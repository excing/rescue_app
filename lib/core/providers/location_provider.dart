import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/track_point_model.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../services/location_service.dart';

/// 简化版位置状态管理Provider
///
/// 负责管理GPS定位、轨迹记录等功能
/// 使用LocationService处理后台任务
class LocationProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;
  final PermissionService _permissionService = PermissionService.instance;
  final LocationService _locationService = LocationService.instance;

  // 状态变量
  Position? _currentPosition;
  bool _isTracking = false;
  bool _isLocationServiceEnabled = false;
  bool _hasLocationPermission = false;
  String? _error;
  List<TrackPointModel> _currentTrackPoints = [];

  // 流订阅（仅用于UI更新）
  StreamSubscription<Position>? _positionStreamSubscription;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;
  bool get hasLocationPermission => _hasLocationPermission;
  String? get error => _error;
  List<TrackPointModel> get currentTrackPoints => _currentTrackPoints;

  /// 当前位置的经纬度字符串
  String get currentLocationString {
    if (_currentPosition == null) return '位置未知';
    return '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';
  }

  /// 当前海拔字符串
  String get currentAltitudeString {
    if (_currentPosition == null) return '海拔未知';
    return '${_currentPosition!.altitude.toStringAsFixed(1)}m';
  }

  /// 当前精度字符串
  String get currentAccuracyString {
    if (_currentPosition == null) return '精度未知';
    return '±${_currentPosition!.accuracy.toStringAsFixed(1)}m';
  }

  /// 初始化位置服务
  Future<void> initialize() async {
    await _checkLocationService();
    await _checkLocationPermission();

    if (_isLocationServiceEnabled && _hasLocationPermission) {
      await _getCurrentPosition();
    }
  }

  /// 检查位置服务是否启用
  Future<void> _checkLocationService() async {
    try {
      _isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      _setError('检查位置服务失败: $e');
      _isLocationServiceEnabled = false;
    }
    notifyListeners();
  }

  /// 检查位置权限
  Future<void> _checkLocationPermission() async {
    try {
      _hasLocationPermission = await _permissionService.hasLocationPermission();
    } catch (e) {
      _setError('检查位置权限失败: $e');
      _hasLocationPermission = false;
    }
    notifyListeners();
  }

  /// 请求位置权限
  Future<bool> requestLocationPermission() async {
    try {
      _clearError();
      final result = await _permissionService.requestLocationPermissions();
      _hasLocationPermission = result.hasBasicPermissions;
      notifyListeners();
      return result.hasBasicPermissions;
    } catch (e) {
      _setError('请求位置权限失败: $e');
      return false;
    }
  }

  /// 获取当前位置
  Future<bool> getCurrentPosition() async {
    return await _getCurrentPosition();
  }

  /// 内部方法：获取当前位置
  Future<bool> _getCurrentPosition() async {
    try {
      _clearError();

      if (!_isLocationServiceEnabled) {
        _setError('位置服务未启用');
        return false;
      }

      if (!_hasLocationPermission) {
        _setError('没有位置权限');
        return false;
      }

      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _currentPosition = position;
        notifyListeners();
        return true;
      } else {
        _setError('获取位置失败');
        return false;
      }
    } catch (e) {
      _setError('获取位置失败: $e');
      return false;
    }
  }

  /// 开始轨迹记录
  Future<bool> startTracking(String rescueId, String userId) async {
    try {
      _clearError();

      if (_isTracking) {
        _setError('轨迹记录已在进行中');
        return false;
      }

      if (!_hasLocationPermission) {
        _setError('没有位置权限');
        return false;
      }

      // 使用LocationService开始轨迹记录
      final success = await _locationService.startTracking(rescueId, userId);
      if (success) {
        _isTracking = true;

        // 开始位置监听（仅用于UI更新）
        _startPositionStream();

        notifyListeners();
        return true;
      } else {
        _setError('启动轨迹记录失败');
        return false;
      }
    } catch (e) {
      _setError('开始轨迹记录失败: $e');
      return false;
    }
  }

  /// 停止轨迹记录
  Future<void> stopTracking() async {
    try {
      if (!_isTracking) return;

      // 停止位置监听
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;

      // 使用LocationService停止轨迹记录
      await _locationService.stopTracking();

      _isTracking = false;
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('停止轨迹记录失败: $e');
    }
  }

  /// 标记当前位置
  Future<bool> markCurrentLocation() async {
    try {
      // 使用LocationService标记当前位置
      final success = await _locationService.markCurrentLocation();
      if (success) {
        notifyListeners();
        return true;
      } else {
        _setError('标记位置失败');
        return false;
      }
    } catch (e) {
      _setError('标记位置失败: $e');
      return false;
    }
  }

  /// 加载轨迹点
  Future<void> loadTrackPoints(String rescueId, String userId) async {
    try {
      _currentTrackPoints =
          await _databaseService.getUserTrackPoints(rescueId, userId);
      notifyListeners();
    } catch (e) {
      _setError('加载轨迹点失败: $e');
    }
  }

  /// 清空当前轨迹点
  void clearTrackPoints() {
    _currentTrackPoints.clear();
    notifyListeners();
  }

  /// 开始位置流监听（仅用于UI更新）
  void _startPositionStream() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        timeLimit: Duration(seconds: 10),
      ),
    ).listen(
      (Position position) {
        _currentPosition = position;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('位置监听失败: $error');
      },
    );
  }

  // ==================== 私有方法 ====================

  void _setError(String error) {
    debugPrint(error);
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}
