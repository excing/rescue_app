import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:latlong2/latlong.dart';
import 'location_service.dart';
import 'optimized_storage_service.dart';
import '../models/location_point.dart';

/// 顶层回调：注册任务处理器
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RescueTaskHandler());
}

/// 前台服务任务处理器：周期获取位置并保存
class RescueTaskHandler extends TaskHandler {
  final _locationService = LocationService();
  final _optimizedStorage = OptimizedStorageService();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _optimizedStorage.initialize();
    await _locationService.initialize();
  }

  /// Called every repeat interval configured via ForegroundTaskOptions.eventAction
  @override
  void onRepeatEvent(DateTime timestamp) async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position == null) return;
      // 使用插件的存储通道在UI侧写入 rescueId/userId，再在此读取
      final userId =
          await FlutterForegroundTask.getData(key: 'userId') as String?;
      final rescueId =
          await FlutterForegroundTask.getData(key: 'rescueId') as String?;
      if (userId == null || rescueId == null) return;

      final point = LocationPoint(
        position: LatLng(position.latitude, position.longitude),
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        timestamp: DateTime.now(),
        userId: userId,
        rescueId: rescueId,
      );
      await _optimizedStorage.saveLocationPointSmart(point);
    } catch (_) {}
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}
}
