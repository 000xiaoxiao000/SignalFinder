enum NetworkType {
  wifi,
  mobile,
  mobile4G,
  mobile5G,
  mobile3G,
  mobile2G,
  none,
  unknown,
}

enum SignalStrength { excellent, good, fair, poor, none }

class NetworkStatus {
  final DateTime timestamp;
  final NetworkType type;
  final SignalStrength signal;
  final int pingMs;
  final double downloadSpeedMbps;
  final double packetLossPercent;
  final String dnsLatencyMs;
  final bool isConnected;

  const NetworkStatus({
    required this.timestamp,
    required this.type,
    required this.signal,
    required this.pingMs,
    required this.downloadSpeedMbps,
    required this.packetLossPercent,
    required this.dnsLatencyMs,
    required this.isConnected,
  });

  factory NetworkStatus.empty() => NetworkStatus(
        timestamp: DateTime.now(),
        type: NetworkType.unknown,
        signal: SignalStrength.none,
        pingMs: 0,
        downloadSpeedMbps: 0,
        packetLossPercent: 0,
        dnsLatencyMs: '--',
        isConnected: false,
      );

  String get networkTypeName {
    switch (type) {
      case NetworkType.wifi:
        return 'WiFi';
      case NetworkType.mobile:
        return '移动网络';
      case NetworkType.mobile5G:
        return '5G';
      case NetworkType.mobile4G:
        return '4G LTE';
      case NetworkType.mobile3G:
        return '3G';
      case NetworkType.mobile2G:
        return '2G';
      case NetworkType.none:
        return '无网络';
      case NetworkType.unknown:
        return '未知';
    }
  }

  String get signalLabel {
    switch (signal) {
      case SignalStrength.excellent:
        return '信号极强';
      case SignalStrength.good:
        return '信号良好';
      case SignalStrength.fair:
        return '信号一般';
      case SignalStrength.poor:
        return '信号极弱';
      case SignalStrength.none:
        return '无信号';
    }
  }

  String get pingLabel {
    if (pingMs <= 0) return '--';
    if (pingMs < 50) return '极快';
    if (pingMs < 100) return '良好';
    if (pingMs < 200) return '一般';
    return '较慢';
  }

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.millisecondsSinceEpoch,
        'type': type.index,
        'signal': signal.index,
        'pingMs': pingMs,
        'downloadSpeedMbps': downloadSpeedMbps,
        'packetLossPercent': packetLossPercent,
        'dnsLatencyMs': dnsLatencyMs,
        'isConnected': isConnected ? 1 : 0,
      };

  factory NetworkStatus.fromMap(Map<String, dynamic> map) => NetworkStatus(
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        type: NetworkType.values[map['type'] as int],
        signal: SignalStrength.values[map['signal'] as int],
        pingMs: map['pingMs'] as int,
        downloadSpeedMbps: (map['downloadSpeedMbps'] as num).toDouble(),
        packetLossPercent: (map['packetLossPercent'] as num).toDouble(),
        dnsLatencyMs: map['dnsLatencyMs'] as String,
        isConnected: (map['isConnected'] as int) == 1,
      );
}
