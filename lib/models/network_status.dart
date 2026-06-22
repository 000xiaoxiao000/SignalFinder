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

enum NetworkStabilityState {
  stable,
  slightJitter,
  congested,
  highLoss,
  likelyDrop,
  recovering,
}

class NetworkStatus {
  final DateTime timestamp;
  final NetworkType type;
  final SignalStrength signal;
  final int pingMs;
  final int jitterMs;
  final int consecutiveFailures;
  final int stabilityScore;
  final NetworkStabilityState stabilityState;
  final double downloadSpeedMbps;
  final double packetLossPercent;
  final String dnsLatencyMs;
  final bool isConnected;

  const NetworkStatus({
    required this.timestamp,
    required this.type,
    required this.signal,
    required this.pingMs,
    this.jitterMs = 0,
    this.consecutiveFailures = 0,
    this.stabilityScore = 0,
    this.stabilityState = NetworkStabilityState.stable,
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
        jitterMs: 0,
        consecutiveFailures: 0,
        stabilityScore: 0,
        stabilityState: NetworkStabilityState.likelyDrop,
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

  String get stabilityLabel {
    if (!isConnected) return '无网络';
    switch (stabilityState) {
      case NetworkStabilityState.stable:
        return '稳定';
      case NetworkStabilityState.slightJitter:
        return '轻微抖动';
      case NetworkStabilityState.congested:
        return '拥塞';
      case NetworkStabilityState.highLoss:
        return '高丢包';
      case NetworkStabilityState.likelyDrop:
        return '疑似断流';
      case NetworkStabilityState.recovering:
        return '恢复中';
    }
  }

  String get stabilityAdvice {
    if (!isConnected) return '当前没有可用网络，请先确认 Wi-Fi 或移动数据已开启。';
    switch (stabilityState) {
      case NetworkStabilityState.stable:
        return '当前网络可用性较好，保持自动监测即可。';
      case NetworkStabilityState.slightJitter:
        return '检测到延迟波动，建议暂停下载测速并关闭后台同步、下载或播放任务。';
      case NetworkStabilityState.congested:
        return type == NetworkType.wifi
            ? '当前 Wi-Fi 可能拥塞，建议切换频段、靠近路由器或改用移动网络。'
            : '当前移动网络可能拥塞，建议换位置、切换 4G/5G 偏好或改用 Wi-Fi。';
      case NetworkStabilityState.highLoss:
        return '当前丢包较高，实时业务容易卡顿或断开，建议优先切换到更稳定的网络。';
      case NetworkStabilityState.likelyDrop:
        return '连续探测失败，疑似断流。请检查网络开关、信号和省流量限制。';
      case NetworkStabilityState.recovering:
        return '网络刚从失败中恢复，建议暂时避免测速和大流量操作。';
    }
  }

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.millisecondsSinceEpoch,
        'type': type.index,
        'signal': signal.index,
        'pingMs': pingMs,
        'jitterMs': jitterMs,
        'consecutiveFailures': consecutiveFailures,
        'stabilityScore': stabilityScore,
        'stabilityState': stabilityState.index,
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
        jitterMs: (map['jitterMs'] as int?) ?? 0,
        consecutiveFailures: (map['consecutiveFailures'] as int?) ?? 0,
        stabilityScore: (map['stabilityScore'] as int?) ?? 0,
        stabilityState: NetworkStabilityState.values[
            (map['stabilityState'] as int?) ??
                NetworkStabilityState.stable.index],
        downloadSpeedMbps: (map['downloadSpeedMbps'] as num).toDouble(),
        packetLossPercent: (map['packetLossPercent'] as num).toDouble(),
        dnsLatencyMs: map['dnsLatencyMs'] as String,
        isConnected: (map['isConnected'] as int) == 1,
      );
}
