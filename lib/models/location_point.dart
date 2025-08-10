import 'package:latlong2/latlong.dart';

/// 位置点模型
class LocationPoint {
  final LatLng position; // 经纬度位置
  final double? altitude; // 海拔高度
  final double? accuracy; // 精度（米）
  final double? speed; // 速度（米/秒）
  final double? heading; // 方向角（度）
  final DateTime timestamp; // 时间戳
  final String userId; // 用户ID
  final String rescueId; // 救援ID

  const LocationPoint({
    required this.position,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.timestamp,
    required this.userId,
    required this.rescueId,
  });

  /// 从JSON创建LocationPoint对象
  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      position: LatLng(
        json['position']['latitude'] as double,
        json['position']['longitude'] as double,
      ),
      altitude: json['altitude'] as double?,
      accuracy: json['accuracy'] as double?,
      speed: json['speed'] as double?,
      heading: json['heading'] as double?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
      rescueId: json['rescueId'] as String,
    );
  }

  /// 转换为JSON
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

  @override
  String toString() {
    return 'LocationPoint(position: $position, altitude: $altitude, accuracy: $accuracy, speed: $speed, heading: $heading, timestamp: $timestamp, userId: $userId, rescueId: $rescueId)';
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
        other.rescueId == rescueId;
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
    );
  }
}
