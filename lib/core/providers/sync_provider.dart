import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/user_track_model.dart';
import '../models/track_point_model.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

/// 简化版数据同步状态管理Provider
/// 
/// 负责管理本地数据与服务器的同步
/// 主要使用SyncService处理同步逻辑
class SyncProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;
  final SyncService _syncService = SyncService.instance;

  // 状态变量
  bool _isAutoSyncEnabled = true;
  Map<String, List<UserTrackModel>> _allUserTracks = {};
  
  // 自动同步定时器
  Timer? _autoSyncTimer;
  
  // 同步间隔（分钟）
  static const int _autoSyncIntervalMinutes = 1;

  // Getters
  bool get isSyncing => _syncService.isSyncing;
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  DateTime? get lastSyncTime => _syncService.lastSyncTime;
  String? get syncError => _syncService.lastSyncError;
  Map<String, List<UserTrackModel>> get allUserTracks => _allUserTracks;
  
  /// 获取同步状态描述
  String get syncStatusDescription => _syncService.syncStatusDescription;

  /// 是否可以手动同步（避免频繁同步）
  bool get canManualSync => _syncService.canManualSync;

  /// 启动自动同步
  void startAutoSync() {
    if (_isAutoSyncEnabled && _autoSyncTimer == null) {
      _syncService.startAutoSync();
      _autoSyncTimer = Timer.periodic(
        Duration(minutes: _autoSyncIntervalMinutes),
        (_) => notifyListeners(), // 定期通知UI更新状态
      );
    }
  }

  /// 停止自动同步
  void stopAutoSync() {
    _syncService.stopAutoSync();
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// 设置自动同步开关
  void setAutoSyncEnabled(bool enabled) {
    _isAutoSyncEnabled = enabled;
    if (enabled) {
      startAutoSync();
    } else {
      stopAutoSync();
    }
    notifyListeners();
  }

  /// 手动同步
  Future<bool> manualSync(String rescueId, String userId) async {
    final result = await _syncService.manualSync(rescueId, userId);
    if (result.isSuccess) {
      // 同步成功后重新加载轨迹数据
      await _loadAllUserTracks(rescueId);
      notifyListeners();
      return true;
    } else {
      notifyListeners();
      return false;
    }
  }

  /// 加载所有用户轨迹数据
  Future<void> _loadAllUserTracks(String rescueId) async {
    try {
      final allTracks = await _databaseService.getAllTrackPoints(rescueId);
      
      // 转换为UserTrackModel格式
      final userTrackMap = <String, List<UserTrackModel>>{};
      for (final entry in allTracks.entries) {
        final userId = entry.key;
        final points = entry.value;
        
        if (points.isNotEmpty) {
          final userTrack = UserTrackModel(
            userId: userId,
            points: points,
            index: 0,
          );
          userTrackMap[userId] = [userTrack];
        }
      }
      
      _allUserTracks = userTrackMap;
    } catch (e) {
      debugPrint('加载用户轨迹数据失败: $e');
      _allUserTracks = {};
    }
  }

  /// 获取指定用户的所有轨迹点
  List<TrackPointModel> getUserAllTrackPoints(String userId) {
    final userTracks = _allUserTracks[userId] ?? [];
    final allPoints = <TrackPointModel>[];
    
    for (final track in userTracks) {
      allPoints.addAll(track.points);
    }
    
    // 按时间戳排序
    allPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allPoints;
  }

  /// 获取所有用户的轨迹点（按用户分组）
  Map<String, List<TrackPointModel>> getAllUsersTrackPoints() {
    final result = <String, List<TrackPointModel>>{};
    
    for (final entry in _allUserTracks.entries) {
      result[entry.key] = getUserAllTrackPoints(entry.key);
    }
    
    return result;
  }

  /// 清空轨迹数据
  void clearTracks() {
    _allUserTracks.clear();
    notifyListeners();
  }

  /// 获取同步统计信息
  SyncStats getSyncStats() {
    int totalUsers = _allUserTracks.length;
    int totalPoints = 0;
    int totalMarkedPoints = 0;

    for (final tracks in _allUserTracks.values) {
      for (final track in tracks) {
        totalPoints += track.pointCount;
        totalMarkedPoints += track.markedPoints.length;
      }
    }

    return SyncStats(
      totalUsers: totalUsers,
      totalPoints: totalPoints,
      totalMarkedPoints: totalMarkedPoints,
      lastSyncTime: lastSyncTime,
    );
  }

  /// 初始化同步Provider
  Future<void> initialize(String rescueId) async {
    await _loadAllUserTracks(rescueId);
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}

/// 同步统计信息
class SyncStats {
  final int totalUsers;
  final int totalPoints;
  final int totalMarkedPoints;
  final DateTime? lastSyncTime;

  const SyncStats({
    required this.totalUsers,
    required this.totalPoints,
    required this.totalMarkedPoints,
    this.lastSyncTime,
  });

  @override
  String toString() {
    return 'SyncStats(users: $totalUsers, points: $totalPoints, marked: $totalMarkedPoints, lastSync: $lastSyncTime)';
  }
}
