import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// 权限服务
/// 
/// 负责管理应用所需的各种权限，包括位置权限、通知权限等
/// 提供统一的权限请求和检查接口
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// 获取单例实例
  static PermissionService get instance => _instance;

  /// 检查位置权限状态
  Future<PermissionStatus> checkLocationPermission() async {
    return await Permission.location.status;
  }

  /// 检查后台位置权限状态
  Future<PermissionStatus> checkBackgroundLocationPermission() async {
    return await Permission.locationAlways.status;
  }

  /// 检查通知权限状态
  Future<PermissionStatus> checkNotificationPermission() async {
    return await Permission.notification.status;
  }

  /// 请求位置权限
  Future<PermissionStatus> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status;
  }

  /// 请求后台位置权限
  Future<PermissionStatus> requestBackgroundLocationPermission() async {
    // 先确保有基础位置权限
    final locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      final newStatus = await Permission.location.request();
      if (!newStatus.isGranted) {
        return newStatus;
      }
    }

    // 请求后台位置权限
    final backgroundStatus = await Permission.locationAlways.request();
    return backgroundStatus;
  }

  /// 请求通知权限
  Future<PermissionStatus> requestNotificationPermission() async {
    return await Permission.notification.request();
  }

  /// 检查是否有位置权限
  Future<bool> hasLocationPermission() async {
    final status = await checkLocationPermission();
    return status.isGranted;
  }

  /// 检查是否有后台位置权限
  Future<bool> hasBackgroundLocationPermission() async {
    final status = await checkBackgroundLocationPermission();
    return status.isGranted;
  }

  /// 检查是否有通知权限
  Future<bool> hasNotificationPermission() async {
    final status = await checkNotificationPermission();
    return status.isGranted;
  }

  /// 请求所有必要权限
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.notification,
    ];

    return await permissions.request();
  }

  /// 检查所有权限状态
  Future<Map<Permission, PermissionStatus>> checkAllPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.notification,
    ];

    final statuses = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      statuses[permission] = await permission.status;
    }

    return statuses;
  }

  /// 显示权限说明对话框
  Future<bool?> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '去设置',
    String cancelText = '取消',
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  /// 显示位置权限说明对话框
  Future<bool?> showLocationPermissionDialog(BuildContext context) async {
    return await showPermissionDialog(
      context,
      title: '位置权限',
      message: '救援APP需要获取您的位置信息来记录轨迹和共享位置。请在设置中允许位置权限。',
    );
  }

  /// 显示后台位置权限说明对话框
  Future<bool?> showBackgroundLocationPermissionDialog(BuildContext context) async {
    return await showPermissionDialog(
      context,
      title: '后台位置权限',
      message: '为了在锁屏状态下继续记录轨迹，救援APP需要后台位置权限。请在设置中选择"始终允许"位置权限。',
    );
  }

  /// 显示通知权限说明对话框
  Future<bool?> showNotificationPermissionDialog(BuildContext context) async {
    return await showPermissionDialog(
      context,
      title: '通知权限',
      message: '救援APP需要发送通知来提醒您轨迹记录状态。请在设置中允许通知权限。',
    );
  }

  /// 打开应用设置页面
  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  /// 获取权限状态描述
  String getPermissionStatusDescription(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '已授权';
      case PermissionStatus.denied:
        return '已拒绝';
      case PermissionStatus.restricted:
        return '受限制';
      case PermissionStatus.limited:
        return '有限授权';
      case PermissionStatus.permanentlyDenied:
        return '永久拒绝';
      case PermissionStatus.provisional:
        return '临时授权';
    }
  }

  /// 检查权限是否被永久拒绝
  bool isPermanentlyDenied(PermissionStatus status) {
    return status == PermissionStatus.permanentlyDenied;
  }

  /// 检查是否需要显示权限说明
  Future<bool> shouldShowRequestPermissionRationale(Permission permission) async {
    return await permission.shouldShowRequestRationale;
  }

  /// 一键请求位置相关权限
  Future<LocationPermissionResult> requestLocationPermissions() async {
    // 1. 请求基础位置权限
    final locationStatus = await requestLocationPermission();
    if (!locationStatus.isGranted) {
      return LocationPermissionResult(
        locationGranted: false,
        backgroundLocationGranted: false,
        notificationGranted: false,
        message: '位置权限被拒绝',
      );
    }

    // 2. 请求后台位置权限
    final backgroundStatus = await requestBackgroundLocationPermission();
    
    // 3. 请求通知权限
    final notificationStatus = await requestNotificationPermission();

    return LocationPermissionResult(
      locationGranted: locationStatus.isGranted,
      backgroundLocationGranted: backgroundStatus.isGranted,
      notificationGranted: notificationStatus.isGranted,
      message: _getPermissionResultMessage(locationStatus, backgroundStatus, notificationStatus),
    );
  }

  /// 获取权限结果消息
  String _getPermissionResultMessage(
    PermissionStatus location,
    PermissionStatus background,
    PermissionStatus notification,
  ) {
    if (location.isGranted && background.isGranted && notification.isGranted) {
      return '所有权限已授权';
    } else if (location.isGranted && background.isGranted) {
      return '位置权限已授权，通知权限未授权';
    } else if (location.isGranted) {
      return '基础位置权限已授权，后台位置权限未授权';
    } else {
      return '位置权限未授权';
    }
  }
}

/// 位置权限请求结果
class LocationPermissionResult {
  final bool locationGranted;
  final bool backgroundLocationGranted;
  final bool notificationGranted;
  final String message;

  const LocationPermissionResult({
    required this.locationGranted,
    required this.backgroundLocationGranted,
    required this.notificationGranted,
    required this.message,
  });

  /// 是否有基础功能权限（至少有位置权限）
  bool get hasBasicPermissions => locationGranted;

  /// 是否有完整功能权限（所有权限都有）
  bool get hasFullPermissions => locationGranted && backgroundLocationGranted && notificationGranted;

  @override
  String toString() {
    return 'LocationPermissionResult(location: $locationGranted, background: $backgroundLocationGranted, notification: $notificationGranted, message: $message)';
  }
}
