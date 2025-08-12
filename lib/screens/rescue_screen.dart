import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/simple_background_service.dart';
import '../models/rescue.dart';
import '../widgets/map_inline.dart';
import 'map_screen.dart';

/// 救援页面 - 主要功能页面
class RescueScreen extends StatefulWidget {
  final String rescueId;

  const RescueScreen({
    super.key,
    required this.rescueId,
  });

  @override
  State<RescueScreen> createState() => _RescueScreenState();
}

class _RescueScreenState extends State<RescueScreen> {
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  final SyncService _syncService = SyncService();
  final SimpleBackgroundService _backgroundService = SimpleBackgroundService();
  // final OptimizedStorageService _optimizedStorage = OptimizedStorageService();

  Rescue? _rescue;
  bool _isLoading = true;
  bool _isTracking = false;
  String _userId = '';
  Map<String, dynamic> _trackStats = {};

  @override
  void initState() {
    super.initState();
    _initializeRescue();
  }

  @override
  void dispose() {
    if (_isTracking) {
      _locationService.stopTracking();
    }
    _syncService.stop();
    super.dispose();
  }

  /// 初始化救援信息
  Future<void> _initializeRescue() async {
    try {
      // 生成用户ID
      _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

      // 获取救援信息
      _rescue = await ApiService.getRescue(widget.rescueId);
      _rescue ??= await _storageService.getRescue(widget.rescueId);

      if (_rescue == null) {
        _showToast('救援信息不存在');
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      _locationService.initialize();
      // 获取轨迹统计信息
      await _loadTrackStats();

      // 初始化同步服务
      await _syncService.initialize(widget.rescueId, _userId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('初始化救援失败: $e');
      _showToast('加载救援信息失败');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  /// 加载轨迹统计信息
  Future<void> _loadTrackStats() async {
    try {
      final stats = await _backgroundService.getCurrentTrackStats();
      setState(() {
        _trackStats = stats;
      });
    } catch (e) {
      print('加载轨迹统计失败: $e');
    }
  }

  /// 开始/停止轨迹记录
  Future<void> _toggleTracking() async {
    if (_isTracking) {
      // 停止轨迹记录
      await _backgroundService.stopBackgroundTracking();
      setState(() {
        _isTracking = false;
      });
      _showToast('轨迹记录已停止');
    } else {
      // 开始轨迹记录
      final success = await _backgroundService.startBackgroundTracking(
          widget.rescueId, _userId);
      if (success) {
        setState(() {
          _isTracking = true;
        });
        _showToast('轨迹记录已开始');

        // 定期更新统计信息
        Timer.periodic(const Duration(seconds: 30), (timer) {
          if (!_isTracking) {
            timer.cancel();
            return;
          }
          _loadTrackStats();
        });
      } else {
        _showToast('无法开始轨迹记录，请检查位置权限');
      }
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('救援 ${widget.rescueId}'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadTrackStats,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // 可滚动的主要内容区域
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        // 救援信息卡片 + 地图
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.emergency,
                                    color: Colors.red[600],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '救援信息',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _rescue?.description ?? '无描述',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_rescue?.location != null) ...[
                                Text(
                                  '位置: ${_rescue!.location.latitude.toStringAsFixed(6)}, ${_rescue!.location.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_rescue!.altitude != null)
                                  Text(
                                    '海拔: ${_rescue!.altitude!.toStringAsFixed(1)}m',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],

                              const SizedBox(height: 12),
                              // 内联地图：显示所有参与者轨迹
                              MapInline(
                                  rescueId: widget.rescueId, rescue: _rescue),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 当前位置信息
                        Consumer<LocationService>(
                          builder: (context, locationService, child) {
                            final position = locationService.currentPosition;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.my_location,
                                        color: Colors.green[600],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '当前位置',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                      const Spacer(),
                                      if (locationService.isAccuracyGood())
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green[600],
                                          size: 16,
                                        )
                                      else
                                        Icon(
                                          Icons.warning,
                                          color: Colors.orange[600],
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (position != null) ...[
                                    Text(
                                      '纬度: ${position.latitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      '经度: ${position.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      '精度: ${position.accuracy.toStringAsFixed(1)}m',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    if (position.altitude != 0)
                                      Text(
                                        '海拔: ${position.altitude.toStringAsFixed(1)}m',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                  ] else
                                    Text(
                                      '正在获取位置...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // 轨迹统计
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue[200]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.timeline,
                                    color: Colors.blue[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '轨迹统计',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '记录点数: ${_trackStats['pointCount'] ?? 0}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          '总距离: ${((_trackStats['distance'] ?? 0.0) / 1000).toStringAsFixed(2)}km',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '时长: ${_formatDuration(_trackStats['duration'] ?? Duration.zero)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          '状态: ${_isTracking ? "记录中" : "已停止"}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _isTracking
                                                ? Colors.green[700]
                                                : Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 为底部按钮留出空间
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // 固定在底部的控制按钮区域
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 开始/停止记录按钮
                          ElevatedButton.icon(
                            onPressed: _toggleTracking,
                            icon: Icon(
                                _isTracking ? Icons.stop : Icons.play_arrow),
                            label: Text(_isTracking ? '停止记录' : '开始记录'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isTracking
                                  ? Colors.red[600]
                                  : Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // 手动同步按钮
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _syncService.manualSync();
                              _showToast('已触发同步');
                            },
                            icon: const Icon(Icons.sync),
                            label: const Text('同步'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // 地图按钮
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapScreen(
                                    rescueId: widget.rescueId,
                                    rescue: _rescue,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.map),
                            label: const Text('地图'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
