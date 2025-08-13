import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rescue_app/presentation/pages/home_page.dart';

import '../../core/models/track_point_model.dart';
import '../../core/providers/rescue_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/providers/track_sharing_provider.dart';
import '../../core/services/background_location_service.dart';
import '../widgets/rescue_map_widget.dart';
import '../widgets/track_display_widget.dart';

/// 救援页面
///
/// 显示救援地图和轨迹信息的主页面
/// 包含地图显示、位置信息、控制按钮等功能
class RescuePage extends StatefulWidget {
  const RescuePage({super.key});

  @override
  State<RescuePage> createState() => _RescuePageState();
}

class _RescuePageState extends State<RescuePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _showInfoPanel = true;
  bool _isTracking = false;
  bool _showTrackView = false;
  List<TrackPointModel> _trackPoints = [];

  @override
  void initState() {
    super.initState();

    // 初始化动画
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // 启动动画
    _fadeController.forward();
    _slideController.forward();

    // 初始化服务
    _initializeServices();

    // 加载轨迹数据
    _loadTrackData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// 初始化服务
  Future<void> _initializeServices() async {
    final rescueProvider = context.read<RescueProvider>();
    final locationProvider = context.read<LocationProvider>();
    final syncProvider = context.read<SyncProvider>();
    final trackSharingProvider = context.read<TrackSharingProvider>();

    if (rescueProvider.currentRescue != null) {
      final rescueId = rescueProvider.currentRescue!.id;
      final userId = rescueProvider.getCurrentUserId();

      // 初始化位置服务
      await locationProvider.initialize();

      // 初始化同步服务
      await syncProvider.initialize(rescueId);

      // 初始化轨迹共享服务
      await trackSharingProvider.initialize(rescueId, userId);

      // 启动自动同步
      syncProvider.startAutoSync();
    }
  }

  /// 加载轨迹数据
  Future<void> _loadTrackData() async {
    final rescueProvider = context.read<RescueProvider>();
    if (rescueProvider.currentRescue != null) {
      try {
        // 从本地缓存加载轨迹点
        final trackPoints = await BackgroundLocationService.getLocalTrackPoints(
          rescueProvider.currentRescue!.id,
          rescueProvider.getCurrentUserId(),
        );

        if (mounted) {
          setState(() {
            _trackPoints = trackPoints;
          });
        }

        debugPrint('已加载 ${trackPoints.length} 个轨迹点');
      } catch (e) {
        debugPrint('加载轨迹数据失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<RescueProvider>(
        builder: (context, rescueProvider, child) {
          final rescue = rescueProvider.currentRescue;

          if (rescue == null) {
            return _buildNoRescueState();
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                // 地图背景
                _buildMapBackground(rescueProvider),

                // 顶部信息面板
                _buildTopInfoPanel(rescue),

                if (!_showInfoPanel) // 显示导航按钮
                  _buildNavigationButton(),

                // 左侧位置信息面板
                _buildLocationInfoPanel(),

                // 底部控制面板
                _buildBottomControlPanel(),

                // 右侧功能按钮
                _buildSideActionButtons(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建无救援状态
  Widget _buildNoRescueState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('救援页面'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '未找到救援信息',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '请返回首页重新加入救援',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建地图背景
  Widget _buildMapBackground(rescueProvider) {
    return Consumer<TrackSharingProvider>(
      builder: (context, trackSharingProvider, child) {
        if (_showTrackView) {
          // 显示轨迹视图
          return TrackDisplayWidget(
            rescueId: rescueProvider.currentRescue?.id ?? '',
            userId: rescueProvider.getCurrentUserId(),
            trackPoints: _trackPoints,
            showDetails: true,
          );
        } else {
          // 显示地图视图
          return RescueMapWidget(
            trackPoints: _trackPoints,
            allUserTracks: trackSharingProvider.allUserTracks,
            currentUserId: rescueProvider.getCurrentUserId(),
            showTrack: true,
            showCurrentLocation: true,
            onMapTap: (location) {
              // 处理地图点击
              debugPrint('地图点击: ${location.latitude}, ${location.longitude}');
            },
          );
        }
      },
    );
  }

  /// 构建顶部信息面板
  Widget _buildTopInfoPanel(rescue) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 救援标题行
              Row(
                children: [
                  IconButton(
                    onPressed: () => {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const HomePage(),
                        ),
                      )
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '救援 ${rescue.id}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleInfoPanel,
                    icon: Icon(
                      _showInfoPanel
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              // 救援描述
              Text(
                rescue.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 8),

              // 同步状态
              Consumer<SyncProvider>(
                builder: (context, syncProvider, child) {
                  return Row(
                    children: [
                      Icon(
                        syncProvider.isSyncing
                            ? Icons.sync
                            : Icons.sync_disabled,
                        color: syncProvider.isSyncing
                            ? Colors.green
                            : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        syncProvider.syncStatusDescription,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示顶部信息面板按钮
  Widget _buildNavigationButton() {
    return Positioned(
      top: 38,
      right: 16,
      child: IconButton(
        onPressed: _toggleInfoPanel,
        icon: Icon(
          _showInfoPanel ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 构建位置信息面板
  Widget _buildLocationInfoPanel() {
    return Positioned(
      left: 16,
      top: 200,
      child: Consumer<LocationProvider>(
        builder: (context, locationProvider, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前位置',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  locationProvider.currentLocationString,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locationProvider.currentAltitudeString,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locationProvider.currentAccuracyString,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建底部控制面板
  Widget _buildBottomControlPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Consumer2<LocationProvider, RescueProvider>(
          builder: (context, locationProvider, rescueProvider, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 视图切换按钮
                _buildViewToggleButton(),

                // 开始/停止记录按钮
                _buildTrackingButton(locationProvider, rescueProvider),

                // 轨迹共享按钮
                _buildTrackSharingButton(),

                // 标记位置按钮
                _buildMarkLocationButton(locationProvider),

                // 同步按钮
                _buildSyncButton(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建侧边功能按钮
  Widget _buildSideActionButtons() {
    return Positioned(
      right: 16,
      top: 200,
      child: Column(
        children: [
          // 缩放按钮
          FloatingActionButton(
            mini: true,
            heroTag: "zoom_in",
            onPressed: () {
              // 地图放大
              _zoomIn();
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.zoom_in, color: Colors.black87),
          ),

          const SizedBox(height: 8),

          FloatingActionButton(
            mini: true,
            heroTag: "zoom_out",
            onPressed: () {
              // 地图缩小
              _zoomOut();
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.zoom_out, color: Colors.black87),
          ),

          const SizedBox(height: 16),

          // 定位按钮
          FloatingActionButton(
            mini: true,
            heroTag: "my_location",
            onPressed: () {
              // 定位到当前位置
              _moveToCurrentLocation();
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// 构建轨迹记录按钮
  Widget _buildTrackingButton(
      LocationProvider locationProvider, RescueProvider rescueProvider) {
    final isTracking = locationProvider.isTracking;

    return FloatingActionButton.extended(
      heroTag: "tracking",
      onPressed: () => _toggleTracking(locationProvider, rescueProvider),
      backgroundColor: isTracking ? Colors.red : Colors.green,
      icon: Icon(
        isTracking ? Icons.stop : Icons.play_arrow,
        color: Colors.white,
      ),
      label: Text(
        isTracking ? '停止记录' : '开始记录',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建标记位置按钮
  Widget _buildMarkLocationButton(LocationProvider locationProvider) {
    return FloatingActionButton(
      heroTag: "mark_location",
      onPressed: () => _markCurrentLocation(locationProvider),
      backgroundColor: Colors.orange,
      child: const Icon(Icons.place, color: Colors.white),
    );
  }

  /// 构建同步按钮
  Widget _buildSyncButton() {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        return FloatingActionButton(
          heroTag: "sync",
          onPressed: syncProvider.canManualSync ? _performSync : null,
          backgroundColor: syncProvider.isSyncing ? Colors.grey : Colors.blue,
          child: syncProvider.isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.sync, color: Colors.white),
        );
      },
    );
  }

  /// 构建视图切换按钮
  Widget _buildViewToggleButton() {
    return FloatingActionButton(
      mini: true,
      heroTag: "view_toggle",
      onPressed: () {
        setState(() {
          _showTrackView = !_showTrackView;
        });
      },
      backgroundColor: _showTrackView ? Colors.orange : Colors.blue,
      child: Icon(
        _showTrackView ? Icons.map : Icons.timeline,
        color: Colors.white,
      ),
    );
  }

  /// 构建轨迹共享按钮
  Widget _buildTrackSharingButton() {
    return Consumer<TrackSharingProvider>(
      builder: (context, trackSharingProvider, child) {
        return FloatingActionButton(
          mini: true,
          heroTag: "track_sharing",
          onPressed: trackSharingProvider.isSyncing
              ? null
              : () async {
                  await trackSharingProvider.syncTracks();

                  if (mounted) {
                    final participantCount =
                        trackSharingProvider.participantCount;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('轨迹同步完成，共 $participantCount 个参与者'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
          backgroundColor:
              trackSharingProvider.isSyncing ? Colors.grey : Colors.purple,
          child: trackSharingProvider.isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.share_location, color: Colors.white),
        );
      },
    );
  }

  /// 切换信息面板显示
  void _toggleInfoPanel() {
    setState(() {
      _showInfoPanel = !_showInfoPanel;
    });

    if (_showInfoPanel) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  /// 切换轨迹记录
  Future<void> _toggleTracking(
      LocationProvider locationProvider, RescueProvider rescueProvider) async {
    final rescue = rescueProvider.currentRescue;
    if (rescue == null) return;

    if (locationProvider.isTracking) {
      await locationProvider.stopTracking();
    } else {
      final userId = rescueProvider.getCurrentUserId();
      await locationProvider.startTracking(rescue.id, userId);
    }
  }

  /// 标记当前位置
  Future<void> _markCurrentLocation(LocationProvider locationProvider) async {
    final success = await locationProvider.markCurrentLocation();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('位置已标记'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 执行同步
  Future<void> _performSync() async {
    final rescueProvider = context.read<RescueProvider>();
    final syncProvider = context.read<SyncProvider>();
    final rescue = rescueProvider.currentRescue;

    if (rescue == null) return;

    final userId = rescueProvider.getCurrentUserId();
    final success = await syncProvider.manualSync(rescue.id, userId);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('同步成功'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同步失败: ${syncProvider.syncError ?? "未知错误"}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 地图放大
  void _zoomIn() {
    // 通过地图组件的key来控制缩放
    // 这里简化处理，实际应该通过MapController
    debugPrint('地图放大');
  }

  /// 地图缩小
  void _zoomOut() {
    // 通过地图组件的key来控制缩放
    // 这里简化处理，实际应该通过MapController
    debugPrint('地图缩小');
  }

  /// 移动到当前位置
  void _moveToCurrentLocation() {
    final locationProvider = context.read<LocationProvider>();
    if (locationProvider.currentPosition != null) {
      // 通过地图组件的key来控制移动
      // 这里简化处理，实际应该通过MapController
      debugPrint('移动到当前位置: ${locationProvider.currentPosition}');
    }
  }
}
