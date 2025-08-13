import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/track_point_model.dart';
import '../services/track_sharing_service.dart';

/// 轨迹共享状态管理
/// 
/// 管理救援中所有参与者的轨迹数据共享状态
/// 提供实时同步、数据缓存、UI状态更新等功能
class TrackSharingProvider extends ChangeNotifier {
  final TrackSharingService _trackSharingService = TrackSharingService.instance;

  // 当前救援ID和用户ID
  String? _currentRescueId;
  String? _currentUserId;

  // 所有用户的轨迹数据 Map<userId, List<TrackPointModel>>
  Map<String, List<TrackPointModel>> _allUserTracks = {};

  // 用户信息摘要 Map<userId, summary>
  Map<String, Map<String, dynamic>> _userSummary = {};

  // 状态标志
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  // 自动同步定时器
  Timer? _autoSyncTimer;

  // ==================== Getters ====================

  /// 所有用户的轨迹数据
  Map<String, List<TrackPointModel>> get allUserTracks => Map.unmodifiable(_allUserTracks);

  /// 用户信息摘要
  Map<String, Map<String, dynamic>> get userSummary => Map.unmodifiable(_userSummary);

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 是否正在同步
  bool get isSyncing => _isSyncing;

  /// 错误信息
  String? get error => _error;

  /// 当前救援ID
  String? get currentRescueId => _currentRescueId;

  /// 当前用户ID
  String? get currentUserId => _currentUserId;

  /// 参与者数量
  int get participantCount => _allUserTracks.length;

  /// 最后同步时间
  DateTime? get lastSyncTime => _trackSharingService.lastSyncTime;

  /// 获取指定用户的轨迹点
  List<TrackPointModel> getUserTracks(String userId) {
    return _allUserTracks[userId] ?? [];
  }

  /// 获取除当前用户外的所有轨迹点
  List<TrackPointModel> getOtherUsersTracks() {
    final allPoints = <TrackPointModel>[];
    
    for (final entry in _allUserTracks.entries) {
      if (entry.key != _currentUserId) {
        allPoints.addAll(entry.value);
      }
    }
    
    // 按时间排序
    allPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allPoints;
  }

  /// 获取所有轨迹点（包括当前用户）
  List<TrackPointModel> getAllTracks() {
    final allPoints = <TrackPointModel>[];
    
    for (final trackList in _allUserTracks.values) {
      allPoints.addAll(trackList);
    }
    
    // 按时间排序
    allPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allPoints;
  }

  // ==================== 公共方法 ====================

  /// 初始化轨迹共享
  Future<void> initialize(String rescueId, String userId) async {
    if (_currentRescueId == rescueId && _currentUserId == userId) {
      return; // 已经初始化过了
    }

    debugPrint('初始化轨迹共享: rescueId=$rescueId, userId=$userId');

    _currentRescueId = rescueId;
    _currentUserId = userId;
    _error = null;

    // 停止之前的自动同步
    _stopAutoSync();

    // 加载缓存数据
    _loadCachedData();

    // 开始首次同步
    await syncTracks();

    // 启动自动同步
    _startAutoSync();
  }

  /// 手动同步轨迹数据
  Future<bool> syncTracks() async {
    if (_currentRescueId == null || _currentUserId == null) {
      _error = '未初始化轨迹共享服务';
      notifyListeners();
      return false;
    }

    if (_isSyncing) {
      debugPrint('正在同步中，跳过本次同步');
      return false;
    }

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('开始同步轨迹数据');

      // 执行同步
      final success = await _trackSharingService.syncTracks(_currentRescueId!, _currentUserId!);
      
      if (success) {
        // 更新本地数据
        await _updateLocalData();
        debugPrint('轨迹同步成功');
      } else {
        _error = '轨迹同步失败';
        debugPrint('轨迹同步失败');
      }

      return success;
    } catch (e) {
      _error = '同步异常: $e';
      debugPrint('轨迹同步异常: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// 上传当前用户轨迹
  Future<bool> uploadUserTrack() async {
    if (_currentRescueId == null || _currentUserId == null) {
      return false;
    }

    try {
      return await _trackSharingService.uploadUserTrack(_currentRescueId!, _currentUserId!);
    } catch (e) {
      debugPrint('上传轨迹异常: $e');
      return false;
    }
  }

  /// 下载所有用户轨迹
  Future<bool> downloadAllTracks() async {
    if (_currentRescueId == null) {
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final allTracks = await _trackSharingService.downloadAllUserTracks(_currentRescueId!);
      
      _allUserTracks = allTracks;
      _userSummary = _trackSharingService.getUserTrackSummary();
      
      debugPrint('下载完成，共 ${_allUserTracks.length} 个用户的轨迹');
      return true;
    } catch (e) {
      _error = '下载轨迹失败: $e';
      debugPrint('下载轨迹异常: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取指定用户的轨迹数据
  Future<List<TrackPointModel>> fetchUserTracks(String userId) async {
    if (_currentRescueId == null) {
      return [];
    }

    try {
      final trackPoints = await _trackSharingService.getUserTrackPoints(_currentRescueId!, userId);
      
      // 更新本地缓存
      if (trackPoints.isNotEmpty) {
        _allUserTracks[userId] = trackPoints;
        notifyListeners();
      }
      
      return trackPoints;
    } catch (e) {
      debugPrint('获取用户轨迹异常: $e');
      return [];
    }
  }

  /// 清除数据
  void clear() {
    _stopAutoSync();
    
    _currentRescueId = null;
    _currentUserId = null;
    _allUserTracks.clear();
    _userSummary.clear();
    _isLoading = false;
    _isSyncing = false;
    _error = null;
    
    _trackSharingService.clearCache();
    notifyListeners();
    
    debugPrint('轨迹共享数据已清除');
  }

  // ==================== 私有方法 ====================

  /// 加载缓存数据
  void _loadCachedData() {
    _allUserTracks = _trackSharingService.getCachedUserTracks();
    _userSummary = _trackSharingService.getUserTrackSummary();
    
    if (_allUserTracks.isNotEmpty) {
      debugPrint('加载缓存数据: ${_allUserTracks.length} 个用户');
      notifyListeners();
    }
  }

  /// 更新本地数据
  Future<void> _updateLocalData() async {
    _allUserTracks = _trackSharingService.getCachedUserTracks();
    _userSummary = _trackSharingService.getUserTrackSummary();
    notifyListeners();
  }

  /// 启动自动同步
  void _startAutoSync() {
    _stopAutoSync(); // 确保没有重复的定时器
    
    // 每5分钟自动同步一次
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_trackSharingService.shouldSync()) {
        syncTracks();
      }
    });
    
    debugPrint('自动同步已启动');
  }

  /// 停止自动同步
  void _stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  @override
  void dispose() {
    _stopAutoSync();
    super.dispose();
  }
}
