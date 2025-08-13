import 'track_point_model.dart';

/// 用户轨迹数据模型
/// 
/// 用于表示单个用户在救援过程中的完整轨迹记录
/// 包含用户ID和轨迹点列表
class UserTrackModel {
  /// 用户ID
  final String userId;
  
  /// 轨迹点列表
  final List<TrackPointModel> points;
  
  /// 文档索引（用于Firestore分片存储）
  final int index;

  const UserTrackModel({
    required this.userId,
    required this.points,
    this.index = 0,
  });

  /// 从JSON创建用户轨迹
  factory UserTrackModel.fromJson(Map<String, dynamic> json) {
    final pointsData = json['points'] as List<dynamic>? ?? [];
    final points = pointsData.map((pointStr) {
      if (pointStr is String) {
        return TrackPointModel.fromCompressedString(pointStr);
      } else if (pointStr is Map<String, dynamic>) {
        return TrackPointModel.fromJson(pointStr);
      } else {
        throw ArgumentError('Invalid point data format');
      }
    }).toList();

    return UserTrackModel(
      userId: json['user_id'] as String,
      points: points,
      index: json['index'] as int? ?? 0,
    );
  }

  /// 转换为JSON（使用压缩字符串格式）
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'points': points.map((point) => point.toCompressedString()).toList(),
      'index': index,
    };
  }

  /// 转换为JSON（使用完整对象格式）
  Map<String, dynamic> toJsonFull() {
    return {
      'user_id': userId,
      'points': points.map((point) => point.toJson()).toList(),
      'index': index,
    };
  }

  /// 获取Firestore文档ID
  String get documentId => index == 0 ? 'user-$userId' : 'user-$userId-$index';

  /// 添加轨迹点
  UserTrackModel addPoint(TrackPointModel point) {
    final newPoints = List<TrackPointModel>.from(points)..add(point);
    return copyWith(points: newPoints);
  }

  /// 添加多个轨迹点
  UserTrackModel addPoints(List<TrackPointModel> newPoints) {
    final allPoints = List<TrackPointModel>.from(points)..addAll(newPoints);
    return copyWith(points: allPoints);
  }

  /// 移除轨迹点
  UserTrackModel removePoint(TrackPointModel point) {
    final newPoints = List<TrackPointModel>.from(points)..remove(point);
    return copyWith(points: newPoints);
  }

  /// 清空轨迹点
  UserTrackModel clearPoints() {
    return copyWith(points: []);
  }

  /// 获取最后一个轨迹点
  TrackPointModel? get lastPoint => points.isNotEmpty ? points.last : null;

  /// 获取第一个轨迹点
  TrackPointModel? get firstPoint => points.isNotEmpty ? points.first : null;

  /// 获取轨迹点数量
  int get pointCount => points.length;

  /// 是否为空轨迹
  bool get isEmpty => points.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => points.isNotEmpty;

  /// 获取轨迹的时间范围
  DateTimeRange? get timeRange {
    if (points.isEmpty) return null;
    
    final timestamps = points.map((p) => p.timestamp).toList()..sort();
    return DateTimeRange(
      start: DateTime.fromMillisecondsSinceEpoch(timestamps.first),
      end: DateTime.fromMillisecondsSinceEpoch(timestamps.last),
    );
  }

  /// 获取已标记的轨迹点
  List<TrackPointModel> get markedPoints => points.where((p) => p.marked).toList();

  /// 获取未标记的轨迹点
  List<TrackPointModel> get unmarkedPoints => points.where((p) => !p.marked).toList();

  /// 估算数据大小（字节）
  int get estimatedSizeInBytes {
    // 每个压缩字符串大约50-60字节，加上JSON结构开销
    const avgPointSize = 60;
    const jsonOverhead = 100;
    return (points.length * avgPointSize) + jsonOverhead;
  }

  /// 是否接近Firestore文档大小限制（1MB）
  bool get isNearSizeLimit {
    const maxSize = 1024 * 1024; // 1MB
    const safetyMargin = 0.8; // 80%安全边界
    return estimatedSizeInBytes > (maxSize * safetyMargin);
  }

  /// 创建副本
  UserTrackModel copyWith({
    String? userId,
    List<TrackPointModel>? points,
    int? index,
  }) {
    return UserTrackModel(
      userId: userId ?? this.userId,
      points: points ?? this.points,
      index: index ?? this.index,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserTrackModel &&
        other.userId == userId &&
        other.index == index;
  }

  @override
  int get hashCode => userId.hashCode ^ index.hashCode;

  @override
  String toString() {
    return 'UserTrackModel(userId: $userId, pointCount: $pointCount, index: $index, sizeKB: ${(estimatedSizeInBytes / 1024).toStringAsFixed(1)})';
  }
}

/// 时间范围类
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  const DateTimeRange({
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);

  @override
  String toString() {
    return 'DateTimeRange(start: $start, end: $end, duration: $duration)';
  }
}
