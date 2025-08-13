import 'package:flutter/foundation.dart';

import '../models/track_point_model.dart';
import '../models/user_track_model.dart';
import 'api_service.dart';
import 'database_service.dart';

/// 轨迹共享服务
///
/// 负责管理救援中所有参与者的轨迹数据共享
/// 包括上传本地轨迹、下载其他用户轨迹、实时同步等功能
class TrackSharingService {
  static final TrackSharingService _instance = TrackSharingService._internal();
  factory TrackSharingService() => _instance;
  TrackSharingService._internal();

  static TrackSharingService get instance => _instance;

  final ApiService _apiService = ApiService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;

  // 缓存的用户轨迹数据
  final Map<String, List<UserTrackModel>> _cachedUserTracks = {};

  // 最后同步时间
  DateTime? _lastSyncTime;

  /// 上传当前用户的轨迹数据到云端
  Future<bool> uploadUserTrack(String rescueId, String userId) async {
    try {
      debugPrint('开始上传用户轨迹: rescueId=$rescueId, userId=$userId');

      // 从本地数据库获取轨迹点
      final allTrackPoints = await _databaseService.getAllTrackPoints(rescueId);
      final trackPoints = allTrackPoints[userId] ?? [];

      if (trackPoints.isEmpty) {
        debugPrint('没有轨迹点需要上传');
        return true;
      }

      // 将轨迹点按时间排序
      trackPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // 创建用户轨迹模型
      final userTrack = UserTrackModel(
        userId: userId,
        points: trackPoints,
      );

      // 上传到云端
      final result = await _apiService.uploadUserTrack(rescueId, userTrack);
      if (result.isSuccess) {
        debugPrint('轨迹上传成功: ${trackPoints.length} 个点');
        return true;
      } else {
        debugPrint('轨迹上传失败: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('上传轨迹异常: $e');
      return false;
    }
  }

  /// 下载救援中所有用户的轨迹数据
  Future<Map<String, List<TrackPointModel>>> downloadAllUserTracks(
      String rescueId) async {
    try {
      debugPrint('开始下载所有用户轨迹: rescueId=$rescueId');

      // 从云端获取所有用户轨迹
      final result = await _apiService.getAllUserTracks(rescueId);
      if (!result.isSuccess) {
        debugPrint('下载轨迹失败: ${result.error}');
        return {};
      }

      final userTracks = result.data ?? [];
      final allUserTrackPoints = <String, List<TrackPointModel>>{};

      // 处理每个用户的轨迹数据
      for (final userTrack in userTracks) {
        final userId = userTrack.userId;
        final trackPoints = userTrack.points;

        if (trackPoints.isNotEmpty) {
          allUserTrackPoints[userId] = trackPoints;
          debugPrint('用户 $userId 的轨迹: ${trackPoints.length} 个点');
        }
      }

      // 更新缓存
      _cachedUserTracks.clear();
      for (final userTrack in userTracks) {
        _cachedUserTracks[userTrack.userId] = [userTrack];
      }
      _lastSyncTime = DateTime.now();

      debugPrint('下载完成，共 ${allUserTrackPoints.length} 个用户的轨迹');
      return allUserTrackPoints;
    } catch (e) {
      debugPrint('下载轨迹异常: $e');
      return {};
    }
  }

  /// 获取指定用户的轨迹数据
  Future<List<TrackPointModel>> getUserTrackPoints(
      String rescueId, String userId) async {
    try {
      // 先检查缓存
      if (_cachedUserTracks.containsKey(userId)) {
        final userTracks = _cachedUserTracks[userId]!;
        if (userTracks.isNotEmpty) {
          return userTracks.first.points;
        }
      }

      // 从云端获取
      final result = await _apiService.getUserTracks(rescueId, userId);
      if (result.isSuccess) {
        final userTracks = result.data ?? [];
        if (userTracks.isNotEmpty) {
          // 更新缓存
          _cachedUserTracks[userId] = userTracks;

          // 合并所有轨迹点
          final allPoints = <TrackPointModel>[];
          for (final userTrack in userTracks) {
            allPoints.addAll(userTrack.points);
          }

          // 按时间排序
          allPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return allPoints;
        }
      }

      return [];
    } catch (e) {
      debugPrint('获取用户轨迹异常: $e');
      return [];
    }
  }

  /// 实时同步轨迹数据
  Future<bool> syncTracks(String rescueId, String currentUserId) async {
    try {
      debugPrint('开始同步轨迹数据');

      // 1. 上传当前用户的轨迹
      final uploadSuccess = await uploadUserTrack(rescueId, currentUserId);
      if (!uploadSuccess) {
        debugPrint('上传轨迹失败');
      }

      // 2. 下载所有用户的轨迹
      final allTracks = await downloadAllUserTracks(rescueId);

      return allTracks.isNotEmpty;
    } catch (e) {
      debugPrint('同步轨迹异常: $e');
      return false;
    }
  }

  /// 获取缓存的用户轨迹数据
  Map<String, List<TrackPointModel>> getCachedUserTracks() {
    final result = <String, List<TrackPointModel>>{};

    for (final entry in _cachedUserTracks.entries) {
      final userId = entry.key;
      final userTracks = entry.value;

      if (userTracks.isNotEmpty) {
        // 合并所有轨迹点
        final allPoints = <TrackPointModel>[];
        for (final userTrack in userTracks) {
          allPoints.addAll(userTrack.points);
        }

        // 按时间排序
        allPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        result[userId] = allPoints;
      }
    }

    return result;
  }

  /// 获取用户信息摘要
  Map<String, Map<String, dynamic>> getUserTrackSummary() {
    final result = <String, Map<String, dynamic>>{};

    for (final entry in _cachedUserTracks.entries) {
      final userId = entry.key;
      final userTracks = entry.value;

      if (userTracks.isNotEmpty) {
        final userTrack = userTracks.first;
        final timeRange = userTrack.timeRange;
        result[userId] = {
          'totalPoints': userTrack.pointCount,
          'startTime': timeRange?.start,
          'endTime': timeRange?.end,
          'updatedAt': DateTime.now(), // 使用当前时间作为更新时间
        };
      }
    }

    return result;
  }

  /// 清除缓存
  void clearCache() {
    _cachedUserTracks.clear();
    _lastSyncTime = null;
    debugPrint('轨迹缓存已清除');
  }

  /// 检查是否需要同步
  bool shouldSync() {
    if (_lastSyncTime == null) return true;

    final now = DateTime.now();
    final timeDiff = now.difference(_lastSyncTime!);

    // 每5分钟同步一次
    return timeDiff.inMinutes >= 5;
  }

  /// 删除用户轨迹数据
  Future<bool> deleteUserTracks(String rescueId, String userId) async {
    try {
      // 从云端删除
      final result = await _apiService.deleteUserTracks(rescueId, userId);

      // 从缓存中删除
      _cachedUserTracks.remove(userId);

      return result.isSuccess;
    } catch (e) {
      debugPrint('删除用户轨迹异常: $e');
      return false;
    }
  }

  /// 获取最后同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 获取缓存的用户数量
  int get cachedUserCount => _cachedUserTracks.length;
}
