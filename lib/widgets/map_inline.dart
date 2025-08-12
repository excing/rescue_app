import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/rescue.dart';
import '../models/track.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// 内联地图组件：在救援页直接展示地图与所有参与者轨迹
class MapInline extends StatefulWidget {
  final String rescueId;
  final Rescue? rescue;
  final double height;

  const MapInline({
    super.key,
    required this.rescueId,
    this.rescue,
    this.height = 320,
  });

  @override
  State<MapInline> createState() => _MapInlineState();
}

class _MapInlineState extends State<MapInline> {
  final MapController _mapController = MapController();
  final StorageService _storageService = StorageService();
  List<Track> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTracks();
    });
  }

  Future<void> _loadTracks() async {
    try {
      final compactTracks = await ApiService.getRescueTracksFromCompact(widget.rescueId);
      final legacyServerTracks = await ApiService.getRescueTracks(widget.rescueId);
      final localTracks = await _storageService.getRescueTracks(widget.rescueId);

      final all = <String, Track>{};
      for (final t in localTracks) { all[t.id] = t; }
      for (final t in legacyServerTracks) { all[t.id] = t; }
      for (final t in compactTracks) { all['track_${t.userId}'] = t; }

      setState(() {
        _tracks = all.values.toList();
        _loading = false;
      });

      // 初次定位到救援位置或首个点
      if (widget.rescue?.location != null) {
        _mapController.move(widget.rescue!.location, 15);
      } else if (_tracks.isNotEmpty && _tracks.first.points.isNotEmpty) {
        _mapController.move(_tracks.first.points.first.position, 15);
      }
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.rescue?.location ?? const LatLng(39.9042, 116.4074),
                initialZoom: 15,
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://huw.blendiv.com/api/tile?s={s}&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'com.example.rescue_app',
                  maxZoom: 18,
                ),
                if (widget.rescue?.location != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: widget.rescue!.location,
                      width: 24,
                      height: 24,
                      child: const Icon(Icons.emergency, color: Colors.red, size: 20),
                    ),
                  ]),
                PolylineLayer(
                  polylines: _tracks.map((t) => Polyline(
                    points: t.points.map((p) => p.position).toList(),
                    color: t.color,
                    strokeWidth: 2.5,
                  )).toList(),
                ),
              ],
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x11000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadTracks,
                  tooltip: '刷新轨迹',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

