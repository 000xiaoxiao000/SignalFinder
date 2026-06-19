class InstalledApp {
  final String packageName;
  final String label;
  final int uid;
  final bool systemApp;

  const InstalledApp({
    required this.packageName,
    required this.label,
    required this.uid,
    required this.systemApp,
  });

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) => InstalledApp(
        packageName: map['packageName'] as String? ?? '',
        label: map['label'] as String? ?? '',
        uid: map['uid'] as int? ?? 0,
        systemApp: map['systemApp'] as bool? ?? false,
      );
}
