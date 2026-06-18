class NetworkTuningStatus {
  final int wifiFrequencyMhz;
  final String wifiBand;
  final String wifiSsid;
  final String wifiBssid;
  final bool highPerfWifiLockHeld;
  final int dataSaverStatus;

  const NetworkTuningStatus({
    required this.wifiFrequencyMhz,
    required this.wifiBand,
    required this.wifiSsid,
    required this.wifiBssid,
    required this.highPerfWifiLockHeld,
    required this.dataSaverStatus,
  });

  factory NetworkTuningStatus.empty() => const NetworkTuningStatus(
        wifiFrequencyMhz: 0,
        wifiBand: '未知',
        wifiSsid: '',
        wifiBssid: '',
        highPerfWifiLockHeld: false,
        dataSaverStatus: 1,
      );

  factory NetworkTuningStatus.fromMap(Map<dynamic, dynamic> map) =>
      NetworkTuningStatus(
        wifiFrequencyMhz: map['wifiFrequencyMhz'] as int? ?? 0,
        wifiBand: map['wifiBand'] as String? ?? '未知',
        wifiSsid: map['wifiSsid'] as String? ?? '',
        wifiBssid: map['wifiBssid'] as String? ?? '',
        highPerfWifiLockHeld: map['highPerfWifiLockHeld'] as bool? ?? false,
        dataSaverStatus: map['dataSaverStatus'] as int? ?? 1,
      );

  bool get isDataSaverEnabled => dataSaverStatus == 3;

  String get dataSaverLabel {
    if (dataSaverStatus == 3) return '已开启';
    if (dataSaverStatus == 2) return '白名单放行';
    return '未开启';
  }
}
