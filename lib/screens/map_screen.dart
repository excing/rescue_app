import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/rescue.dart';
import '../models/track.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// 地图页面 - 显示救援位置和所有人员轨迹
class MapScreen extends StatefulWidget {
  final String rescueId;
  final Rescue? rescue;

  const MapScreen({
    super.key,
    required this.rescueId,
    this.rescue,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final StorageService _storageService = StorageService();
  
  List<Track> _tracks = [];
  bool _isLoading = true;
  bool _showCurrentLocation = true;
  bool _followCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _loadMapData();
    _startLocationUpdates();
  }

  /// 加载地图数据
  Future<void> _loadMapData() async {
    try {
      // 加载轨迹数据
      await _loadTracks();
      
      // 如果有救援位置，移动地图到救援位置
      if (widget.rescue?.location != null) {
        _mapController.move(widget.rescue!.location, 15.0);
      } else {
        // 否则移动到当前位置
        final locationService = Provider.of<LocationService>(context, listen: false);
        final position = locationService.currentPosition;
        if (position != null) {
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            15.0,
          );
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('加载地图数据失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 加载轨迹数据
  Future<void> _loadTracks() async {
    try {
      // 从服务器获取轨迹
      final serverTracks = await ApiService.getRescueTracks(widget.rescueId);
      
      // 从本地获取轨迹
      final localTracks = await _storageService.getRescueTracks(widget.rescueId);
      
      // 合并轨迹数据（去重）
      final allTracks = <String, Track>{};
      
      for (final track in localTracks) {
        allTracks[track.id] = track;
      }
      
      for (final track in serverTracks) {
        allTracks[track.id] = track;
      }
      
      setState(() {
        _tracks = allTracks.values.toList();
      });
    } catch (e) {
      print('加载轨迹失败: $e');
    }
  }

  /// 开始位置更新
  void _startLocationUpdates() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    locationService.locationStream.listen((locationPoint) {
      if (_followCurrentLocation) {
        _mapController.move(locationPoint.position, _mapController.camera.zoom);
      }
    });
  }

  /// 移动到当前位置
  void _moveToCurrentLocation() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final position = locationService.currentPosition;
    if (position != null) {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16.0,
      );
    }
  }

  /// 移动到救援位置
  void _moveToRescueLocation() {
    if (widget.rescue?.location != null) {
      _mapController.move(widget.rescue!.location, 16.0);
    }
  }

  /// 适应所有轨迹
  void _fitAllTracks() {
    if (_tracks.isEmpty) return;

    final allPoints = <LatLng>[];
    
    // 添加救援位置
    if (widget.rescue?.location != null) {
      allPoints.add(widget.rescue!.location);
    }
    
    // 添加所有轨迹点
    for (final track in _tracks) {
      for (final point in track.points) {
        allPoints.add(point.position);
      }
    }
    
    if (allPoints.isNotEmpty) {
      final bounds = _calculateBounds(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  /// 计算边界
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('救援地图 ${widget.rescueId}'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadTracks,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新轨迹',
          ),
          IconButton(
            onPressed: _fitAllTracks,
            icon: const Icon(Icons.fit_screen),
            tooltip: '适应所有轨迹',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 地图
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.rescue?.location ?? 
                        const LatLng(39.9042, 116.4074), // 默认北京
                    initialZoom: 15.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    // 瓦片图层 - 使用OpenStreetMap
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.rescue_app',
                      maxZoom: 18,
                    ),
                    
                    // 救援位置标记
                    if (widget.rescue?.location != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.rescue!.location,
                            width: 60,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red[600],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.emergency,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    
                    // 轨迹线条
                    PolylineLayer(
                      polylines: _tracks.map((track) {
                        return Polyline(
                          points: track.points.map((p) => p.position).toList(),
                          color: track.color,
                          strokeWidth: 3.0,
                        );
                      }).toList(),
                    ),
                    
                    // 当前位置标记
                    if (_showCurrentLocation)
                      Consumer<LocationService>(
                        builder: (context, locationService, child) {
                          final position = locationService.currentPosition;
                          if (position == null) return const SizedBox.shrink();
                          
                          return MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(position.latitude, position.longitude),
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue[600],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    
                    // 轨迹起点和终点标记
                    MarkerLayer(
                      markers: _tracks.expand((track) {
                        final markers = <Marker>[];
                        
                        if (track.points.isNotEmpty) {
                          // 起点
                          markers.add(
                            Marker(
                              point: track.points.first.position,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: track.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          );
                          
                          // 终点（如果不是活跃轨迹）
                          if (!track.isActive && track.points.length > 1) {
                            markers.add(
                              Marker(
                                point: track.points.last.position,
                                width: 20,
                                height: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: track.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.stop,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                        
                        return markers;
                      }).toList(),
                    ),
                  ],
                ),
                
                // 控制按钮
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: Column(
                    children: [
                      // 当前位置按钮
                      FloatingActionButton(
                        heroTag: "current_location",
                        onPressed: _moveToCurrentLocation,
                        backgroundColor: Colors.blue[600],
                        child: const Icon(Icons.my_location, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      
                      // 救援位置按钮
                      if (widget.rescue?.location != null)
                        FloatingActionButton(
                          heroTag: "rescue_location",
                          onPressed: _moveToRescueLocation,
                          backgroundColor: Colors.red[600],
                          child: const Icon(Icons.emergency, color: Colors.white),
                        ),
                    ],
                  ),
                ),
                
                // 轨迹信息面板
                if (_tracks.isNotEmpty)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '轨迹信息 (${_tracks.length}条)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _tracks.length,
                              itemBuilder: (context, index) {
                                final track = _tracks[index];
                                return Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: track.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: track.color,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        track.userName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: track.color,
                                        ),
                                      ),
                                      Text(
                                        '${track.points.length}点',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: track.color,
                                        ),
                                      ),
                                      if (track.totalDistance != null)
                                        Text(
                                          '${(track.totalDistance! / 1000).toStringAsFixed(1)}km',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: track.color,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
