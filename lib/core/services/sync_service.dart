import 'dart:async';

import '../models/user_track_model.dart';
import '../models/track_point_model.dart';
import 'database_service.dart';
import 'api_service.dart';

/// 数据同步服务
///
/// 负责本地数据与服务器的同步，包括救援数据和轨迹数据
/// 实现本地优先策略和准实时同步机制
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  /// 获取单例实例
  static SyncService get instance => _instance;

  final DatabaseService _databaseService = DatabaseService.instance;
  final ApiService _apiService = ApiService.instance;

  // 同步状态
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastSyncError;

  // 自动同步定时器
  Timer? _autoSyncTimer;
  static const Duration _autoSyncInterval = Duration(minutes: 1);
  static const Duration _manualSyncCooldown = Duration(seconds: 5);

  // Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncError => _lastSyncError;

  /// 同步状态描述
  String get syncStatusDescription {
    if (_isSyncing) return '同步中...';
    if (_lastSyncError != null) return '同步失败: $_lastSyncError';
    if (_lastSyncTime != null) {
      final duration = DateTime.now().difference(_lastSyncTime!);
      if (duration.inMinutes < 1) {
        return '刚刚同步';
      } else if (duration.inMinutes < 60) {
        return '${duration.inMinutes}分钟前同步';
      } else {
        return '${duration.inHours}小时前同步';
      }
    }
    return '未同步';
  }

  /// 是否可以手动同步
  bool get canManualSync {
    if (_lastSyncTime == null) return true;
    final duration = DateTime.now().difference(_lastSyncTime!);
    return duration >= _manualSyncCooldown;
  }

  /// 启动自动同步
  void startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      // 自动同步需要当前救援信息，这里暂时跳过
      // 在实际使用时会从Provider获取当前救援信息
    });
  }

  /// 停止自动同步
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// 手动同步
  Future<SyncResult> manualSync(String rescueId, String userId) async {
    if (!canManualSync) {
      return SyncResult.error('请等待${_manualSyncCooldown.inSeconds}秒后再试');
    }

    return await _performSync(rescueId, userId, isManual: true);
  }

  /// 执行同步
  Future<SyncResult> _performSync(String rescueId, String userId,
      {bool isManual = false}) async {
    if (_isSyncing) {
      return SyncResult.error('同步正在进行中');
    }

    try {
      _isSyncing = true;
      _lastSyncError = null;

      // 1. 同步救援信息
      // final rescueResult = await _syncRescueData(rescueId);
      // if (!rescueResult.isSuccess) {
      //   throw Exception('同步救援信息失败: ${rescueResult.error}');
      // }

      // 2. 上传本地轨迹数据
      final uploadResult = await _uploadLocalTracks(rescueId, userId);
      if (!uploadResult.isSuccess) {
        throw Exception('上传轨迹数据失败: ${uploadResult.error}');
      }

      // 3. 下载服务器轨迹数据
      final downloadResult = await _downloadServerTracks(rescueId);
      if (!downloadResult.isSuccess) {
        throw Exception('下载轨迹数据失败: ${downloadResult.error}');
      }

      // 4. 更新同步时间
      _lastSyncTime = DateTime.now();
      _isSyncing = false;

      return SyncResult.success(
        data: {
          'uploadedPoints': uploadResult.data ?? 0,
          'downloadedTracks': downloadResult.data ?? 0,
        },
      );
    } catch (e) {
      _lastSyncError = e.toString();
      _isSyncing = false;
      return SyncResult.error(e.toString());
    }
  }

  /// 同步救援数据
  Future<SyncResult> _syncRescueData(String rescueId) async {
    try {
      // 检查本地是否有救援数据
      final localRescue = await _databaseService.getRescue(rescueId);

      if (localRescue == null) {
        // 从服务器获取救援数据
        final apiResult = await _apiService.getRescue(rescueId);
        if (apiResult.isSuccess) {
          await _databaseService.insertRescue(apiResult.data!);
          await _databaseService.markRescueSynced(rescueId);
          return SyncResult.success();
        } else {
          return SyncResult.error('获取救援数据失败: ${apiResult.error}');
        }
      }

      return SyncResult.success();
    } catch (e) {
      return SyncResult.error('同步救援数据失败: $e');
    }
  }

  /// 上传本地轨迹数据
  Future<SyncResult<int>> _uploadLocalTracks(
      String rescueId, String userId) async {
    try {
      // 获取未同步的轨迹点
      final unsyncedCount =
          await _databaseService.getUnsyncedTrackPointsCount(rescueId, userId);
      if (unsyncedCount == 0) {
        return SyncResult.success(data: 0);
      }

      // 获取所有轨迹点
      final trackPoints =
          await _databaseService.getUserTrackPoints(rescueId, userId);
      if (trackPoints.isEmpty) {
        return SyncResult.success(data: 0);
      }

      // 按文档大小分组
      final userTrackDocuments = _groupPointsIntoDocuments(userId, trackPoints);

      // 上传每个文档
      for (final userTrack in userTrackDocuments) {
        final result = await _apiService.uploadUserTrack(rescueId, userTrack);
        if (!result.isSuccess) {
          return SyncResult.error('上传轨迹文档失败: ${result.error}');
        }
      }

      // 标记为已同步
      await _databaseService.markTrackPointsSynced(rescueId, userId);

      return SyncResult.success(data: trackPoints.length);
    } catch (e) {
      return SyncResult.error('上传本地轨迹失败: $e');
    }
  }

  /// 下载服务器轨迹数据
  Future<SyncResult<int>> _downloadServerTracks(String rescueId) async {
    try {
      final result = await _apiService.getAllUserTracks(rescueId);
      if (!result.isSuccess) {
        return SyncResult.error('获取服务器轨迹失败: ${result.error}');
      }

      final serverTracks = result.data!;
      int totalTracks = 0;

      // 按用户分组处理
      final groupedTracks = <String, List<UserTrackModel>>{};
      for (final track in serverTracks) {
        groupedTracks.putIfAbsent(track.userId, () => []).add(track);
      }

      // 保存到本地数据库
      for (final entry in groupedTracks.entries) {
        final userId = entry.key;
        final userTracks = entry.value;

        // 合并所有轨迹点
        final allPoints = <TrackPointModel>[];
        for (final track in userTracks) {
          allPoints.addAll(track.points);
        }

        if (allPoints.isNotEmpty) {
          // 删除旧数据
          await _databaseService.deleteUserTrackPoints(rescueId, userId);

          // 插入新数据
          await _databaseService.insertTrackPoints(rescueId, userId, allPoints);

          // 标记为已同步
          await _databaseService.markTrackPointsSynced(rescueId, userId);

          totalTracks += allPoints.length;
        }
      }

      return SyncResult.success(data: totalTracks);
    } catch (e) {
      return SyncResult.error('下载服务器轨迹失败: $e');
    }
  }

  /// 将轨迹点分组为文档（考虑1MB限制）
  List<UserTrackModel> _groupPointsIntoDocuments(
      String userId, List<TrackPointModel> points) {
    final documents = <UserTrackModel>[];
    const maxSizeBytes = 1024 * 1024 * 0.8; // 80% of 1MB for safety

    List<TrackPointModel> currentPoints = [];
    int currentSize = 0;
    int documentIndex = 0;

    for (final point in points) {
      final pointSize = point.toCompressedString().length;

      if (currentSize + pointSize > maxSizeBytes && currentPoints.isNotEmpty) {
        // 创建新文档
        documents.add(UserTrackModel(
          userId: userId,
          points: List.from(currentPoints),
          index: documentIndex,
        ));

        currentPoints.clear();
        currentSize = 0;
        documentIndex++;
      }

      currentPoints.add(point);
      currentSize += pointSize;
    }

    // 添加最后一个文档
    if (currentPoints.isNotEmpty) {
      documents.add(UserTrackModel(
        userId: userId,
        points: currentPoints,
        index: documentIndex,
      ));
    }

    return documents;
  }

  /// 清理同步状态
  void clearSyncState() {
    _lastSyncTime = null;
    _lastSyncError = null;
  }

  void dispose() {
    stopAutoSync();
  }
}

/// 同步结果
class SyncResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  const SyncResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory SyncResult.success({T? data}) {
    return SyncResult._(isSuccess: true, data: data);
  }

  factory SyncResult.error(String error) {
    return SyncResult._(isSuccess: false, error: error);
  }

  @override
  String toString() {
    return 'SyncResult(isSuccess: $isSuccess, data: $data, error: $error)';
  }
}
