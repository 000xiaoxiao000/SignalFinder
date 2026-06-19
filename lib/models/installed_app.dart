class InstalledApp {
  final String packageName;
  final String label;
  final int uid;
  final bool systemApp;
  final int rxBytes;
  final int txBytes;

  const InstalledApp({
    required this.packageName,
    required this.label,
    required this.uid,
    required this.systemApp,
    required this.rxBytes,
    required this.txBytes,
  });

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) => InstalledApp(
        packageName: map['packageName'] as String? ?? '',
        label: map['label'] as String? ?? '',
        uid: map['uid'] as int? ?? 0,
        systemApp: map['systemApp'] as bool? ?? false,
        rxBytes: map['rxBytes'] as int? ?? -1,
        txBytes: map['txBytes'] as int? ?? -1,
      );

  int get totalBytes {
    if (rxBytes < 0 || txBytes < 0) return -1;
    return rxBytes + txBytes;
  }

  String get trafficLabel {
    final total = totalBytes;
    if (total < 0) return '需授权';
    if (total < 1024) return '$total B';
    if (total < 1024 * 1024) {
      return '${(total / 1024).toStringAsFixed(1)} KB';
    }
    if (total < 1024 * 1024 * 1024) {
      return '${(total / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(total / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
