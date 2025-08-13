import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/track_point_model.dart';
import '../../core/providers/location_provider.dart';
import 'rescue_map_widget.dart';

/// 轨迹显示组件
///
/// 显示救援轨迹的详细信息和地图视图
class TrackDisplayWidget extends StatefulWidget {
  /// 救援ID
  final String rescueId;

  /// 用户ID
  final String userId;

  /// 轨迹点列表
  final List<TrackPointModel> trackPoints;

  /// 是否显示详细信息
  final bool showDetails;

  const TrackDisplayWidget({
    super.key,
    required this.rescueId,
    required this.userId,
    this.trackPoints = const [],
    this.showDetails = true,
  });

  @override
  State<TrackDisplayWidget> createState() => _TrackDisplayWidgetState();
}

class _TrackDisplayWidgetState extends State<TrackDisplayWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isMapView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        return Column(
          children: [
            // 顶部控制栏
            if (widget.showDetails) _buildControlBar(),

            // 主要内容区域
            Expanded(
              child: _isMapView ? _buildMapView() : _buildListView(),
            ),

            // 底部统计信息
            if (widget.showDetails) _buildStatsBar(),
          ],
        );
      },
    );
  }

  /// 构建控制栏
  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 视图切换按钮
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('地图'),
                icon: Icon(Icons.map),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('列表'),
                icon: Icon(Icons.list),
              ),
            ],
            selected: {_isMapView},
            onSelectionChanged: (Set<bool> selection) {
              setState(() {
                _isMapView = selection.first;
              });
            },
          ),

          const Spacer(),

          // 操作按钮
          IconButton(
            onPressed: _exportTrack,
            icon: const Icon(Icons.download),
            tooltip: '导出轨迹',
          ),
          IconButton(
            onPressed: _shareTrack,
            icon: const Icon(Icons.share),
            tooltip: '分享轨迹',
          ),
        ],
      ),
    );
  }

  /// 构建地图视图
  Widget _buildMapView() {
    return RescueMapWidget(
      trackPoints: widget.trackPoints,
      showTrack: true,
      showCurrentLocation: true,
      onMapTap: (location) {
        // 处理地图点击事件
        _showLocationDetails(location);
      },
    );
  }

  /// 构建列表视图
  Widget _buildListView() {
    if (widget.trackPoints.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无轨迹数据',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.trackPoints.length,
      itemBuilder: (context, index) {
        final point = widget.trackPoints[index];
        final isFirst = index == 0;
        final isLast = index == widget.trackPoints.length - 1;

        return _buildTrackPointItem(point, isFirst, isLast);
      },
    );
  }

  /// 构建轨迹点项目
  Widget _buildTrackPointItem(
      TrackPointModel point, bool isFirst, bool isLast) {
    Color pointColor = Colors.blue;
    IconData pointIcon = Icons.location_on;

    if (isFirst) {
      pointColor = Colors.green;
      pointIcon = Icons.play_arrow;
    } else if (isLast) {
      pointColor = Colors.orange;
      pointIcon = Icons.stop;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: pointColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            pointIcon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          '${(point.latitude / 10000000.0).toStringAsFixed(6)}, ${(point.longitude / 10000000.0).toStringAsFixed(6)}',
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '时间: ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(point.timestamp))}'),
            Text('海拔: ${(point.altitude / 100.0).toStringAsFixed(1)}m'),
            Text('精度: ${(point.accuracy / 100.0).toStringAsFixed(1)}m'),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _showPointDetails(point),
          icon: const Icon(Icons.info_outline),
        ),
      ),
    );
  }

  /// 构建统计栏
  Widget _buildStatsBar() {
    if (widget.trackPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final stats = _calculateTrackStats();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('总点数', '${widget.trackPoints.length}'),
          _buildStatItem(
              '总距离', '${stats['distance']?.toStringAsFixed(2) ?? '0'}km'),
          _buildStatItem('持续时间', stats['duration'] ?? '0分钟'),
          _buildStatItem(
              '平均速度', '${stats['avgSpeed']?.toStringAsFixed(1) ?? '0'}km/h'),
        ],
      ),
    );
  }

  /// 构建统计项目
  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 计算轨迹统计信息
  Map<String, dynamic> _calculateTrackStats() {
    if (widget.trackPoints.length < 2) {
      return {
        'distance': 0.0,
        'duration': '0分钟',
        'avgSpeed': 0.0,
      };
    }

    double totalDistance = 0.0;
    final startTime =
        DateTime.fromMillisecondsSinceEpoch(widget.trackPoints.first.timestamp);
    final endTime =
        DateTime.fromMillisecondsSinceEpoch(widget.trackPoints.last.timestamp);

    // 计算总距离
    for (int i = 1; i < widget.trackPoints.length; i++) {
      final prev = widget.trackPoints[i - 1];
      final curr = widget.trackPoints[i];

      // 使用简单的距离计算公式
      final distance = _calculateDistance(
        prev.latitude / 10000000.0,
        prev.longitude / 10000000.0,
        curr.latitude / 10000000.0,
        curr.longitude / 10000000.0,
      );
      totalDistance += distance;
    }

    // 计算持续时间
    final duration = endTime.difference(startTime);
    final durationText = duration.inHours > 0
        ? '${duration.inHours}小时${duration.inMinutes % 60}分钟'
        : '${duration.inMinutes}分钟';

    // 计算平均速度
    final avgSpeed = duration.inSeconds > 0
        ? (totalDistance / duration.inSeconds) * 3.6 // m/s to km/h
        : 0.0;

    return {
      'distance': totalDistance / 1000, // 转换为公里
      'duration': durationText,
      'avgSpeed': avgSpeed,
    };
  }

  /// 计算两点间距离（米）
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 地球半径（米）
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// 显示位置详情
  void _showLocationDetails(dynamic location) {
    // TODO: 实现位置详情显示
  }

  /// 显示轨迹点详情
  void _showPointDetails(TrackPointModel point) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('轨迹点详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('纬度: ${(point.latitude / 10000000.0).toStringAsFixed(6)}'),
            Text('经度: ${(point.longitude / 10000000.0).toStringAsFixed(6)}'),
            Text('海拔: ${(point.altitude / 100.0).toStringAsFixed(1)}m'),
            Text('精度: ${(point.accuracy / 100.0).toStringAsFixed(1)}m'),
            Text('时间: ${DateTime.fromMillisecondsSinceEpoch(point.timestamp)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 导出轨迹
  void _exportTrack() {
    // TODO: 实现轨迹导出功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('轨迹导出功能开发中...')),
    );
  }

  /// 分享轨迹
  void _shareTrack() {
    // TODO: 实现轨迹分享功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('轨迹分享功能开发中...')),
    );
  }
}
