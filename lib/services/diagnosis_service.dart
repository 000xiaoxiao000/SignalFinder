import '../models/network_status.dart';
import '../models/installed_app.dart';

enum DiagnosisIssue {
  highLatency,
  packetLoss,
  slowSpeed,
  dnsIssue,
  noConnection,
  unstableConnection,
  crowdedNetwork,
  highJitter,
  likelyDrop,
  ok,
}

class DiagnosisResult {
  final List<DiagnosisIssue> issues;
  final String summary;
  final List<DiagnosisTip> tips;
  final List<NetworkImpactApp> impactApps;
  final bool canInspectAppTraffic;
  final int score; // 0-100

  const DiagnosisResult({
    required this.issues,
    required this.summary,
    required this.tips,
    this.impactApps = const [],
    this.canInspectAppTraffic = false,
    required this.score,
  });
}

class NetworkImpactApp {
  final String packageName;
  final String label;
  final String trafficLabel;
  final int totalBytes;
  final ImpactLevel level;

  const NetworkImpactApp({
    required this.packageName,
    required this.label,
    required this.trafficLabel,
    required this.totalBytes,
    required this.level,
  });
}

enum ImpactLevel { high, medium, low }

class DiagnosisTip {
  final String title;
  final String detail;
  final String icon;
  final TipPriority priority;
  final DiagnosisTipAction? action;

  const DiagnosisTip({
    required this.title,
    required this.detail,
    required this.icon,
    required this.priority,
    this.action,
  });
}

enum TipPriority { high, medium, low }

enum DiagnosisTipAction {
  openNetworkTuning,
  openWifiSettings,
  openMobileNetworkSettings,
  openDataSaverSettings,
  openUsageAccessSettings,
  temporaryBackgroundRefreshPause,
}

class DiagnosisService {
  DiagnosisResult diagnose(
    NetworkStatus status, {
    List<InstalledApp> installedApps = const [],
    bool canInspectAppTraffic = false,
  }) {
    if (!status.isConnected) {
      return const DiagnosisResult(
        issues: [DiagnosisIssue.noConnection],
        summary: '当前没有网络连接',
        score: 0,
        tips: [
          DiagnosisTip(
            icon: '📡',
            title: '检查飞行模式',
            detail: '确认手机没有开启飞行模式，移动数据已打开。',
            priority: TipPriority.high,
            action: DiagnosisTipAction.openMobileNetworkSettings,
          ),
          DiagnosisTip(
            icon: '🔄',
            title: '重启网络',
            detail: '关闭再打开移动数据，或切换到 WiFi。',
            priority: TipPriority.high,
            action: DiagnosisTipAction.openWifiSettings,
          ),
        ],
      );
    }

    final impactApps = _findImpactApps(installedApps, canInspectAppTraffic);
    final issues = <DiagnosisIssue>[];
    final tips = <DiagnosisTip>[];
    int score = 100;

    // Latency check
    if (status.pingMs > 300) {
      issues.add(DiagnosisIssue.highLatency);
      score -= 30;
      tips.add(const DiagnosisTip(
        icon: '⚡',
        title: '延迟过高',
        detail: '当前延迟超过 300ms，网页加载和应用响应会明显变慢。尝试走到信号更好的地方，或远离人群密集区域。',
        priority: TipPriority.high,
      ));
    } else if (status.pingMs > 150) {
      issues.add(DiagnosisIssue.highLatency);
      score -= 15;
      tips.add(const DiagnosisTip(
        icon: '⚡',
        title: '延迟偏高',
        detail: '延迟在 150-300ms，轻度影响使用体验。',
        priority: TipPriority.medium,
      ));
    }

    // Packet loss check
    if (status.packetLossPercent >= 30) {
      issues.add(DiagnosisIssue.packetLoss);
      score -= 30;
      tips.add(const DiagnosisTip(
        icon: '📉',
        title: '严重丢包',
        detail: '丢包率超过 30%，可能正处于基站覆盖边缘或地下深层。建议换个位置或等到人少时再用。',
        priority: TipPriority.high,
      ));
    } else if (status.packetLossPercent >= 10) {
      issues.add(DiagnosisIssue.packetLoss);
      score -= 15;
      tips.add(const DiagnosisTip(
        icon: '📉',
        title: '存在丢包',
        detail: '丢包率 10-30%，部分请求会失败。视频通话和游戏体验会受影响。',
        priority: TipPriority.medium,
      ));
    }

    // Stability check
    if (status.stabilityState == NetworkStabilityState.likelyDrop) {
      issues.add(DiagnosisIssue.likelyDrop);
      score -= 25;
      tips.add(const DiagnosisTip(
        icon: '⛔',
        title: '疑似短时断流',
        detail: '连续探测失败或丢包过高。建议先停止测速和下载，再检查移动数据、Wi-Fi 或省流量限制。',
        priority: TipPriority.high,
        action: DiagnosisTipAction.openDataSaverSettings,
      ));
    } else if (status.stabilityState == NetworkStabilityState.recovering) {
      issues.add(DiagnosisIssue.unstableConnection);
      score -= 10;
      tips.add(const DiagnosisTip(
        icon: '↗',
        title: '网络正在恢复',
        detail: '刚出现过失败探测，建议短时间内不要启动大文件下载或测速，等待连接稳定。',
        priority: TipPriority.medium,
      ));
    }

    if (status.jitterMs > 120) {
      issues.add(DiagnosisIssue.highJitter);
      score -= 20;
      tips.add(DiagnosisTip(
        icon: '〽',
        title: '抖动很高',
        detail: status.type == NetworkType.wifi
            ? '延迟波动超过 120ms，实时连接容易卡顿。建议开启 Wi-Fi 高性能锁、靠近路由器或切换到移动网络。'
            : '延迟波动超过 120ms，移动网络可能正在小区切换或拥塞。建议换位置，必要时进入移动网络设置调整 5G/4G 偏好。',
        priority: TipPriority.high,
        action: status.type == NetworkType.wifi
            ? DiagnosisTipAction.openNetworkTuning
            : DiagnosisTipAction.openMobileNetworkSettings,
      ));
    } else if (status.jitterMs > 50) {
      issues.add(DiagnosisIssue.highJitter);
      score -= 10;
      tips.add(const DiagnosisTip(
        icon: '〽',
        title: '存在延迟抖动',
        detail: '当前平均延迟不一定很高，但波动较明显。建议关闭后台下载、同步和自动更新。',
        priority: TipPriority.medium,
        action: DiagnosisTipAction.openNetworkTuning,
      ));
    }

    // Speed check
    if (status.downloadSpeedMbps > 0 && status.downloadSpeedMbps < 1) {
      issues.add(DiagnosisIssue.slowSpeed);
      score -= 20;
      tips.add(DiagnosisTip(
        icon: '⏬',
        title: '下载速度极慢',
        detail: impactApps.isEmpty
            ? '当前下载速度低于 1Mbps，看视频和下载文件会非常慢。关闭不用的 App，减少带宽占用。'
            : '当前下载速度低于 1Mbps，看视频和下载文件会非常慢。优先检查下方流量占用较高的 App，并关闭不用的后台同步、下载或播放任务。',
        priority: TipPriority.high,
      ));
    }

    // Crowded network detection: high latency + packet loss on mobile
    if (status.type != NetworkType.wifi &&
        status.pingMs > 150 &&
        status.packetLossPercent > 5) {
      issues.add(DiagnosisIssue.crowdedNetwork);
      tips.add(const DiagnosisTip(
        icon: '👥',
        title: '可能处于人多场景',
        detail:
            '综合判断当前可能在地铁、商场等人密集区域，基站超载导致网速下降。\n建议：①提前缓存内容；②切换到 4G（关闭 5G）；③优选更快的 DNS。',
        priority: TipPriority.high,
        action: DiagnosisTipAction.openMobileNetworkSettings,
      ));
    }

    // General tips
    tips.add(const DiagnosisTip(
      icon: '🌐',
      title: '优化 DNS 可提速',
      detail: '运营商默认 DNS 在高峰期响应较慢。使用本 App 的"DNS 测速"功能找到更快的 DNS，可减少网页打开时间。',
      priority: TipPriority.medium,
    ));

    if (status.type == NetworkType.mobile5G) {
      tips.add(const DiagnosisTip(
        icon: '📶',
        title: '尝试切换到 4G',
        detail: '5G 在地下或人群中穿透力差。进入手机设置 → 移动网络 → 首选网络类型，选择 LTE/4G。',
        priority: TipPriority.medium,
        action: DiagnosisTipAction.openMobileNetworkSettings,
      ));
    }

    tips.add(const DiagnosisTip(
      icon: '🔄',
      title: '减少后台网络干扰',
      detail: '进入网络调优查看高流量应用、Wi-Fi 高性能锁、省流量和系统网络入口。弱网时先停止后台下载、同步和自动更新。',
      priority: TipPriority.low,
      action: DiagnosisTipAction.openNetworkTuning,
    ));

    String summary;
    if (score >= 80) {
      summary = '网络状态良好，无明显问题';
    } else if (score >= 60) {
      summary = '网络存在轻微问题，体验有所下降';
    } else if (score >= 40) {
      summary = '网络质量较差，建议按提示优化';
    } else {
      summary = '网络严重拥塞，强烈建议换个位置';
    }

    return DiagnosisResult(
      issues: issues.isEmpty ? [DiagnosisIssue.ok] : issues,
      summary: summary,
      tips: tips,
      impactApps: impactApps,
      canInspectAppTraffic: canInspectAppTraffic,
      score: score.clamp(0, 100),
    );
  }

  List<NetworkImpactApp> _findImpactApps(
    List<InstalledApp> apps,
    bool canInspectAppTraffic,
  ) {
    if (!canInspectAppTraffic) return const [];
    final trafficApps = apps.where((app) => app.totalBytes > 0).toList()
      ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return trafficApps.take(5).map((app) {
      return NetworkImpactApp(
        packageName: app.packageName,
        label: app.label.isEmpty ? app.packageName : app.label,
        trafficLabel: app.trafficLabel,
        totalBytes: app.totalBytes,
        level: _impactLevel(app.totalBytes),
      );
    }).toList();
  }

  ImpactLevel _impactLevel(int totalBytes) {
    if (totalBytes >= 1024 * 1024 * 1024) return ImpactLevel.high;
    if (totalBytes >= 100 * 1024 * 1024) return ImpactLevel.medium;
    return ImpactLevel.low;
  }
}
