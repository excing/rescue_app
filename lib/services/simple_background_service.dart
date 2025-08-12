import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'location_service.dart';
import 'optimized_storage_service.dart';
import 'storage_service.dart';
import '../models/location_point.dart';
import 'foreground_task_handler.dart';

/// 后台服务：集成前台服务以确保Android锁屏/熄屏持续定位
class SimpleBackgroundService extends ChangeNotifier {
  static final SimpleBackgroundService _instance =
      SimpleBackgroundService._internal();
  factory SimpleBackgroundService() => _instance;
  SimpleBackgroundService._internal();

  Timer? _backgroundTimer;
  bool _isRunning = false;
  String? _currentRescueId;
  String? _currentUserId;

  final LocationService _locationService = LocationService();
  final OptimizedStorageService _storageService = OptimizedStorageService();
  final StorageService _legacyStorage = StorageService();

  // 后台定位配置
  static const Duration _backgroundInterval = Duration(minutes: 1); // 每分钟定位一次
  static const Duration _foregroundInterval =
      Duration(seconds: 10); // 前台每10秒定位一次

  bool get isRunning => _isRunning;
  String? get currentRescueId => _currentRescueId;

  /// 启动后台定位服务（Android 前台服务 + 定期定位）
  Future<bool> startBackgroundTracking(String rescueId, String userId) async {
    try {
      if (_isRunning) {
        print('后台服务已在运行');
        return true;
      }

      // 初始化服务
      await _storageService.initialize();
      final locationInitialized = await _locationService.initialize();
      if (!locationInitialized) {
        print('位置服务初始化失败');
        return false;
      }

      _currentRescueId = rescueId;
      _currentUserId = userId;
      _isRunning = true;

      // Android：启动前台服务通知（如果可用）
      try {
        // 通知权限（Android 13+）
        final notiStatus = await FlutterForegroundTask.checkNotificationPermission();
        if (notiStatus != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }

        // 将上下文写入服务数据区
        await FlutterForegroundTask.saveData(key: 'userId', value: userId);
        await FlutterForegroundTask.saveData(key: 'rescueId', value: rescueId);

        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'rescue_location',
            channelName: '救援定位',
            channelDescription: '持续定位以记录救援轨迹',
            channelImportance: NotificationChannelImportance.HIGH,
            priority: NotificationPriority.HIGH,
            showBadge: true,
          ),
          iosNotificationOptions: const IOSNotificationOptions(showNotification: true),
          foregroundTaskOptions: ForegroundTaskOptions(
            eventAction: ForegroundTaskEventAction.repeat(60000),
            autoRunOnBoot: false,
            allowWakeLock: true,
            allowWifiLock: true,
          ),
        );
        await FlutterForegroundTask.startService(
          notificationTitle: '救援定位',
          notificationText: '正在持续记录轨迹',
          callback: startCallback,
        );
      } catch (e) {
        // iOS 或不支持时忽略，走Timer
      }

      // 启动定期定位（兜底）
      _startPeriodicLocation();

      print('后台定位服务启动成功');
      notifyListeners();
      return true;
    } catch (e) {
      print('启动后台定位服务失败: $e');
      return false;
    }
  }

  /// 停止后台定位服务
  Future<void> stopBackgroundTracking() async {
    try {
      // 在停止时追加一条全0经纬度的停止标记
      if (_currentRescueId != null && _currentUserId != null) {
        final stopPoint = LocationPoint(
          position: const LatLng(0, 0),
          altitude: 0,
          accuracy: 0,
          timestamp: DateTime.now(),
          userId: _currentUserId!,
          rescueId: _currentRescueId!,
          marked: false,
        );
        // 保存到两套本地存储，确保同步服务可发现
        try {
          await _legacyStorage.saveLocationPoint(stopPoint);
        } catch (_) {}
        try {
          await _storageService.saveLocationPointSmart(stopPoint);
        } catch (_) {}
      }

      _backgroundTimer?.cancel();
      _backgroundTimer = null;
      _isRunning = false;
      _currentRescueId = null;
      _currentUserId = null;

      print('后台定位服务已停止');
      notifyListeners();
    } catch (e) {
      print('停止后台定位服务失败: $e');
    }
  }

  /// 启动定期定位
  void _startPeriodicLocation() {
    // 立即执行一次定位
    _performLocationUpdate();

    // 设置定期定位
    _backgroundTimer = Timer.periodic(_backgroundInterval, (_) {
      _performLocationUpdate();
    });
  }

  /// 执行位置更新
  Future<void> _performLocationUpdate() async {
    if (!_isRunning || _currentRescueId == null || _currentUserId == null) {
      return;
    }

    try {
      print('执行后台位置更新...');

      // 获取当前位置
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        print('获取位置失败');
        return;
      }

      // 创建位置点
      final locationPoint = LocationPoint(
        position: LatLng(position.latitude, position.longitude),
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        timestamp: DateTime.now(),
        userId: _currentUserId!,
        rescueId: _currentRescueId!,
      );

      // 智能保存位置点
      final saved = await _storageService.saveLocationPointSmart(locationPoint);
      if (saved) {
        print('位置点保存成功: ${position.latitude}, ${position.longitude}');
      }

      // 通知监听器
      notifyListeners();
    } catch (e) {
      print('位置更新失败: $e');
    }
  }

  /// 切换到前台模式 - 更频繁的定位
  void switchToForegroundMode() {
    if (!_isRunning) return;

    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(_foregroundInterval, (_) {
      _performLocationUpdate();
    });
    print('切换到前台定位模式');
  }

  /// 切换到后台模式 - 较少的定位频率
  void switchToBackgroundMode() {
    if (!_isRunning) return;

    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(_backgroundInterval, (_) {
      _performLocationUpdate();
    });
    print('切换到后台定位模式');
  }

  /// 手动触发位置更新
  Future<void> manualLocationUpdate() async {
    await _performLocationUpdate();
  }

  /// 获取当前轨迹统计
  Future<Map<String, dynamic>> getCurrentTrackStats() async {
    if (_currentRescueId == null || _currentUserId == null) {
      return {};
    }

    try {
      final summaries =
          await _storageService.getTrackSummaries(_currentRescueId!);
      final userSummary = summaries.firstWhere(
        (s) => s['user_id'] == _currentUserId,
        orElse: () => {},
      );

      if (userSummary.isNotEmpty) {
        final pointCount = userSummary['point_count'] ?? 0;
        final duration = userSummary['total_duration'] ?? 0;
        final distance = userSummary['total_distance'] ?? 0.0;

        return {
          'pointCount': pointCount,
          'duration': Duration(milliseconds: duration),
          'distance': distance,
          'isActive': _isRunning,
        };
      }
    } catch (e) {
      print('获取轨迹统计失败: $e');
    }

    return {};
  }

  /// 获取最近的位置点
  Future<List<LocationPoint>> getRecentLocationPoints({int limit = 10}) async {
    if (_currentRescueId == null || _currentUserId == null) {
      return [];
    }

    return await _storageService.getCompressedLocationPoints(
      _currentRescueId!,
      _currentUserId!,
      limit: limit,
    );
  }

  /// 清理旧数据
  Future<void> cleanupOldData() async {
    try {
      await _storageService.cleanOldData();
      print('旧数据清理完成');
    } catch (e) {
      print('清理旧数据失败: $e');
    }
  }

  /// 获取存储统计
  Future<Map<String, int>> getStorageStats() async {
    return await _storageService.getStorageStats();
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    super.dispose();
  }
}

/// 应用生命周期监听器 - 处理前台/后台切换
class AppLifecycleListener extends WidgetsBindingObserver {
  final SimpleBackgroundService _backgroundService = SimpleBackgroundService();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // 应用回到前台
        print('应用回到前台');
        _backgroundService.switchToForegroundMode();
        break;
      case AppLifecycleState.paused:
        // 应用进入后台
        print('应用进入后台');
        _backgroundService.switchToBackgroundMode();
        break;
      case AppLifecycleState.detached:
        // 应用被终止
        print('应用被终止');
        _backgroundService.stopBackgroundTracking();
        break;
      default:
        break;
    }
  }
}

/// 位置权限助手
class LocationPermissionHelper {
  /// 检查并请求位置权限
  static Future<bool> checkAndRequestPermissions() async {
    try {
      // 检查位置服务
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('位置服务未启用');
        return false;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('位置权限被拒绝');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('位置权限被永久拒绝');
        return false;
      }

      print('位置权限检查通过');
      return true;
    } catch (e) {
      print('权限检查失败: $e');
      return false;
    }
  }

  /// 打开应用设置
  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      print('打开应用设置失败: $e');
    }
  }
}
