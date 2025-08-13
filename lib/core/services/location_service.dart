import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/track_point_model.dart';
import 'database_service.dart';
import 'background_location_service.dart';

/// 简化版位置服务
///
/// 负责GPS定位和轨迹记录
/// 暂时不包含前台服务功能，专注于核心定位功能
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// 获取单例实例
  static LocationService get instance => _instance;

  // 状态变量
  bool _isInitialized = false;
  bool _isTracking = false;
  Position? _lastPosition;
  String? _currentRescueId;
  String? _currentUserId;

  // 位置监听流
  StreamSubscription<Position>? _positionSubscription;

  // 定位设置
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 3, // 3米距离过滤，提高精度
    timeLimit: Duration(seconds: 15),
  );

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;

  /// 初始化位置服务
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // 检查位置服务是否启用
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('位置服务未启用');
        return false;
      }

      // 检查位置权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('位置权限被拒绝');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('位置权限被永久拒绝');
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('初始化位置服务失败: $e');
      return false;
    }
  }

  /// 开始轨迹记录
  Future<bool> startTracking(String rescueId, String userId) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }

      if (_isTracking) {
        debugPrint('轨迹记录已在进行中');
        return false;
      }

      _currentRescueId = rescueId;
      _currentUserId = userId;

      // 使用后台服务开始位置追踪
      final success =
          await BackgroundLocationService.startTracking(rescueId, userId);
      if (!success) {
        debugPrint('启动后台位置服务失败');
        return false;
      }

      // 同时启动前台位置监听（用于UI更新）
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        (Position position) {
          _onPositionUpdate(position);
        },
        onError: (error) {
          debugPrint('位置监听错误: $error');
        },
      );

      _isTracking = true;
      debugPrint('轨迹记录已开始（包含后台服务）');
      return true;
    } catch (e) {
      debugPrint('开始轨迹记录失败: $e');
      return false;
    }
  }

  /// 停止轨迹记录
  Future<void> stopTracking() async {
    try {
      if (!_isTracking) return;

      // 停止后台服务
      await BackgroundLocationService.stopTracking();

      // 停止前台位置监听
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      _isTracking = false;
      _currentRescueId = null;
      _currentUserId = null;

      debugPrint('轨迹记录已停止（包含后台服务）');
    } catch (e) {
      debugPrint('停止轨迹记录失败: $e');
    }
  }

  /// 获取当前位置
  Future<Position?> getCurrentPosition() async {
    try {
      if (!_isInitialized) return null;

      // 无法获取当前位置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      _lastPosition = position;
      return position;
    } catch (e) {
      debugPrint('获取当前位置失败: $e');
      return null;
    }
  }

  /// 手动标记当前位置
  Future<bool> markCurrentLocation() async {
    try {
      if (!_isTracking || _currentRescueId == null || _currentUserId == null) {
        return false;
      }

      final position = await getCurrentPosition();
      if (position == null) return false;

      final markedPoint = TrackPointModel.fromDouble(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        dateTime: DateTime.now(),
        marked: true,
      );

      await _saveTrackPoint(markedPoint);
      return true;
    } catch (e) {
      debugPrint('标记当前位置失败: $e');
      return false;
    }
  }

  /// 位置更新回调
  void _onPositionUpdate(Position position) async {
    try {
      _lastPosition = position;

      // 创建轨迹点
      final trackPoint = TrackPointModel.fromDouble(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        dateTime: DateTime.now(),
        marked: false,
      );

      // 保存轨迹点
      await _saveTrackPoint(trackPoint);
    } catch (e) {
      debugPrint('处理位置更新失败: $e');
    }
  }

  /// 保存轨迹点到数据库
  Future<void> _saveTrackPoint(TrackPointModel point) async {
    try {
      if (_currentRescueId == null || _currentUserId == null) return;

      await DatabaseService.instance.insertTrackPoint(
        _currentRescueId!,
        _currentUserId!,
        point,
      );
    } catch (e) {
      debugPrint('保存轨迹点失败: $e');
    }
  }

  /// 获取位置权限状态
  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// 请求位置权限
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// 检查位置服务是否启用
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// 打开位置设置
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// 打开应用设置
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// 计算两点之间的距离（米）
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// 计算两点之间的方位角（度）
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// 清理资源
  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    _currentRescueId = null;
    _currentUserId = null;
  }
}
