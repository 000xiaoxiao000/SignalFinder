class CellSignal {
  final String radio;
  final bool registered;
  final int level;
  final int? dbm;
  final int? asu;
  final String? ci;
  final int? tac;
  final int? pci;
  final int? arfcn;
  final String operatorName;
  final String distanceLabel;
  final String distanceMethod;
  final String refreshNote;
  final int? estimatedDistanceMeters;
  final double? estimatedLatitude;
  final double? estimatedLongitude;
  final int? estimationConfidenceMeters;
  final bool fallback;

  const CellSignal({
    required this.radio,
    required this.registered,
    required this.level,
    required this.dbm,
    required this.asu,
    required this.ci,
    required this.tac,
    required this.pci,
    required this.arfcn,
    required this.operatorName,
    required this.distanceLabel,
    required this.distanceMethod,
    required this.refreshNote,
    required this.estimatedDistanceMeters,
    required this.estimatedLatitude,
    required this.estimatedLongitude,
    required this.estimationConfidenceMeters,
    this.fallback = false,
  });

  static int? _intFromMapValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory CellSignal.fromMap(Map<dynamic, dynamic> map) => CellSignal(
        radio: map['radio'] as String? ?? 'Unknown',
        registered: map['registered'] as bool? ?? false,
        level: _intFromMapValue(map['level']) ?? 0,
        dbm: _intFromMapValue(map['dbm']),
        asu: _intFromMapValue(map['asu']),
        ci: map['ci']?.toString(),
        tac: _intFromMapValue(map['tac']),
        pci: _intFromMapValue(map['pci']),
        arfcn: _intFromMapValue(map['arfcn']),
        operatorName: map['operatorName'] as String? ?? '',
        distanceLabel: map['distanceLabel'] as String? ?? '需至少3个有点位的小区',
        distanceMethod: map['distanceMethod'] as String? ?? 'WLS待计算',
        refreshNote: map['refreshNote'] as String? ?? '',
        estimatedDistanceMeters:
            _intFromMapValue(map['estimatedDistanceMeters']),
        estimatedLatitude: (map['estimatedLatitude'] as num?)?.toDouble(),
        estimatedLongitude: (map['estimatedLongitude'] as num?)?.toDouble(),
        estimationConfidenceMeters:
            _intFromMapValue(map['estimationConfidenceMeters']),
        fallback: map['fallback'] as bool? ?? false,
      );

  String get strengthLabel {
    if (level >= 4) return '极强';
    if (level == 3) return '良好';
    if (level == 2) return '一般';
    if (level == 1) return '较弱';
    return '未知';
  }

  String get displayName => registered ? '当前服务小区' : '邻近小区';

  String get lockId => [
        radio,
        pci?.toString() ?? '--',
        tac?.toString() ?? '--',
        ci ?? '--',
        arfcn?.toString() ?? '--',
      ].join('|');
}
