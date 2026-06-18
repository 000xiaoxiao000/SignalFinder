class RootStatus {
  final bool available;
  final bool checked;
  final String detail;

  const RootStatus({
    required this.available,
    required this.checked,
    required this.detail,
  });

  factory RootStatus.unknown() => const RootStatus(
        available: false,
        checked: false,
        detail: '尚未检测',
      );

  factory RootStatus.fromMap(Map<dynamic, dynamic> map) => RootStatus(
        available: map['available'] as bool? ?? false,
        checked: map['checked'] as bool? ?? false,
        detail: map['detail'] as String? ?? '',
      );
}

class RootCommandResult {
  final bool ok;
  final String output;
  final int exitCode;

  const RootCommandResult({
    required this.ok,
    required this.output,
    required this.exitCode,
  });

  factory RootCommandResult.empty() => const RootCommandResult(
        ok: false,
        output: '',
        exitCode: -1,
      );

  factory RootCommandResult.fromMap(Map<dynamic, dynamic> map) =>
      RootCommandResult(
        ok: map['ok'] as bool? ?? false,
        output: map['output'] as String? ?? '',
        exitCode: map['exitCode'] as int? ?? -1,
      );
}
