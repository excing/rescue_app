import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/track_point_model.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/rescue_provider.dart';

/// 救援地图组件
///
/// 使用开源地图方案显示救援位置和轨迹
class RescueMapWidget extends StatefulWidget {
  /// 地图中心点
  final LatLng? center;

  /// 初始缩放级别
  final double initialZoom;

  /// 是否显示当前位置
  final bool showCurrentLocation;

  /// 是否显示轨迹
  final bool showTrack;

  /// 当前用户轨迹点列表
  final List<TrackPointModel> trackPoints;

  /// 所有用户轨迹数据 Map<userId, List<TrackPointModel>>
  final Map<String, List<TrackPointModel>> allUserTracks;

  /// 当前用户ID
  final String? currentUserId;

  /// 地图点击回调
  final Function(LatLng)? onMapTap;

  const RescueMapWidget({
    super.key,
    this.center,
    this.initialZoom = 15.0,
    this.showCurrentLocation = true,
    this.showTrack = true,
    this.trackPoints = const [],
    this.allUserTracks = const {},
    this.currentUserId,
    this.onMapTap,
  });

  @override
  State<RescueMapWidget> createState() => _RescueMapWidgetState();
}

class _RescueMapWidgetState extends State<RescueMapWidget> {
  late MapController _mapController;
  LatLng? _currentCenter;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.center ?? const LatLng(39.9042, 116.4074); // 默认北京
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// 构建多用户轨迹线
  List<Polyline> _buildTrackPolylines() {
    final polylines = <Polyline>[];

    // 定义不同用户的轨迹颜色
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    int colorIndex = 0;

    // 添加当前用户轨迹（蓝色，较粗）
    if (widget.trackPoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: widget.trackPoints
              .map((point) => LatLng(
                    point.latitude / 10000000.0,
                    point.longitude / 10000000.0,
                  ))
              .toList(),
          strokeWidth: 4.0,
          color: Colors.blue,
        ),
      );
    }

    // 添加其他用户轨迹
    for (final entry in widget.allUserTracks.entries) {
      final userId = entry.key;
      final trackPoints = entry.value;

      // 跳过当前用户（已经添加过了）
      if (userId == widget.currentUserId) continue;

      if (trackPoints.isNotEmpty) {
        final color = colors[colorIndex % colors.length];
        colorIndex++;

        polylines.add(
          Polyline(
            points: trackPoints
                .map((point) => LatLng(
                      point.latitude / 10000000.0,
                      point.longitude / 10000000.0,
                    ))
                .toList(),
            strokeWidth: 3.0,
            color: color,
          ),
        );
      }
    }

    return polylines;
  }

  /// 构建用户轨迹标记
  List<Marker> _buildUserTrackMarkers() {
    final markers = <Marker>[];

    // 定义不同用户的标记颜色
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    int colorIndex = 0;

    // 为每个用户添加起点和终点标记
    for (final entry in widget.allUserTracks.entries) {
      final userId = entry.key;
      final trackPoints = entry.value;

      if (trackPoints.isEmpty) continue;

      final color = userId == widget.currentUserId
          ? Colors.blue
          : colors[colorIndex % colors.length];

      if (userId != widget.currentUserId) {
        colorIndex++;
      }

      // 起点标记
      final startPoint = trackPoints.first;
      markers.add(
        Marker(
          point: LatLng(
            startPoint.latitude / 10000000.0,
            startPoint.longitude / 10000000.0,
          ),
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      );

      // 终点标记（如果不是起点）
      if (trackPoints.length > 1) {
        final endPoint = trackPoints.last;
        markers.add(
          Marker(
            point: LatLng(
              endPoint.latitude / 10000000.0,
              endPoint.longitude / 10000000.0,
            ),
            width: 24,
            height: 24,
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.stop,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        );
      }

      // 当前位置标记（最后一个点）
      if (trackPoints.isNotEmpty) {
        final lastPoint = trackPoints.last;
        markers.add(
          Marker(
            point: LatLng(
              lastPoint.latitude / 10000000.0,
              lastPoint.longitude / 10000000.0,
            ),
            width: 20,
            height: 20,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  userId.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationProvider, RescueProvider>(
      builder: (context, locationProvider, rescueProvider, child) {
        // 更新地图中心点
        if (widget.showCurrentLocation &&
            locationProvider.currentPosition != null) {
          _currentCenter = LatLng(
            locationProvider.currentPosition!.latitude,
            locationProvider.currentPosition!.longitude,
          );
        }

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentCenter!,
            initialZoom: widget.initialZoom,
            minZoom: 3.0,
            maxZoom: 18.0,
            onTap: (tapPosition, point) {
              widget.onMapTap?.call(point);
            },
          ),
          children: [
            // 地图瓦片层 - 使用OpenStreetMap
            TileLayer(
              urlTemplate:
                  'https://huw.blendiv.com/api/tile?s={s}&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.blendiv.rescue_app',
              maxZoom: 18,
            ),

            // 轨迹线层
            if (widget.showTrack)
              PolylineLayer(
                polylines: _buildTrackPolylines(),
              ),

            // 标记层
            MarkerLayer(
              markers: _buildMarkers(locationProvider, rescueProvider),
            ),
          ],
        );
      },
    );
  }

  /// 构建地图标记
  List<Marker> _buildMarkers(
      LocationProvider locationProvider, RescueProvider rescueProvider) {
    List<Marker> markers = [];

    // 当前位置标记
    if (widget.showCurrentLocation &&
        locationProvider.currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(
            locationProvider.currentPosition!.latitude,
            locationProvider.currentPosition!.longitude,
          ),
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 15,
            ),
          ),
        ),
      );
    }

    // 救援位置标记
    final rescue = rescueProvider.currentRescue;
    if (rescue != null) {
      markers.add(
        Marker(
          point: LatLng(rescue.location.latitude, rescue.location.longitude),
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.emergency,
              color: Colors.white,
              size: 15,
            ),
          ),
        ),
      );
    }

    // 多用户轨迹标记
    if (widget.showTrack) {
      markers.addAll(_buildUserTrackMarkers());
    }

    return markers;
  }

  /// 移动地图到指定位置
  void moveToLocation(LatLng location, {double? zoom}) {
    _mapController.move(location, zoom ?? widget.initialZoom);
  }

  /// 移动地图到当前位置
  void moveToCurrentLocation() {
    final locationProvider = context.read<LocationProvider>();
    if (locationProvider.currentPosition != null) {
      moveToLocation(
        LatLng(
          locationProvider.currentPosition!.latitude,
          locationProvider.currentPosition!.longitude,
        ),
      );
    }
  }

  /// 适配显示所有轨迹点
  void fitTrackBounds() {
    if (widget.trackPoints.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(
      widget.trackPoints
          .map((point) => LatLng(
                point.latitude / 10000000.0,
                point.longitude / 10000000.0,
              ))
          .toList(),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }
}
