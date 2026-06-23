import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/app_whitelist_vpn_status.dart';
import '../models/cell_signal.dart';
import '../models/installed_app.dart';
import '../models/network_tuning_status.dart';
import '../models/network_status.dart';
import '../models/root_command.dart';
import 'app_log_service.dart';

class NetworkService {
  static const MethodChannel _mobileNetworkChannel =
      MethodChannel('netboost/mobile_network');
  static const String _pingHost = 'baidu.com';
  static const String _speedTestUrl =
      'https://speed.cloudflare.com/__down?bytes=1000000';
  static const int _pingCount = 5;
  static const int _quickPingCount = 3;
  static const int _pingTimeoutMs = 3000;
  final _logs = AppLogService.instance;

  Future<NetworkType> getNetworkType() async {
    final result = await Connectivity().checkConnectivity();
    _logs.info('当前连接类型：$result');
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
    } catch (e, stack) {
      _logs.warning('读取移动网络制式失败，降级为 mobile', e, stack);
    }
    return NetworkType.mobile;
  }

  Future<void> openMobileNetworkSettings() async {
    if (!Platform.isAndroid) return;
    _logs.info('打开移动网络设置');
    await _mobileNetworkChannel.invokeMethod<void>('openMobileNetworkSettings');
  }

  Future<void> openWifiSettings() async {
    if (!Platform.isAndroid) return;
    _logs.info('打开 WiFi 设置');
    await _mobileNetworkChannel.invokeMethod<void>('openWifiSettings');
  }

  Future<void> openDataSaverSettings() async {
    if (!Platform.isAndroid) return;
    _logs.info('打开省流量设置');
    await _mobileNetworkChannel.invokeMethod<void>('openDataSaverSettings');
  }

  Future<void> openManageApplicationsSettings() async {
    if (!Platform.isAndroid) return;
    _logs.info('打开应用管理设置');
    await _mobileNetworkChannel
        .invokeMethod<void>('openManageApplicationsSettings');
  }

  Future<void> openVpnSettings() async {
    if (!Platform.isAndroid) return;
    _logs.info('打开 VPN 设置');
    await _mobileNetworkChannel.invokeMethod<void>('openVpnSettings');
  }

  Future<void> openPrivateDnsSettings() async {
    if (!Platform.isAndroid) return;
    _logs.info('打开私有 DNS 设置');
    await _mobileNetworkChannel.invokeMethod<void>('openPrivateDnsSettings');
  }

  Future<List<InstalledApp>> getInstalledApps() async {
    if (!Platform.isAndroid) return const [];
    final result = await _mobileNetworkChannel.invokeMethod<List<dynamic>>(
      'getInstalledApps',
    );
    final apps = result
            ?.map((item) => InstalledApp.fromMap(item as Map<dynamic, dynamic>))
            .where((app) => app.packageName.isNotEmpty)
            .toList() ??
        const <InstalledApp>[];
    _logs.info('读取已安装应用完成：${apps.length} 个');
    return apps;
  }

  Future<bool> hasUsageStatsPermission() async {
    if (!Platform.isAndroid) return false;
    return await _mobileNetworkChannel.invokeMethod<bool>(
          'hasUsageStatsPermission',
        ) ??
        false;
  }

  Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    _logs.info('打开使用情况访问权限设置');
    await _mobileNetworkChannel.invokeMethod<void>('openUsageAccessSettings');
  }

  Future<AppWhitelistVpnStatus> getAppWhitelistVpnStatus() async {
    if (!Platform.isAndroid) return AppWhitelistVpnStatus.empty();
    final result = await _mobileNetworkChannel
        .invokeMethod<Map<dynamic, dynamic>>('getAppWhitelistVpnStatus');
    if (result == null) return AppWhitelistVpnStatus.empty();
    return AppWhitelistVpnStatus.fromMap(result);
  }

  Future<AppWhitelistVpnStatus> startAppWhitelistVpn(
    List<String> allowedPackages,
  ) async {
    if (!Platform.isAndroid) return AppWhitelistVpnStatus.empty();
    final result =
        await _mobileNetworkChannel.invokeMethod<Map<dynamic, dynamic>>(
      'startAppWhitelistVpn',
      {'allowedPackages': allowedPackages},
    );
    if (result == null) return AppWhitelistVpnStatus.empty();
    return AppWhitelistVpnStatus.fromMap(result);
  }

  Future<AppWhitelistVpnStatus> stopAppWhitelistVpn() async {
    if (!Platform.isAndroid) return AppWhitelistVpnStatus.empty();
    final result = await _mobileNetworkChannel
        .invokeMethod<Map<dynamic, dynamic>>('stopAppWhitelistVpn');
    if (result == null) return AppWhitelistVpnStatus.empty();
    return AppWhitelistVpnStatus.fromMap(result);
  }

  Future<List<CellSignal>> getCellSignals() async {
    if (!Platform.isAndroid) return const [];

    try {
      await Permission.locationWhenInUse.request();
      final phoneStatus = await Permission.phone.request();
      if (!phoneStatus.isGranted) {
        _logs.warning('未授予电话权限，将只尝试读取 Wi-Fi 或系统允许的信号信息');
      }

      final result = await _mobileNetworkChannel
          .invokeMethod<List<dynamic>>('getCellSignals');
      return result
              ?.map((item) => CellSignal.fromMap(item as Map<dynamic, dynamic>))
              .toList() ??
          const [];
    } on PlatformException catch (e, stack) {
      _logs.error('系统读取小区信息失败', e, stack);
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
    } catch (e, stack) {
      _logs.error('读取网络调优状态失败', e, stack);
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
    } catch (e, stack) {
      _logs.error('设置高性能 WiFi 锁失败', e, stack);
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
    } catch (e, stack) {
      _logs.error('检测 Root 状态失败', e, stack);
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
    } catch (e, stack) {
      _logs.error('执行 Root 命令失败：$commandId', e, stack);
      return RootCommandResult.empty();
    }
  }

  Future<({int pingMs, double packetLossPercent})> _measureTcpConnectivity({
    required int count,
    required Duration delay,
  }) async {
    final result = await _sampleTcpConnectivity(count: count, delay: delay);
    return (
      pingMs: result.pingMs,
      packetLossPercent: result.packetLossPercent,
    );
  }

  Future<
      ({
        int pingMs,
        double packetLossPercent,
        int jitterMs,
        int consecutiveFailures,
        bool hadFailureBeforeSuccess,
      })> _sampleTcpConnectivity({
    required int count,
    required Duration delay,
  }) async {
    final latencies = <int>[];
    int consecutiveFailures = 0;
    int maxConsecutiveFailures = 0;
    bool hadFailure = false;
    bool hadFailureBeforeSuccess = false;
    for (int i = 0; i < count; i++) {
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
        if (hadFailure) hadFailureBeforeSuccess = true;
        consecutiveFailures = 0;
      } catch (e, stack) {
        hadFailure = true;
        consecutiveFailures += 1;
        if (consecutiveFailures > maxConsecutiveFailures) {
          maxConsecutiveFailures = consecutiveFailures;
        }
        _logs.warning('TCP 探测第 ${i + 1} 次失败', e, stack);
      }
      if (i < count - 1) {
        await Future.delayed(delay);
      }
    }
    final packetLoss = ((count - latencies.length) / count * 100).toDouble();
    if (latencies.isEmpty) {
      return (
        pingMs: -1,
        packetLossPercent: packetLoss,
        jitterMs: 0,
        consecutiveFailures: maxConsecutiveFailures,
        hadFailureBeforeSuccess: false,
      );
    }
    final stableLatencies = latencies.toList()..sort();
    if (stableLatencies.length > 2) stableLatencies.removeLast();
    final pingMs =
        (stableLatencies.reduce((a, b) => a + b) / stableLatencies.length)
            .round();
    return (
      pingMs: pingMs,
      packetLossPercent: packetLoss,
      jitterMs: _calculateJitter(latencies),
      consecutiveFailures: maxConsecutiveFailures,
      hadFailureBeforeSuccess: hadFailureBeforeSuccess,
    );
  }

  int _calculateJitter(List<int> latencies) {
    if (latencies.length < 2) return 0;
    var totalDiff = 0;
    for (int i = 1; i < latencies.length; i++) {
      totalDiff += (latencies[i] - latencies[i - 1]).abs();
    }
    return (totalDiff / (latencies.length - 1)).round();
  }

  Future<int> measurePing() async {
    final result = await _measureTcpConnectivity(
      count: _pingCount,
      delay: const Duration(milliseconds: 200),
    );
    return result.pingMs;
  }

  Future<double> measurePacketLoss() async {
    final result = await _measureTcpConnectivity(
      count: _pingCount,
      delay: const Duration(milliseconds: 100),
    );
    return result.packetLossPercent;
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
    } catch (e, stack) {
      _logs.warning('Cloudflare 下载测速失败，尝试备用测速', e, stack);
      try {
        final start = DateTime.now();
        await http
            .get(Uri.parse('https://www.baidu.com'))
            .timeout(const Duration(seconds: 5));
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        if (elapsed > 0) return 50000 / elapsed; // rough estimate
      } catch (e, stack) {
        _logs.error('备用下载测速失败', e, stack);
      }
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
    _logs.info('开始完整网络检测');
    final type = await getNetworkType();
    if (type == NetworkType.none) {
      _logs.warning('完整网络检测结束：无网络连接');
      return NetworkStatus.empty();
    }

    final connectivity = await _sampleTcpConnectivity(
      count: _pingCount,
      delay: const Duration(milliseconds: 200),
    );
    final pingMs = connectivity.pingMs;
    final packetLoss = connectivity.packetLossPercent;
    final signal = inferSignalStrength(pingMs, packetLoss);
    final shouldSkipSpeedTest = pingMs < 0 || packetLoss >= 30 || pingMs > 600;
    final downloadSpeed =
        shouldSkipSpeedTest ? 0.0 : await measureDownloadSpeed();
    if (shouldSkipSpeedTest) {
      _logs.warning('网络抖动或丢包较高，跳过下载测速以减少带宽占用');
    }
    final stability = _inferStability(
      pingMs: pingMs,
      packetLoss: packetLoss,
      jitterMs: connectivity.jitterMs,
      consecutiveFailures: connectivity.consecutiveFailures,
      hadFailureBeforeSuccess: connectivity.hadFailureBeforeSuccess,
    );

    final status = NetworkStatus(
      timestamp: DateTime.now(),
      type: type,
      signal: signal,
      pingMs: pingMs < 0 ? 0 : pingMs,
      jitterMs: stability.jitterMs,
      consecutiveFailures: stability.consecutiveFailures,
      stabilityScore: stability.score,
      stabilityState: stability.state,
      downloadSpeedMbps: downloadSpeed,
      packetLossPercent: packetLoss,
      dnsLatencyMs: '--',
      isConnected: true,
    );
    _logs.info(
      '完整网络检测完成：ping=${status.pingMs}ms, 丢包=${status.packetLossPercent.toStringAsFixed(0)}%, 下载=${status.downloadSpeedMbps.toStringAsFixed(1)}Mbps',
    );
    return status;
  }

  /// Quick measurement — only ping, skip speed test for real-time updates
  Future<NetworkStatus> quickMeasurement() async {
    _logs.info('开始快速网络检测');
    final type = await getNetworkType();
    if (type == NetworkType.none) {
      _logs.warning('快速网络检测结束：无网络连接');
      return NetworkStatus.empty();
    }

    final connectivity = await _sampleTcpConnectivity(
      count: _quickPingCount,
      delay: const Duration(milliseconds: 150),
    );
    final pingMs = connectivity.pingMs;
    final packetLoss = connectivity.packetLossPercent;
    final signal = inferSignalStrength(pingMs, packetLoss);
    final stability = _inferStability(
      pingMs: pingMs,
      packetLoss: packetLoss,
      jitterMs: connectivity.jitterMs,
      consecutiveFailures: connectivity.consecutiveFailures,
      hadFailureBeforeSuccess: connectivity.hadFailureBeforeSuccess,
    );

    final status = NetworkStatus(
      timestamp: DateTime.now(),
      type: type,
      signal: signal,
      pingMs: pingMs < 0 ? 0 : pingMs,
      jitterMs: stability.jitterMs,
      consecutiveFailures: stability.consecutiveFailures,
      stabilityScore: stability.score,
      stabilityState: stability.state,
      downloadSpeedMbps: 0,
      packetLossPercent: packetLoss,
      dnsLatencyMs: '--',
      isConnected: true,
    );
    _logs.info(
      '快速网络检测完成：ping=${status.pingMs}ms, 丢包=${status.packetLossPercent.toStringAsFixed(0)}%',
    );
    return status;
  }

  ({
    int score,
    int jitterMs,
    int consecutiveFailures,
    NetworkStabilityState state,
  }) _inferStability({
    required int pingMs,
    required double packetLoss,
    required int jitterMs,
    required int consecutiveFailures,
    required bool hadFailureBeforeSuccess,
  }) {
    var score = 100;
    if (pingMs < 0) {
      return (
        score: 0,
        jitterMs: jitterMs,
        consecutiveFailures: consecutiveFailures,
        state: NetworkStabilityState.likelyDrop,
      );
    }
    if (pingMs > 300) {
      score -= 25;
    } else if (pingMs > 150) {
      score -= 12;
    }
    if (jitterMs > 120) {
      score -= 25;
    } else if (jitterMs > 50) {
      score -= 12;
    }
    if (packetLoss >= 30) {
      score -= 35;
    } else if (packetLoss >= 10) {
      score -= 18;
    }
    if (consecutiveFailures >= 2) {
      score -= 25;
    } else if (consecutiveFailures == 1) {
      score -= 10;
    }

    NetworkStabilityState state;
    if (consecutiveFailures >= 2 || packetLoss >= 70) {
      state = NetworkStabilityState.likelyDrop;
    } else if (hadFailureBeforeSuccess) {
      state = NetworkStabilityState.recovering;
    } else if (packetLoss >= 20) {
      state = NetworkStabilityState.highLoss;
    } else if (pingMs > 220 && packetLoss > 5) {
      state = NetworkStabilityState.congested;
    } else if (jitterMs > 50 || packetLoss >= 10 || pingMs > 150) {
      state = NetworkStabilityState.slightJitter;
    } else {
      state = NetworkStabilityState.stable;
    }

    return (
      score: score.clamp(0, 100),
      jitterMs: jitterMs,
      consecutiveFailures: consecutiveFailures,
      state: state,
    );
  }
}
