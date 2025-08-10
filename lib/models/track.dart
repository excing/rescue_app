import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'location_point.dart';

/// 轨迹模型
class Track {
  final String id; // 轨迹ID
  final String userId; // 用户ID
  final String userName; // 用户名称
  final String rescueId; // 救援ID
  final List<LocationPoint> points; // 轨迹点列表
  final Color color; // 轨迹颜色
  final DateTime startTime; // 开始时间
  final DateTime? endTime; // 结束时间
  final bool isActive; // 是否活跃
  final double? totalDistance; // 总距离（米）
  final Duration? totalDuration; // 总时长

  const Track({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rescueId,
    required this.points,
    required this.color,
    required this.startTime,
    this.endTime,
    this.isActive = true,
    this.totalDistance,
    this.totalDuration,
  });

  /// 从JSON创建Track对象
  factory Track.fromJson(Map<String, dynamic> json) {
    final pointsList = json['points'] as List<dynamic>? ?? [];
    final points = pointsList
        .map((point) => LocationPoint.fromJson(point as Map<String, dynamic>))
        .toList();

    return Track(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      rescueId: json['rescueId'] as String,
      points: points,
      color: Color(json['color'] as int? ?? 0xFF2196F3),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      totalDistance: json['totalDistance'] as double?,
      totalDuration: json['totalDuration'] != null
          ? Duration(milliseconds: json['totalDuration'] as int)
          : null,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'rescueId': rescueId,
      'points': points.map((point) => point.toJson()).toList(),
      'color': color.value,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isActive': isActive,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration?.inMilliseconds,
    };
  }

  /// 添加新的位置点
  Track addPoint(LocationPoint point) {
    final newPoints = List<LocationPoint>.from(points)..add(point);
    return copyWith(
      points: newPoints,
      totalDistance: _calculateTotalDistance(newPoints),
      totalDuration: _calculateTotalDuration(newPoints),
    );
  }

  /// 获取最新的位置点
  LocationPoint? get latestPoint {
    return points.isNotEmpty ? points.last : null;
  }

  /// 获取轨迹的边界框（返回最小和最大坐标）
  Map<String, LatLng>? get bounds {
    if (points.isEmpty) return null;

    double minLat = points.first.position.latitude;
    double maxLat = points.first.position.latitude;
    double minLng = points.first.position.longitude;
    double maxLng = points.first.position.longitude;

    for (final point in points) {
      minLat =
          minLat < point.position.latitude ? minLat : point.position.latitude;
      maxLat =
          maxLat > point.position.latitude ? maxLat : point.position.latitude;
      minLng =
          minLng < point.position.longitude ? minLng : point.position.longitude;
      maxLng =
          maxLng > point.position.longitude ? maxLng : point.position.longitude;
    }

    return {
      'southwest': LatLng(minLat, minLng),
      'northeast': LatLng(maxLat, maxLng),
    };
  }

  /// 计算总距离
  double _calculateTotalDistance(List<LocationPoint> points) {
    if (points.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 1; i < points.length; i++) {
      total += points[i - 1].distanceTo(points[i]);
    }
    return total;
  }

  /// 计算总时长
  Duration _calculateTotalDuration(List<LocationPoint> points) {
    if (points.length < 2) return Duration.zero;

    return points.last.timestamp.difference(points.first.timestamp);
  }

  /// 复制并修改部分属性
  Track copyWith({
    String? id,
    String? userId,
    String? userName,
    String? rescueId,
    List<LocationPoint>? points,
    Color? color,
    DateTime? startTime,
    DateTime? endTime,
    bool? isActive,
    double? totalDistance,
    Duration? totalDuration,
  }) {
    return Track(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      rescueId: rescueId ?? this.rescueId,
      points: points ?? this.points,
      color: color ?? this.color,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }

  @override
  String toString() {
    return 'Track(id: $id, userId: $userId, userName: $userName, rescueId: $rescueId, pointsCount: ${points.length}, color: $color, startTime: $startTime, endTime: $endTime, isActive: $isActive, totalDistance: $totalDistance, totalDuration: $totalDuration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Track &&
        other.id == id &&
        other.userId == userId &&
        other.userName == userName &&
        other.rescueId == rescueId &&
        other.color == color &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      userName,
      rescueId,
      color,
      startTime,
      endTime,
      isActive,
    );
  }
}
