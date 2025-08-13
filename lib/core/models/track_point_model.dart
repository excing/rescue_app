/// 轨迹点数据模型
/// 
/// 用于表示用户在救援过程中的位置轨迹点
/// 包含精确的位置信息、时间戳、标记状态等
class TrackPointModel {
  /// 纬度 - int32格式，精确到0.1米
  final int latitude;
  
  /// 经度 - int32格式，精确到0.1米  
  final int longitude;
  
  /// 海拔 - int32格式，单位厘米
  final int altitude;
  
  /// 精度 - int32格式，单位厘米
  final int accuracy;
  
  /// 时间戳 - int64格式，毫秒级
  final int timestamp;
  
  /// 是否已标记/已搜索
  final bool marked;

  const TrackPointModel({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.timestamp,
    this.marked = false,
  });

  /// 从double类型的经纬度创建轨迹点（转换为int32格式）
  factory TrackPointModel.fromDouble({
    required double latitude,
    required double longitude,
    required double altitude,
    required double accuracy,
    required DateTime dateTime,
    bool marked = false,
  }) {
    return TrackPointModel(
      latitude: (latitude * 10000000).round(), // 精确到0.1米
      longitude: (longitude * 10000000).round(), // 精确到0.1米
      altitude: (altitude * 100).round(), // 转换为厘米
      accuracy: (accuracy * 100).round(), // 转换为厘米
      timestamp: dateTime.millisecondsSinceEpoch,
      marked: marked,
    );
  }

  /// 从压缩字符串创建轨迹点
  /// 格式: "latitude,longitude,altitude,accuracy,marked,timestamp"
  factory TrackPointModel.fromCompressedString(String compressed) {
    final parts = compressed.split(',');
    if (parts.length != 6) {
      throw ArgumentError('Invalid compressed string format');
    }
    
    return TrackPointModel(
      latitude: int.parse(parts[0]),
      longitude: int.parse(parts[1]),
      altitude: int.parse(parts[2]),
      accuracy: int.parse(parts[3]),
      marked: parts[4] == 'true',
      timestamp: int.parse(parts[5]),
    );
  }

  /// 从JSON创建轨迹点
  factory TrackPointModel.fromJson(Map<String, dynamic> json) {
    return TrackPointModel(
      latitude: json['latitude'] as int,
      longitude: json['longitude'] as int,
      altitude: json['altitude'] as int,
      accuracy: json['accuracy'] as int,
      timestamp: json['timestamp'] as int,
      marked: json['marked'] as bool? ?? false,
    );
  }

  /// 转换为压缩字符串格式
  /// 格式: "latitude,longitude,altitude,accuracy,marked,timestamp"
  String toCompressedString() {
    return '$latitude,$longitude,$altitude,$accuracy,$marked,$timestamp';
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': timestamp,
      'marked': marked,
    };
  }

  /// 获取double类型的纬度
  double get latitudeDouble => latitude / 10000000.0;

  /// 获取double类型的经度
  double get longitudeDouble => longitude / 10000000.0;

  /// 获取double类型的海拔（米）
  double get altitudeDouble => altitude / 100.0;

  /// 获取double类型的精度（米）
  double get accuracyDouble => accuracy / 100.0;

  /// 获取DateTime类型的时间
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// 是否为停止记录标记点（经纬度都为0）
  bool get isStopMarker => latitude == 0 && longitude == 0;

  /// 创建停止记录标记点
  factory TrackPointModel.createStopMarker() {
    return TrackPointModel(
      latitude: 0,
      longitude: 0,
      altitude: 0,
      accuracy: 0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      marked: false,
    );
  }

  /// 创建副本
  TrackPointModel copyWith({
    int? latitude,
    int? longitude,
    int? altitude,
    int? accuracy,
    int? timestamp,
    bool? marked,
  }) {
    return TrackPointModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      marked: marked ?? this.marked,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrackPointModel &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode ^ timestamp.hashCode;

  @override
  String toString() {
    return 'TrackPointModel(lat: ${latitudeDouble.toStringAsFixed(7)}, lng: ${longitudeDouble.toStringAsFixed(7)}, alt: ${altitudeDouble.toStringAsFixed(2)}m, acc: ${accuracyDouble.toStringAsFixed(2)}m, time: $dateTime, marked: $marked)';
  }
}
