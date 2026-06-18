import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/cell_signal.dart';
import '../models/network_status.dart';
import '../models/network_tuning_status.dart';
import '../models/root_command.dart';
import '../models/dns_result.dart';
import '../services/network_service.dart';
import '../services/dns_service.dart';
import '../services/diagnosis_service.dart';

enum MeasurementState { idle, measuring, done, error }

class NetworkProvider extends ChangeNotifier {
  final _networkService = NetworkService();
  final _dnsService = DnsService();
  final _diagnosisService = DiagnosisService();

  NetworkStatus _currentStatus = NetworkStatus.empty();
  List<NetworkStatus> _history = [];
  List<CellSignal> _cellSignals = [];
  List<DnsServer> _dnsServers = DnsServer.defaultServers();
  DiagnosisResult? _diagnosisResult;
  NetworkTuningStatus _tuningStatus = NetworkTuningStatus.empty();
  RootStatus _rootStatus = RootStatus.unknown();
  RootCommandResult _lastRootCommandResult = RootCommandResult.empty();
  String? _lockedCellSignalId;
  String _cellSignalRefreshMessage = '';

  MeasurementState _networkState = MeasurementState.idle;
  MeasurementState _cellSignalState = MeasurementState.idle;
  MeasurementState _tuningState = MeasurementState.idle;
  MeasurementState _rootState = MeasurementState.idle;
  MeasurementState _dnsState = MeasurementState.idle;
  MeasurementState _diagnosisState = MeasurementState.idle;

  int _dnsTestProgress = 0;
  String _errorMessage = '';
  DateTime? _backgroundRefreshPauseUntil;
  DateTime? _cellSignalRefreshStartedAt;

  Timer? _autoRefreshTimer;
  Timer? _backgroundRefreshTimer;
  Timer? _cellSignalRefreshTicker;

  NetworkStatus get currentStatus => _currentStatus;
  List<NetworkStatus> get history => List.unmodifiable(_history);
  List<CellSignal> get cellSignals => List.unmodifiable(_cellSignals);
  List<DnsServer> get dnsServers => List.unmodifiable(_dnsServers);
  DiagnosisResult? get diagnosisResult => _diagnosisResult;
  NetworkTuningStatus get tuningStatus => _tuningStatus;
  RootStatus get rootStatus => _rootStatus;
  RootCommandResult get lastRootCommandResult => _lastRootCommandResult;
  String? get lockedCellSignalId => _lockedCellSignalId;
  String get cellSignalRefreshMessage => _cellSignalRefreshMessage;
  MeasurementState get networkState => _networkState;
  MeasurementState get cellSignalState => _cellSignalState;
  MeasurementState get tuningState => _tuningState;
  MeasurementState get rootState => _rootState;
  MeasurementState get dnsState => _dnsState;
  MeasurementState get diagnosisState => _diagnosisState;
  int get dnsTestProgress => _dnsTestProgress;
  String get errorMessage => _errorMessage;
  int get cellSignalRefreshRemainingSeconds {
    final startedAt = _cellSignalRefreshStartedAt;
    if (_cellSignalState != MeasurementState.measuring || startedAt == null) {
      return 0;
    }
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return (10 - elapsed).clamp(0, 10);
  }

  bool get isAutoRefreshing => _autoRefreshTimer != null;
  DateTime? get backgroundRefreshPauseUntil => _backgroundRefreshPauseUntil;
  bool get isBackgroundRefreshPaused =>
      _backgroundRefreshPauseUntil?.isAfter(DateTime.now()) ?? false;
  Duration? get backgroundRefreshPauseRemaining {
    final until = _backgroundRefreshPauseUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void startAutoRefresh({Duration interval = const Duration(seconds: 30)}) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(interval, (_) => refreshQuick());
    refreshQuick();
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    notifyListeners();
  }

  void toggleAutoRefresh() {
    if (isAutoRefreshing) {
      stopAutoRefresh();
    } else {
      startAutoRefresh();
    }
  }

  Future<void> refreshQuick() async {
    if (_networkState == MeasurementState.measuring) return;
    _networkState = MeasurementState.measuring;
    notifyListeners();

    try {
      final status = await _networkService.quickMeasurement();
      _currentStatus = status;
      _addToHistory(status);
      _networkState = MeasurementState.done;
    } catch (e) {
      _errorMessage = e.toString();
      _networkState = MeasurementState.error;
    }
    notifyListeners();
  }

  Future<void> runFullMeasurement() async {
    if (_networkState == MeasurementState.measuring) return;
    _networkState = MeasurementState.measuring;
    notifyListeners();

    try {
      final status = await _networkService.fullMeasurement();
      _currentStatus = status;
      _addToHistory(status);
      _networkState = MeasurementState.done;
    } catch (e) {
      _errorMessage = e.toString();
      _networkState = MeasurementState.error;
    }
    notifyListeners();
  }

  Future<void> refreshCellSignals() async {
    if (_cellSignalState == MeasurementState.measuring) return;
    _cellSignalState = MeasurementState.measuring;
    _cellSignalRefreshMessage = '正在请求系统刷新小区信息，最多等待 10 秒';
    _cellSignalRefreshStartedAt = DateTime.now();
    _cellSignalRefreshTicker?.cancel();
    _cellSignalRefreshTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    notifyListeners();

    try {
      final signals = await _networkService.getCellSignals();
      _cellSignals = signals
        ..sort((a, b) {
          if (a.registered != b.registered) return a.registered ? -1 : 1;
          return (b.dbm ?? -999).compareTo(a.dbm ?? -999);
        });
      _cellSignalRefreshMessage = _buildCellSignalRefreshMessage(_cellSignals);
      _cellSignalState = MeasurementState.done;
    } catch (e) {
      _errorMessage = e.toString();
      _cellSignalRefreshMessage = '刷新失败：$_errorMessage';
      _cellSignalState = MeasurementState.error;
    }
    _cellSignalRefreshStartedAt = null;
    _cellSignalRefreshTicker?.cancel();
    notifyListeners();
  }

  void toggleCellSignalLock(CellSignal signal) {
    final id = signal.lockId;
    _lockedCellSignalId = _lockedCellSignalId == id ? null : id;
    notifyListeners();
  }

  String _buildCellSignalRefreshMessage(List<CellSignal> signals) {
    if (signals.isEmpty) {
      return '没有读到小区信息。请确认电话和位置权限、系统定位开关、移动网络都已开启';
    }
    final note = signals.map((signal) => signal.refreshNote).firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    if (note.isNotEmpty) return note;
    final hasWlsDistance = signals.any(
      (signal) => signal.distanceMethod == '加权最小二乘',
    );
    if (hasWlsDistance) return '刷新完成，已使用加权最小二乘估计基站距离';
    return '刷新完成，已读取 ${signals.length} 个小区；距离估计需要至少3个基站点位';
  }

  Future<void> refreshNetworkTuningStatus() async {
    if (_tuningState == MeasurementState.measuring) return;
    _tuningState = MeasurementState.measuring;
    notifyListeners();

    try {
      _tuningStatus = await _networkService.getNetworkTuningStatus();
      _tuningState = MeasurementState.done;
    } catch (e) {
      _errorMessage = e.toString();
      _tuningState = MeasurementState.error;
    }
    notifyListeners();
  }

  Future<void> checkRootStatus() async {
    if (_rootState == MeasurementState.measuring) return;
    _rootState = MeasurementState.measuring;
    notifyListeners();

    try {
      _rootStatus = await _networkService.checkRootStatus();
      _rootState = MeasurementState.done;
    } catch (e) {
      _errorMessage = e.toString();
      _rootState = MeasurementState.error;
    }
    notifyListeners();
  }

  Future<void> runRootCommand(String commandId) async {
    if (_rootState == MeasurementState.measuring) return;
    _rootState = MeasurementState.measuring;
    notifyListeners();

    try {
      _lastRootCommandResult = await _networkService.runRootCommand(commandId);
      _rootState = MeasurementState.done;
    } catch (e) {
      _errorMessage = e.toString();
      _rootState = MeasurementState.error;
    }
    notifyListeners();
  }

  Future<void> testAllDns() async {
    if (_dnsState == MeasurementState.measuring) return;
    _dnsState = MeasurementState.measuring;
    _dnsTestProgress = 0;
    _dnsServers = DnsServer.defaultServers();
    notifyListeners();

    try {
      final results = await _dnsService.testAllServers(
        _dnsServers,
        onProgress: (index, _) {
          _dnsTestProgress = index + 1;
          notifyListeners();
        },
      );
      _dnsServers = results;
      _dnsState = MeasurementState.done;
    } catch (e) {
      _errorMessage = e.toString();
      _dnsState = MeasurementState.error;
    }
    notifyListeners();
  }

  Future<void> runDiagnosis() async {
    if (_diagnosisState == MeasurementState.measuring) return;
    _diagnosisState = MeasurementState.measuring;
    _diagnosisResult = null;
    notifyListeners();

    try {
      await runFullMeasurement();
      _diagnosisResult = _diagnosisService.diagnose(_currentStatus);
      _diagnosisState = MeasurementState.done;
    } catch (e) {
      _errorMessage = e.toString();
      _diagnosisState = MeasurementState.error;
    }
    notifyListeners();
  }

  Future<void> openMobileNetworkSettings() async {
    await _networkService.openMobileNetworkSettings();
  }

  Future<void> openWifiSettings() async {
    await _networkService.openWifiSettings();
  }

  Future<void> openDataSaverSettings() async {
    await _networkService.openDataSaverSettings();
  }

  Future<void> openManageApplicationsSettings() async {
    await _networkService.openManageApplicationsSettings();
  }

  Future<void> setHighPerfWifiLock(bool enabled) async {
    await _networkService.setHighPerfWifiLock(enabled);
    await refreshNetworkTuningStatus();
  }

  void startBackgroundRefreshPause(Duration duration) {
    _backgroundRefreshPauseUntil = DateTime.now().add(duration);
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isBackgroundRefreshPaused) {
        _backgroundRefreshPauseUntil = null;
        _backgroundRefreshTimer?.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelBackgroundRefreshPause() {
    _backgroundRefreshPauseUntil = null;
    _backgroundRefreshTimer?.cancel();
    notifyListeners();
  }

  void _addToHistory(NetworkStatus status) {
    _history.insert(0, status);
    if (_history.length > 50) _history = _history.sublist(0, 50);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _backgroundRefreshTimer?.cancel();
    _cellSignalRefreshTicker?.cancel();
    super.dispose();
  }
}
