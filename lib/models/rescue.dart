import 'package:latlong2/latlong.dart';

/// 救援信息模型
class Rescue {
  final String id; // 4位数字救援号
  final String description; // 救援描述
  final LatLng location; // 救援地点
  final double? altitude; // 海拔高度
  final DateTime createdAt; // 创建时间
  final String createdBy; // 创建者ID
  final bool isActive; // 是否活跃

  const Rescue({
    required this.id,
    required this.description,
    required this.location,
    this.altitude,
    required this.createdAt,
    required this.createdBy,
    this.isActive = true,
  });

  /// 从JSON创建Rescue对象
  factory Rescue.fromJson(Map<String, dynamic> json) {
    return Rescue(
      id: json['id'] as String,
      description: json['description'] as String,
      location: LatLng(
        json['location']['latitude'] as double,
        json['location']['longitude'] as double,
      ),
      altitude: ((json['altitude'] ?? 0)).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'altitude': altitude,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'isActive': isActive,
    };
  }

  /// 复制并修改部分属性
  Rescue copyWith({
    String? id,
    String? description,
    LatLng? location,
    double? altitude,
    DateTime? createdAt,
    String? createdBy,
    bool? isActive,
  }) {
    return Rescue(
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
  String toString() {
    return 'Rescue(id: $id, description: $description, location: $location, altitude: $altitude, createdAt: $createdAt, createdBy: $createdBy, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rescue &&
        other.id == id &&
        other.description == description &&
        other.location == location &&
        other.altitude == altitude &&
        other.createdAt == createdAt &&
        other.createdBy == createdBy &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      description,
      location,
      altitude,
      createdAt,
      createdBy,
      isActive,
    );
  }
}
