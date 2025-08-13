import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track_point_model.dart';
import 'database_service.dart';

/// 后台位置服务
///
/// 使用 flutter_background_service 实现后台位置追踪
/// 支持在应用后台、锁屏状态下持续记录位置轨迹
@pragma('vm:entry-point')
class BackgroundLocationService {
  static const String notificationChannelId = 'rescue_tracking_channel';
  static const String notificationChannelTitle = '救援轨迹记录';
  static const String notificationChannelDescription = '准备开始记录位置轨迹';

  static const String _serviceKey = 'background_location_service';
  static const String _rescueIdKey = 'current_rescue_id';
  static const String _userIdKey = 'current_user_id';
  static const String _isTrackingKey = 'is_tracking';

  // 定位设置
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 3, // 3米距离过滤，提高精度
    timeLimit: Duration(seconds: 30),
  );

  /// 初始化后台服务
  static Future<void> initializeService() async {
    try {
      final service = FlutterBackgroundService();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        notificationChannelId, // id
        notificationChannelTitle, // title
        description: notificationChannelDescription, // description
        importance: Importance.low, // importance must be at low or higher level
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 配置后台服务
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: notificationChannelId,
          initialNotificationTitle: notificationChannelTitle,
          initialNotificationContent: notificationChannelDescription,
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      debugPrint('后台服务初始化成功');
    } catch (e) {
      debugPrint('后台服务初始化失败: $e');
    }
  }

  /// 开始后台位置追踪
  static Future<bool> startTracking(String rescueId, String userId) async {
    try {
      debugPrint('开始启动后台位置追踪: rescueId=$rescueId, userId=$userId');

      // 检查位置权限
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('位置权限不足，无法启动后台追踪');
        return false;
      }

      // 保存追踪参数到本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rescueIdKey, rescueId);
      await prefs.setString(_userIdKey, userId);
      await prefs.setBool(_isTrackingKey, true);
      debugPrint('追踪参数已保存到本地存储');

      // 启动后台服务
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      debugPrint('后台服务运行状态: $isRunning');

      if (!isRunning) {
        debugPrint('启动后台服务...');
        final success = await service.startService();
        debugPrint('后台服务启动结果: $success');

        // 等待服务启动
        await Future.delayed(const Duration(seconds: 2));
      }

      // 发送开始追踪命令
      debugPrint('发送开始追踪命令...');
      service.invoke('start_tracking', {
        'rescue_id': rescueId,
        'user_id': userId,
      });

      debugPrint('后台位置追踪启动成功');
      return true;
    } catch (e) {
      debugPrint('启动后台位置追踪失败: $e');
      return false;
    }
  }

  /// 停止后台位置追踪
  static Future<void> stopTracking() async {
    try {
      final service = FlutterBackgroundService();

      // 发送停止追踪命令
      service.invoke('stop_tracking');

      // 清除本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rescueIdKey);
      await prefs.remove(_userIdKey);
      await prefs.setBool(_isTrackingKey, false);

      // 停止后台服务
      service.invoke('stop_service');
    } catch (e) {
      debugPrint('停止后台位置追踪失败: $e');
    }
  }

  /// 检查是否正在追踪
  static Future<bool> isTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isTrackingKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 获取当前追踪的救援信息
  static Future<Map<String, String?>> getCurrentTrackingInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'rescue_id': prefs.getString(_rescueIdKey),
        'user_id': prefs.getString(_userIdKey),
      };
    } catch (e) {
      return {'rescue_id': null, 'user_id': null};
    }
  }

  /// Android/iOS 前台服务入口点
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // 确保插件绑定已初始化
    DartPluginRegistrant.ensureInitialized();

    String? currentRescueId;
    String? currentUserId;
    Timer? locationTimer;

    // 监听来自主应用的命令
    service.on('start_tracking').listen((event) async {
      final data = event!;
      currentRescueId = data['rescue_id'] as String?;
      currentUserId = data['user_id'] as String?;

      // 更新通知
      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: '救援轨迹记录中',
          content: '正在记录位置轨迹 - 救援号: $currentRescueId',
        );
      }

      // 开始定期获取位置
      locationTimer =
          _startLocationTracking(service, currentRescueId!, currentUserId!);
    });

    service.on('stop_tracking').listen((event) async {
      locationTimer?.cancel();

      // 添加停止标记点
      if (currentRescueId != null && currentUserId != null) {
        await _saveStopMarker(currentRescueId!, currentUserId!);
      }

      // 更新通知
      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: '救援轨迹记录已停止',
          content: '轨迹记录已结束',
        );
      }

      // 停止服务
      service.stopSelf();
    });

    // 服务停止时的清理
    service.on('stop_service').listen((event) {
      locationTimer?.cancel();
      service.stopSelf();
    });
  }

  /// iOS 后台处理
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// 开始位置追踪
  static Timer _startLocationTracking(
      ServiceInstance service, String rescueId, String userId) {
    return Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        // 检查位置权限
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          timer.cancel();
          return;
        }

        // 获取当前位置
        final position = await Geolocator.getCurrentPosition(
            locationSettings: _locationSettings);

        // 创建轨迹点
        final trackPoint = TrackPointModel.fromDouble(
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          accuracy: position.accuracy,
          dateTime: DateTime.now(),
          marked: false,
        );

        // 保存到数据库
        await _saveTrackPoint(rescueId, userId, trackPoint);

        // 更新通知内容
        if (service is AndroidServiceInstance) {
          await service.setForegroundNotificationInfo(
            title: '救援轨迹记录中',
            content:
                '位置: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          );
        }

        // 发送位置更新到主应用
        service.invoke('location_update', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitude': position.altitude,
          'accuracy': position.accuracy,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e) {
        debugPrint('后台获取位置失败: $e');

        // 如果连续失败，可以考虑停止服务
        if (service is AndroidServiceInstance) {
          await service.setForegroundNotificationInfo(
            title: '救援轨迹记录',
            content: '位置获取失败，请检查GPS设置',
          );
        }
      }
    });
  }

  /// 保存轨迹点到数据库
  static Future<void> _saveTrackPoint(
      String rescueId, String userId, TrackPointModel point) async {
    try {
      await DatabaseService.instance.insertTrackPoint(rescueId, userId, point);
    } catch (e) {
      debugPrint('后台保存轨迹点失败: $e');
    }
  }

  /// 保存停止标记点
  static Future<void> _saveStopMarker(String rescueId, String userId) async {
    try {
      final stopMarker = TrackPointModel.createStopMarker();
      await DatabaseService.instance
          .insertTrackPoint(rescueId, userId, stopMarker);
    } catch (e) {
      debugPrint('后台保存停止标记失败: $e');
    }
  }
}
