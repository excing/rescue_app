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

  /// 轨迹点列表
  final List<TrackPointModel> trackPoints;

  /// 地图点击回调
  final Function(LatLng)? onMapTap;

  const RescueMapWidget({
    super.key,
    this.center,
    this.initialZoom = 15.0,
    this.showCurrentLocation = true,
    this.showTrack = true,
    this.trackPoints = const [],
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
            if (widget.showTrack && widget.trackPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.trackPoints
                        .map((point) => LatLng(
                              point.latitude / 10000000.0, // 转换为double
                              point.longitude / 10000000.0, // 转换为double
                            ))
                        .toList(),
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
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

    // 轨迹点标记（仅显示关键点）
    if (widget.showTrack && widget.trackPoints.isNotEmpty) {
      // 显示起点
      if (widget.trackPoints.isNotEmpty) {
        final startPoint = widget.trackPoints.first;
        markers.add(
          Marker(
            point: LatLng(
              startPoint.latitude / 10000000.0,
              startPoint.longitude / 10000000.0,
            ),
            width: 30,
            height: 30,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        );
      }

      // 显示终点（如果不是起点）
      if (widget.trackPoints.length > 1) {
        final endPoint = widget.trackPoints.last;
        markers.add(
          Marker(
            point: LatLng(
              endPoint.latitude / 10000000.0,
              endPoint.longitude / 10000000.0,
            ),
            width: 30,
            height: 30,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.stop,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        );
      }
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
