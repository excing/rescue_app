import 'package:latlong2/latlong.dart';

/// 位置点模型
class LocationPoint {
  final LatLng position; // 经纬度位置
  final double? altitude; // 海拔高度（米）
  final double? accuracy; // 精度（米）
  final double? speed; // 速度（米/秒）
  final double? heading; // 方向角（度）
  final DateTime timestamp; // 时间戳
  final String userId; // 用户ID
  final String rescueId; // 救援ID
  final bool marked; // 是否已搜索/标记

  const LocationPoint({
    required this.position,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.timestamp,
    required this.userId,
    required this.rescueId,
    this.marked = false,
  });

  /// 从JSON创建LocationPoint对象（兼容旧结构）
  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      position: LatLng(
        json['position']['latitude'] as double,
        json['position']['longitude'] as double,
      ),
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
      rescueId: json['rescueId'] as String,
      marked: json['marked'] as bool? ?? false,
    );
  }

  /// 转换为JSON（兼容旧结构）
  Map<String, dynamic> toJson() {
    return {
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'rescueId': rescueId,
      'marked': marked,
    };
  }

  /// 复制并修改部分属性
  LocationPoint copyWith({
    LatLng? position,
    double? altitude,
    double? accuracy,
    double? speed,
    double? heading,
    DateTime? timestamp,
    String? userId,
    String? rescueId,
    bool? marked,
  }) {
    return LocationPoint(
      position: position ?? this.position,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      rescueId: rescueId ?? this.rescueId,
      marked: marked ?? this.marked,
    );
  }

  /// 计算与另一个位置点的距离（米）
  double distanceTo(LocationPoint other) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, position, other.position);
  }

  /// 计算与另一个位置点的时间差（秒）
  double timeDifferenceTo(LocationPoint other) {
    return other.timestamp.difference(timestamp).inMilliseconds / 1000.0;
  }

  /// 计算移动速度（米/秒）
  double? calculateSpeedTo(LocationPoint other) {
    final distance = distanceTo(other);
    final timeDiff = timeDifferenceTo(other);
    if (timeDiff > 0) {
      return distance / timeDiff;
    }
    return null;
  }

  /// --- 紧凑CSV序列化，满足Firestore 1MB文档限制 ---
  /// 经纬度缩放为1e6（~0.11m），海拔/精度为厘米，时间戳ms
  int get latE6 => (position.latitude * 1e6).round();
  int get lngE6 => (position.longitude * 1e6).round();
  int get altitudeCm => ((altitude ?? 0) * 100).round();
  int get accuracyCm => ((accuracy ?? 0) * 100).round();
  int get timestampMs => timestamp.millisecondsSinceEpoch;

  /// 生成紧凑CSV："lat,lng,alt,acc,marked,timestamp"
  String toCompactCSV() {
    final m = marked ? 1 : 0;
    return '$latE6,$lngE6,$altitudeCm,$accuracyCm,$m,$timestampMs';
  }

  /// 从紧凑CSV解析
  static LocationPoint fromCompactCSV(
    String csv, {
    required String userId,
    required String rescueId,
  }) {
    final parts = csv.split(',');
    if (parts.length < 6) {
      throw FormatException('Invalid compact CSV point: $csv');
    }
    final lat = int.parse(parts[0]) / 1e6;
    final lng = int.parse(parts[1]) / 1e6;
    final altCm = int.parse(parts[2]);
    final accCm = int.parse(parts[3]);
    final marked = parts[4] == '1';
    final ts = int.parse(parts[5]);
    return LocationPoint(
      position: LatLng(lat, lng),
      altitude: altCm / 100.0,
      accuracy: accCm / 100.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      userId: userId,
      rescueId: rescueId,
      marked: marked,
    );
  }

  @override
  String toString() {
    return 'LocationPoint(position: $position, altitude: $altitude, accuracy: $accuracy, speed: $speed, heading: $heading, timestamp: $timestamp, userId: $userId, rescueId: $rescueId, marked: $marked)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationPoint &&
        other.position == position &&
        other.altitude == altitude &&
        other.accuracy == accuracy &&
        other.speed == speed &&
        other.heading == heading &&
        other.timestamp == timestamp &&
        other.userId == userId &&
        other.rescueId == rescueId &&
        other.marked == marked;
  }

  @override
  int get hashCode {
    return Object.hash(
      position,
      altitude,
      accuracy,
      speed,
      heading,
      timestamp,
      userId,
      rescueId,
      marked,
    );
  }
}
