import 'package:flutter/material.dart';

/// 用户模型
class User {
  final String id; // 用户ID
  final String name; // 用户名称
  final Color trackColor; // 轨迹颜色
  final DateTime createdAt; // 创建时间
  final DateTime? lastActiveAt; // 最后活跃时间
  final bool isOnline; // 是否在线

  const User({
    required this.id,
    required this.name,
    required this.trackColor,
    required this.createdAt,
    this.lastActiveAt,
    this.isOnline = false,
  });

  /// 从JSON创建User对象
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      trackColor: Color(json['trackColor'] as int? ?? 0xFF2196F3),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt'] as String)
          : null,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trackColor': trackColor.value,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  /// 复制并修改部分属性
  User copyWith({
    String? id,
    String? name,
    Color? trackColor,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isOnline,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      trackColor: trackColor ?? this.trackColor,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  /// 生成随机轨迹颜色
  static Color generateRandomColor(String userId) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
      Colors.deepOrange,
      Colors.deepPurple,
      Colors.lightBlue,
      Colors.lightGreen,
    ];

    // 基于用户ID生成一致的颜色
    final hash = userId.hashCode;
    final index = hash.abs() % colors.length;
    return colors[index];
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, trackColor: $trackColor, createdAt: $createdAt, lastActiveAt: $lastActiveAt, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.trackColor == trackColor &&
        other.createdAt == createdAt &&
        other.lastActiveAt == lastActiveAt &&
        other.isOnline == isOnline;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      trackColor,
      createdAt,
      lastActiveAt,
      isOnline,
    );
  }
}
