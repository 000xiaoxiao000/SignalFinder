import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/cell_signal.dart';
import '../models/network_tuning_status.dart';
import '../models/network_status.dart';
import '../models/root_command.dart';

class NetworkService {
  static const MethodChannel _mobileNetworkChannel =
      MethodChannel('netboost/mobile_network');
  static const String _pingHost = 'baidu.com';
  static const String _speedTestUrl =
      'https://speed.cloudflare.com/__down?bytes=1000000';
  static const int _pingCount = 5;
  static const int _pingTimeoutMs = 3000;

  Future<NetworkType> getNetworkType() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.wifi) return NetworkType.wifi;
    if (result == ConnectivityResult.mobile) {
      return _getMobileNetworkType();
    }
    if (result == ConnectivityResult.none) return NetworkType.none;
    return NetworkType.unknown;
  }

  Future<NetworkType> _getMobileNetworkType() async {
    if (!Platform.isAndroid) return NetworkType.unknown;

    try {
      await Permission.phone.request();
      final generation = await _mobileNetworkChannel
          .invokeMethod<String>('getMobileNetworkGeneration');
      switch (generation) {
        case '5G':
          return NetworkType.mobile5G;
        case '4G':
          return NetworkType.mobile4G;
        case '3G':
          return NetworkType.mobile3G;
        case '2G':
          return NetworkType.mobile2G;
      }
    } catch (_) {
      // Fall back to generic mobile when Android cannot expose radio details.
    }
    return NetworkType.mobile;
  }

  Future<void> openMobileNetworkSettings() async {
    if (!Platform.isAndroid) return;
    await _mobileNetworkChannel.invokeMethod<void>('openMobileNetworkSettings');
  }

  Future<void> openWifiSettings() async {
    if (!Platform.isAndroid) return;
    await _mobileNetworkChannel.invokeMethod<void>('openWifiSettings');
  }

  Future<void> openDataSaverSettings() async {
    if (!Platform.isAndroid) return;
    await _mobileNetworkChannel.invokeMethod<void>('openDataSaverSettings');
  }

  Future<void> openManageApplicationsSettings() async {
    if (!Platform.isAndroid) return;
    await _mobileNetworkChannel
        .invokeMethod<void>('openManageApplicationsSettings');
  }

  Future<List<CellSignal>> getCellSignals() async {
    if (!Platform.isAndroid) return const [];

    try {
      final phoneStatus = await Permission.phone.request();
      if (!phoneStatus.isGranted) {
        throw Exception('需要允许“电话”权限后才能读取移动网络制式和小区信息');
      }

      await Permission.locationWhenInUse.request();

      final result = await _mobileNetworkChannel
          .invokeMethod<List<dynamic>>('getCellSignals');
      return result
              ?.map((item) => CellSignal.fromMap(item as Map<dynamic, dynamic>))
              .toList() ??
          const [];
    } on PlatformException catch (e) {
      throw Exception(e.message ?? '系统读取小区信息失败');
    }
  }

  Future<NetworkTuningStatus> getNetworkTuningStatus() async {
    if (!Platform.isAndroid) return NetworkTuningStatus.empty();
    try {
      final result = await _mobileNetworkChannel
          .invokeMethod<Map<dynamic, dynamic>>('getNetworkTuningStatus');
      if (result == null) return NetworkTuningStatus.empty();
      return NetworkTuningStatus.fromMap(result);
    } catch (_) {
      return NetworkTuningStatus.empty();
    }
  }

  Future<bool> setHighPerfWifiLock(bool enabled) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _mobileNetworkChannel.invokeMethod<bool>(
            'setHighPerfWifiLock',
            {'enabled': enabled},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<RootStatus> checkRootStatus() async {
    if (!Platform.isAndroid) return RootStatus.unknown();
    try {
      final result = await _mobileNetworkChannel
          .invokeMethod<Map<dynamic, dynamic>>('checkRootStatus');
      if (result == null) return RootStatus.unknown();
      return RootStatus.fromMap(result);
    } catch (_) {
      return RootStatus.unknown();
    }
  }

  Future<RootCommandResult> runRootCommand(String commandId) async {
    if (!Platform.isAndroid) return RootCommandResult.empty();
    try {
      final result =
          await _mobileNetworkChannel.invokeMethod<Map<dynamic, dynamic>>(
        'runRootCommand',
        {'commandId': commandId},
      );
      if (result == null) return RootCommandResult.empty();
      return RootCommandResult.fromMap(result);
    } catch (_) {
      return RootCommandResult.empty();
    }
  }

  Future<int> measurePing() async {
    final latencies = <int>[];
    for (int i = 0; i < _pingCount; i++) {
      try {
        final start = DateTime.now();
        final socket = await Socket.connect(
          _pingHost,
          80,
          timeout: const Duration(milliseconds: _pingTimeoutMs),
        );
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        socket.destroy();
        latencies.add(elapsed);
      } catch (_) {
        // packet lost
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (latencies.isEmpty) return -1;
    latencies.sort();
    // trim outliers: remove highest value
    if (latencies.length > 2) latencies.removeLast();
    return (latencies.reduce((a, b) => a + b) / latencies.length).round();
  }

  Future<double> measurePacketLoss() async {
    int sent = 0;
    int received = 0;
    for (int i = 0; i < _pingCount; i++) {
      sent++;
      try {
        final socket = await Socket.connect(
          _pingHost,
          80,
          timeout: const Duration(milliseconds: _pingTimeoutMs),
        );
        socket.destroy();
        received++;
      } catch (_) {
        // lost
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (sent == 0) return 100.0;
    return ((sent - received) / sent * 100).toDouble();
  }

  Future<double> measureDownloadSpeed() async {
    try {
      final start = DateTime.now();
      final response = await http
          .get(Uri.parse(_speedTestUrl))
          .timeout(const Duration(seconds: 10));
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      if (response.statusCode == 200 && elapsed > 0) {
        final bytes = response.bodyBytes.length;
        return (bytes * 8 / elapsed / 1000); // Mbps
      }
    } catch (_) {
      // fallback: small HTTP request
      try {
        final start = DateTime.now();
        await http
            .get(Uri.parse('https://www.baidu.com'))
            .timeout(const Duration(seconds: 5));
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        if (elapsed > 0) return 50000 / elapsed; // rough estimate
      } catch (_) {}
    }
    return 0.0;
  }

  SignalStrength inferSignalStrength(int pingMs, double packetLoss) {
    if (pingMs < 0) return SignalStrength.none;
    if (packetLoss >= 50) return SignalStrength.poor;
    if (pingMs < 50 && packetLoss < 5) return SignalStrength.excellent;
    if (pingMs < 100 && packetLoss < 10) return SignalStrength.good;
    if (pingMs < 200 && packetLoss < 20) return SignalStrength.fair;
    return SignalStrength.poor;
  }

  Future<NetworkStatus> fullMeasurement() async {
    final type = await getNetworkType();
    if (type == NetworkType.none) return NetworkStatus.empty();

    final pingMs = await measurePing();
    final packetLoss = await measurePacketLoss();
    final signal = inferSignalStrength(pingMs, packetLoss);
    final downloadSpeed = await measureDownloadSpeed();

    return NetworkStatus(
      timestamp: DateTime.now(),
      type: type,
      signal: signal,
      pingMs: pingMs < 0 ? 0 : pingMs,
      downloadSpeedMbps: downloadSpeed,
      packetLossPercent: packetLoss,
      dnsLatencyMs: '--',
      isConnected: true,
    );
  }

  /// Quick measurement — only ping, skip speed test for real-time updates
  Future<NetworkStatus> quickMeasurement() async {
    final type = await getNetworkType();
    if (type == NetworkType.none) return NetworkStatus.empty();

    final pingMs = await measurePing();
    final packetLoss = await measurePacketLoss();
    final signal = inferSignalStrength(pingMs, packetLoss);

    return NetworkStatus(
      timestamp: DateTime.now(),
      type: type,
      signal: signal,
      pingMs: pingMs < 0 ? 0 : pingMs,
      downloadSpeedMbps: 0,
      packetLossPercent: packetLoss,
      dnsLatencyMs: '--',
      isConnected: true,
    );
  }
}
