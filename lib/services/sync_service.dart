import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'location_service.dart';
import '../models/location_point.dart';
import '../models/track.dart';

/// 同步服务类，负责离线数据同步
class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final StorageService _storageService = StorageService();
  final LocationService _locationService = LocationService();

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isOnline = false;
  String? _currentRescueId;
  String? _currentUserId;

  // 同步配置
  static const Duration _syncInterval = Duration(minutes: 2); // 每2分钟同步一次
  static const int _batchSize = 50; // 每批同步50个位置点

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  /// 初始化同步服务
  Future<void> initialize(String rescueId, String userId) async {
    _currentRescueId = rescueId;
    _currentUserId = userId;

    // 检查网络连接
    await _checkNetworkConnection();

    // 启动定期同步
    _startPeriodicSync();

    // 监听位置更新
    _locationService.locationStream.listen(_onLocationUpdate);
  }

  /// 检查网络连接
  Future<void> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('tools.blendiv.com');
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      _isOnline = false;
    }
    notifyListeners();
  }

  /// 启动定期同步
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      _performSync();
    });
  }

  /// 停止同步服务
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _currentRescueId = null;
    _currentUserId = null;
  }

  /// 位置更新回调
  void _onLocationUpdate(LocationPoint point) {
    // 保存到本地
    _storageService.saveLocationPoint(point);

    // 如果在线，尝试立即同步最新的位置点
    if (_isOnline && !_isSyncing) {
      _syncRecentLocationPoints();
    }
  }

  /// 执行同步
  Future<void> _performSync() async {
    if (_isSyncing || _currentRescueId == null || _currentUserId == null) {
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      // 检查网络连接
      await _checkNetworkConnection();

      if (!_isOnline) {
        print('网络不可用，跳过同步');
        return;
      }

      // 同步位置点
      await _syncLocationPoints();

      // 同步轨迹信息
      await _syncTrack();

      print('同步完成');
    } catch (e) {
      print('同步失败: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// 同步位置点
  Future<void> _syncLocationPoints() async {
    if (_currentRescueId == null || _currentUserId == null) return;

    try {
      // 获取未同步的位置点
      final unsyncedPoints = await _storageService.getUnsyncedLocationPoints(
        _currentRescueId!,
        _currentUserId!,
      );

      if (unsyncedPoints.isEmpty) {
        return;
      }

      print('开始同步 ${unsyncedPoints.length} 个位置点');

      // 分批上传
      for (int i = 0; i < unsyncedPoints.length; i += _batchSize) {
        final end = (i + _batchSize < unsyncedPoints.length)
            ? i + _batchSize
            : unsyncedPoints.length;
        final batch = unsyncedPoints.sublist(i, end);

        final success = await ApiService.uploadLocationPoints(
          _currentRescueId!,
          _currentUserId!,
          batch,
        );

        if (success && batch.isNotEmpty) {
          // 标记为已同步
          await _storageService.markLocationPointsSynced(
            _currentRescueId!,
            _currentUserId!,
            batch.first.timestamp,
            batch.last.timestamp,
          );
          print('成功同步批次 ${i ~/ _batchSize + 1}');
        } else {
          print('同步批次 ${i ~/ _batchSize + 1} 失败');
          break; // 如果一个批次失败，停止后续同步
        }
      }
    } catch (e) {
      print('同步位置点失败: $e');
    }
  }

  /// 同步最近的位置点（实时同步）
  Future<void> _syncRecentLocationPoints() async {
    if (_currentRescueId == null || _currentUserId == null) return;

    try {
      // 获取最近5分钟的未同步位置点
      final recentPoints = await _storageService.getUnsyncedLocationPoints(
        _currentRescueId!,
        _currentUserId!,
      );

      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(minutes: 5));

      final recentUnsyncedPoints = recentPoints.where((point) {
        return point.timestamp.isAfter(cutoff);
      }).toList();

      if (recentUnsyncedPoints.isNotEmpty) {
        final success = await ApiService.uploadLocationPoints(
          _currentRescueId!,
          _currentUserId!,
          recentUnsyncedPoints,
        );

        if (success) {
          await _storageService.markLocationPointsSynced(
            _currentRescueId!,
            _currentUserId!,
            recentUnsyncedPoints.first.timestamp,
            recentUnsyncedPoints.last.timestamp,
          );
        }
      }
    } catch (e) {
      print('同步最近位置点失败: $e');
    }
  }

  /// 同步轨迹信息
  Future<void> _syncTrack() async {
    if (_currentRescueId == null || _currentUserId == null) return;

    try {
      // 获取当前用户的轨迹点
      final trackPoints = _locationService.trackPoints;

      if (trackPoints.isEmpty) {
        return;
      }

      // 创建轨迹对象
      final track = Track(
        id: 'track_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: _currentUserId!,
        userName: '救援员${_currentUserId!.substring(_currentUserId!.length - 3)}',
        rescueId: _currentRescueId!,
        points: trackPoints,
        color: _generateUserColor(_currentUserId!),
        startTime: trackPoints.first.timestamp,
        endTime: trackPoints.last.timestamp,
        isActive: _locationService.isTracking,
        totalDistance: _locationService.getTotalDistance(),
        totalDuration:
            trackPoints.last.timestamp.difference(trackPoints.first.timestamp),
      );

      // 保存到本地
      await _storageService.saveTrack(track);

      // 上传到服务器
      final success = await ApiService.uploadTrack(track);

      if (success) {
        print('轨迹同步成功');
      } else {
        print('轨迹同步失败');
      }
    } catch (e) {
      print('同步轨迹失败: $e');
    }
  }

  /// 手动触发同步
  Future<void> manualSync() async {
    if (_isSyncing) {
      return;
    }

    await _performSync();
  }

  /// 强制同步所有数据
  Future<void> forceSyncAll() async {
    if (_currentRescueId == null || _currentUserId == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await _checkNetworkConnection();

      if (!_isOnline) {
        throw Exception('网络不可用');
      }

      // 获取所有未同步的位置点
      final allUnsyncedPoints = await _storageService.getUnsyncedLocationPoints(
        _currentRescueId!,
        _currentUserId!,
      );

      if (allUnsyncedPoints.isNotEmpty) {
        final success = await ApiService.uploadLocationPoints(
          _currentRescueId!,
          _currentUserId!,
          allUnsyncedPoints,
        );

        if (success) {
          await _storageService.markLocationPointsSynced(
            _currentRescueId!,
            _currentUserId!,
            allUnsyncedPoints.first.timestamp,
            allUnsyncedPoints.last.timestamp,
          );
        }
      }

      // 同步轨迹
      await _syncTrack();

      print('强制同步完成');
    } catch (e) {
      print('强制同步失败: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// 生成用户颜色
  Color _generateUserColor(String userId) {
    final colors = [
      const Color(0xFFE57373), // 红色
      const Color(0xFF64B5F6), // 蓝色
      const Color(0xFF81C784), // 绿色
      const Color(0xFFFFB74D), // 橙色
      const Color(0xFFBA68C8), // 紫色
      const Color(0xFF4DB6AC), // 青色
      const Color(0xFFF06292), // 粉色
      const Color(0xFF9575CD), // 深紫色
      const Color(0xFF4FC3F7), // 浅蓝色
      const Color(0xFFAED581), // 浅绿色
    ];

    final hash = userId.hashCode;
    final index = hash.abs() % colors.length;
    return colors[index];
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
