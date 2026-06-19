class AppWhitelistVpnStatus {
  final bool running;
  final List<String> allowedPackages;
  final String message;

  const AppWhitelistVpnStatus({
    required this.running,
    required this.allowedPackages,
    required this.message,
  });

  factory AppWhitelistVpnStatus.empty() => const AppWhitelistVpnStatus(
        running: false,
        allowedPackages: [],
        message: '白名单模式未开启',
      );

  factory AppWhitelistVpnStatus.fromMap(Map<dynamic, dynamic> map) {
    final rawPackages = map['allowedPackages'] as List<dynamic>? ?? const [];
    return AppWhitelistVpnStatus(
      running: map['running'] as bool? ?? false,
      allowedPackages: rawPackages.map((item) => item.toString()).toList(),
      message: map['message'] as String? ?? '',
    );
  }
}
