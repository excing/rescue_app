import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_point.dart';

/// 位置服务类，负责GPS定位和轨迹记录
class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _hasPermission = false;
  String? _currentRescueId;
  String? _currentUserId;

  final List<LocationPoint> _trackPoints = [];
  final StreamController<LocationPoint> _locationController =
      StreamController<LocationPoint>.broadcast();

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  List<LocationPoint> get trackPoints => List.unmodifiable(_trackPoints);
  Stream<LocationPoint> get locationStream => _locationController.stream;

  /// 初始化位置服务
  Future<bool> initialize() async {
    try {
      print('开始初始化位置服务...');

      // 检查位置服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('位置服务未启用，尝试打开设置');
        // 尝试打开位置设置
        serviceEnabled = await Geolocator.openLocationSettings();
        if (!serviceEnabled) {
          print('用户未开启位置服务');
          return false;
        }
      }

      // 请求位置权限
      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        print('位置权限被拒绝');
        return false;
      }

      _hasPermission = true;
      print('位置权限获取成功');

      // 获取当前位置
      final position = await getCurrentLocation();
      if (position != null) {
        print('当前位置获取成功: ${position.latitude}, ${position.longitude}');
      }

      notifyListeners();
      return true;
    } catch (e) {
      print('初始化位置服务失败: $e');
      return false;
    }
  }

  /// 请求位置权限
  Future<bool> _requestLocationPermission() async {
    try {
      // 检查当前权限状态
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // 权限被永久拒绝，需要用户手动开启
        return false;
      }

      // 在Android上请求后台位置权限
      if (Platform.isAndroid) {
        final backgroundPermission = await Permission.locationAlways.request();
        if (backgroundPermission != PermissionStatus.granted) {
          print('后台位置权限未授予');
          // 即使后台权限未授予，也可以继续使用前台定位
        }
      }

      return true;
    } catch (e) {
      print('请求位置权限失败: $e');
      return false;
    }
  }

  /// 获取当前位置
  Future<Position?> getCurrentLocation() async {
    try {
      if (!_hasPermission) {
        print('没有位置权限，尝试重新初始化...');
        final initialized = await initialize();
        if (!initialized) {
          print('重新初始化失败');
          return null;
        }
      }

      print('开始获取当前位置...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      _currentPosition = position;
      print(
          '位置获取成功: ${position.latitude}, ${position.longitude}, 精度: ${position.accuracy}m');
      notifyListeners();
      return position;
    } catch (e) {
      print('获取当前位置失败: $e');
      // 尝试使用最后已知位置
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print(
              '使用最后已知位置: ${lastPosition.latitude}, ${lastPosition.longitude}');
          _currentPosition = lastPosition;
          notifyListeners();
          return lastPosition;
        }
      } catch (e2) {
        print('获取最后已知位置也失败: $e2');
      }
      return null;
    }
  }

  /// 开始轨迹记录
  Future<bool> startTracking(String rescueId, String userId) async {
    try {
      if (_isTracking) {
        print('轨迹记录已在进行中');
        return true;
      }

      if (!_hasPermission) {
        final initialized = await initialize();
        if (!initialized) {
          return false;
        }
      }

      _currentRescueId = rescueId;
      _currentUserId = userId;
      _isTracking = true;
      _trackPoints.clear();

      // 配置位置设置
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // 最小移动距离1米
        timeLimit: Duration(seconds: 30),
      );

      // 开始位置流
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onLocationUpdate,
        onError: _onLocationError,
      );

      notifyListeners();
      print('开始轨迹记录: $rescueId, $userId');
      return true;
    } catch (e) {
      print('开始轨迹记录失败: $e');
      _isTracking = false;
      notifyListeners();
      return false;
    }
  }

  /// 停止轨迹记录
  Future<void> stopTracking() async {
    try {
      _isTracking = false;
      await _positionStream?.cancel();
      _positionStream = null;
      _currentRescueId = null;
      _currentUserId = null;

      notifyListeners();
      print('停止轨迹记录');
    } catch (e) {
      print('停止轨迹记录失败: $e');
    }
  }

  /// 位置更新回调
  void _onLocationUpdate(Position position) {
    try {
      _currentPosition = position;

      if (_isTracking && _currentRescueId != null && _currentUserId != null) {
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

        _trackPoints.add(locationPoint);
        _locationController.add(locationPoint);

        print(
            '位置更新: ${position.latitude}, ${position.longitude}, 精度: ${position.accuracy}m');
      }

      notifyListeners();
    } catch (e) {
      print('处理位置更新失败: $e');
    }
  }

  /// 位置错误回调
  void _onLocationError(dynamic error) {
    print('位置服务错误: $error');
  }

  /// 清空轨迹点
  void clearTrackPoints() {
    _trackPoints.clear();
    notifyListeners();
  }

  /// 获取指定时间范围内的轨迹点
  List<LocationPoint> getTrackPointsInRange(DateTime start, DateTime end) {
    return _trackPoints.where((point) {
      return point.timestamp.isAfter(start) && point.timestamp.isBefore(end);
    }).toList();
  }

  /// 获取最近的轨迹点
  List<LocationPoint> getRecentTrackPoints(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _trackPoints.where((point) {
      return point.timestamp.isAfter(cutoff);
    }).toList();
  }

  /// 计算总距离
  double getTotalDistance() {
    if (_trackPoints.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 1; i < _trackPoints.length; i++) {
      total += _trackPoints[i - 1].distanceTo(_trackPoints[i]);
    }
    return total;
  }

  /// 计算平均速度
  double getAverageSpeed() {
    if (_trackPoints.length < 2) return 0.0;

    final totalDistance = getTotalDistance();
    final totalTime =
        _trackPoints.last.timestamp.difference(_trackPoints.first.timestamp);

    if (totalTime.inSeconds > 0) {
      return totalDistance / totalTime.inSeconds; // 米/秒
    }
    return 0.0;
  }

  /// 获取当前海拔
  double? getCurrentAltitude() {
    return _currentPosition?.altitude;
  }

  /// 获取当前精度
  double? getCurrentAccuracy() {
    return _currentPosition?.accuracy;
  }

  /// 检查位置精度是否足够
  bool isAccuracyGood() {
    final accuracy = getCurrentAccuracy();
    return accuracy != null && accuracy <= 10.0; // 精度小于等于10米认为是好的
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _locationController.close();
    super.dispose();
  }
}
