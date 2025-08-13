/// 救援数据模型
///
/// 用于表示一个救援任务的基本信息
/// 包含救援ID、描述、位置、海拔、创建时间等信息
class RescueModel {
  /// 救援ID - 随机4位数字
  final String id;

  /// 救援描述
  final String description;

  /// 救援地点经纬度
  final LocationCoordinate location;

  /// 救援地点海拔（米）
  final double altitude;

  /// 创建时间
  final DateTime createdAt;

  /// 创建者ID
  final String createdBy;

  /// 是否激活状态
  final bool isActive;

  const RescueModel({
    required this.id,
    required this.description,
    required this.location,
    required this.altitude,
    required this.createdAt,
    required this.createdBy,
    this.isActive = true,
  });

  /// 从JSON创建救援模型
  factory RescueModel.fromJson(Map<String, dynamic> json) {
    return RescueModel(
      id: json['id'] as String,
      description: json['description'] as String,
      location:
          LocationCoordinate.fromJson(json['location'] as Map<String, dynamic>),
      altitude: (json['altitude'] as num).toDouble(),
      // createAt:  "createdAt": { "_seconds": 1755072629, "_nanoseconds": 950000000  }
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt']['_seconds'] * 1000),
      createdBy: json['createdBy'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'location': location.toJson(),
      'altitude': altitude,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'isActive': isActive,
    };
  }

  /// 创建副本
  RescueModel copyWith({
    String? id,
    String? description,
    LocationCoordinate? location,
    double? altitude,
    DateTime? createdAt,
    String? createdBy,
    bool? isActive,
  }) {
    return RescueModel(
      id: id ?? this.id,
      description: description ?? this.description,
      location: location ?? this.location,
      altitude: altitude ?? this.altitude,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RescueModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RescueModel(id: $id, description: $description, location: $location, altitude: $altitude, createdAt: $createdAt, createdBy: $createdBy, isActive: $isActive)';
  }
}

/// 位置坐标模型
///
/// 用于表示经纬度坐标信息
class LocationCoordinate {
  /// 纬度
  final double latitude;

  /// 经度
  final double longitude;

  const LocationCoordinate({
    required this.latitude,
    required this.longitude,
  });

  /// 从JSON创建位置坐标
  factory LocationCoordinate.fromJson(Map<String, dynamic> json) {
    return LocationCoordinate(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// 创建副本
  LocationCoordinate copyWith({
    double? latitude,
    double? longitude,
  }) {
    return LocationCoordinate(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationCoordinate &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() {
    return 'LocationCoordinate(latitude: $latitude, longitude: $longitude)';
  }
}
