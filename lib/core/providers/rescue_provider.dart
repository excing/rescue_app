import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/rescue_model.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

/// 救援状态管理Provider
///
/// 负责管理救援相关的状态和业务逻辑
/// 包括创建救援、加入救援、获取救援信息等功能
class RescueProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;
  final ApiService _apiService = ApiService.instance;

  // 状态变量
  RescueModel? _currentRescue;
  bool _isLoading = false;
  String? _error;
  List<RescueModel> _recentRescues = [];

  // Getters
  RescueModel? get currentRescue => _currentRescue;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<RescueModel> get recentRescues => _recentRescues;
  bool get hasCurrentRescue => _currentRescue != null;

  /// 生成随机4位数字救援ID
  String generateRescueId() {
    final random = Random();
    final id = (1000 + random.nextInt(9000)).toString();
    return id;
  }

  /// 生成用户ID
  String generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 创建新救援
  Future<bool> createRescue({
    required String description,
    required double latitude,
    required double longitude,
    required double altitude,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // 生成救援ID和用户ID
      final rescueId = generateRescueId();
      final userId = generateUserId();

      // 创建救援模型
      final rescue = RescueModel(
        id: rescueId,
        description: description,
        location: LocationCoordinate(
          latitude: latitude,
          longitude: longitude,
        ),
        altitude: altitude,
        createdAt: DateTime.now(),
        createdBy: userId,
        isActive: true,
      );

      // 保存到本地数据库
      await _databaseService.insertRescue(rescue);

      // 上传到服务器
      final apiResult = await _apiService.createRescue(rescue);
      if (apiResult.isSuccess) {
        // 标记为已同步
        await _databaseService.markRescueSynced(rescueId);
      } else {
        debugPrint('上传救援数据失败: ${apiResult.error}');
        // 不影响本地创建，稍后同步
      }

      // 设置为当前救援
      _currentRescue = rescue;

      // 刷新最近救援列表
      await _loadRecentRescues();

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('创建救援失败: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 加入救援
  Future<bool> joinRescue(String rescueId) async {
    try {
      _setLoading(true);
      _clearError();

      // 先从本地数据库查找
      RescueModel? rescue = await _databaseService.getRescue(rescueId);

      if (rescue == null) {
        // 从服务器获取救援信息
        final apiResult = await _apiService.getRescue(rescueId);
        if (apiResult.isSuccess) {
          rescue = apiResult.data!;
          // 保存到本地数据库
          await _databaseService.insertRescue(rescue);
        } else {
          _setError('救援不存在或网络连接失败');
          _setLoading(false);
          return false;
        }
      }

      // 设置为当前救援
      _currentRescue = rescue;

      // 刷新最近救援列表
      await _loadRecentRescues();

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('加入救援失败: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 离开当前救援
  void leaveRescue() {
    _currentRescue = null;
    _clearError();
    notifyListeners();
  }

  /// 刷新当前救援信息
  Future<bool> refreshCurrentRescue() async {
    if (_currentRescue == null) return false;

    try {
      _setLoading(true);
      _clearError();

      final apiResult = await _apiService.getRescue(_currentRescue!.id);
      if (apiResult.isSuccess) {
        _currentRescue = apiResult.data!;
        // 更新本地数据库
        await _databaseService.insertRescue(_currentRescue!);
        await _databaseService.markRescueSynced(_currentRescue!.id);
      } else {
        _setError('刷新救援信息失败: ${apiResult.error}');
        _setLoading(false);
        return false;
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('刷新救援信息失败: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 加载最近的救援列表
  Future<void> loadRecentRescues() async {
    await _loadRecentRescues();
    notifyListeners();
  }

  /// 内部方法：加载最近救援列表
  Future<void> _loadRecentRescues() async {
    try {
      _recentRescues = await _databaseService.getAllRescues();
    } catch (e) {
      debugPrint('加载最近救援列表失败: $e');
      _recentRescues = [];
    }
  }

  /// 删除救援记录
  Future<bool> deleteRescue(String rescueId) async {
    try {
      await _databaseService.deleteRescue(rescueId);

      // 如果删除的是当前救援，清空当前救援
      if (_currentRescue?.id == rescueId) {
        _currentRescue = null;
      }

      // 刷新最近救援列表
      await _loadRecentRescues();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('删除救援记录失败: $e');
      return false;
    }
  }

  /// 检查救援ID是否有效
  Future<bool> validateRescueId(String rescueId) async {
    // 检查格式：4位数字
    if (rescueId.length != 4 || !RegExp(r'^\d{4}$').hasMatch(rescueId)) {
      return false;
    }

    try {
      // 先检查本地数据库
      final localRescue = await _databaseService.getRescue(rescueId);
      if (localRescue != null) {
        return true;
      }

      // 检查服务器
      final apiResult = await _apiService.checkRescueExists(rescueId);
      return apiResult.isSuccess && apiResult.data == true;
    } catch (e) {
      debugPrint('验证救援ID失败: $e');
      return false;
    }
  }

  /// 获取当前用户ID
  String getCurrentUserId() {
    return _currentRescue?.createdBy ?? generateUserId();
  }

  // ==================== 私有方法 ====================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
