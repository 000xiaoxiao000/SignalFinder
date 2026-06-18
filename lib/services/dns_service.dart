import 'dart:async';
import 'dart:io';
import '../models/dns_result.dart';

class DnsService {
  static const String _testDomain = 'baidu.com';
  static const int _dnsPort = 53;
  static const int _timeoutMs = 3000;

  /// DNS query packet for A record of _testDomain
  List<int> _buildDnsQuery() {
    // Minimal valid DNS query packet
    const domain = _testDomain;
    final labels = domain.split('.');
    final query = <int>[
      0x00, 0x01, // Transaction ID
      0x01, 0x00, // Flags: standard query
      0x00, 0x01, // Questions: 1
      0x00, 0x00, // Answer RRs: 0
      0x00, 0x00, // Authority RRs: 0
      0x00, 0x00, // Additional RRs: 0
    ];
    for (final label in labels) {
      query.add(label.length);
      query.addAll(label.codeUnits);
    }
    query.addAll([
      0x00,
      0x00,
      0x01,
      0x00,
      0x01
    ]); // null terminator + A record + IN class
    return query;
  }

  Future<int> testDnsLatency(String dnsAddress) async {
    if (dnsAddress == 'auto') {
      return await _testSystemDns();
    }
    try {
      final completer = Completer<int>();
      final start = DateTime.now();
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final packet = _buildDnsQuery();
      socket.send(packet, InternetAddress(dnsAddress), _dnsPort);

      final timeout = Timer(const Duration(milliseconds: _timeoutMs), () {
        if (!completer.isCompleted) {
          socket.close();
          completer.complete(-1);
        }
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final elapsed = DateTime.now().difference(start).inMilliseconds;
          timeout.cancel();
          socket.close();
          if (!completer.isCompleted) completer.complete(elapsed);
        }
      });

      return await completer.future;
    } catch (_) {
      return -1;
    }
  }

  Future<int> _testSystemDns() async {
    try {
      final start = DateTime.now();
      await InternetAddress.lookup(_testDomain)
          .timeout(const Duration(milliseconds: _timeoutMs));
      return DateTime.now().difference(start).inMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  Future<List<DnsServer>> testAllServers(
    List<DnsServer> servers, {
    void Function(int index, DnsServer server)? onProgress,
  }) async {
    for (int i = 0; i < servers.length; i++) {
      final server = servers[i];
      final latency = await testDnsLatency(server.address);
      server.latencyMs = latency;
      server.isTested = true;
      server.isReachable = latency >= 0;
      onProgress?.call(i, server);
    }
    final tested = servers.where((s) => s.isReachable).toList();
    tested.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
    final unreachable = servers.where((s) => !s.isReachable).toList();
    return [...tested, ...unreachable];
  }

  DnsServer? getBestServer(List<DnsServer> servers) {
    final reachable =
        servers.where((s) => s.isTested && s.isReachable).toList();
    if (reachable.isEmpty) return null;
    reachable.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
    return reachable.first;
  }
}
