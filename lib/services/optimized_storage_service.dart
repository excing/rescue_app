import 'dart:convert';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../models/rescue.dart';
import '../models/location_point.dart';

/// 优化的存储服务 - 减少数据量，提高性能
class OptimizedStorageService {
  static final OptimizedStorageService _instance =
      OptimizedStorageService._internal();
  factory OptimizedStorageService() => _instance;
  OptimizedStorageService._internal();

  Database? _database;
  SharedPreferences? _prefs;

  // 数据压缩配置
  static const int _maxPointsPerBatch = 50; // 每批最多50个点
  static const double _minDistanceFilter = 2.0; // 最小距离过滤2米
  static const int _maxStorageDays = 7; // 最多存储7天数据

  /// 初始化存储服务
  Future<bool> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _initDatabase();
      return true;
    } catch (e) {
      print('初始化优化存储服务失败: $e');
      return false;
    }
  }

  /// 初始化数据库
  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'rescue_app_optimized.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  /// 创建数据库表
  Future<void> _createTables(Database db, int version) async {
    // 救援表
    await db.execute('''
      CREATE TABLE rescues (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        created_at INTEGER NOT NULL,
        created_by TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 压缩的位置点表 - 只存储关键信息
    await db.execute('''
      CREATE TABLE location_points_compressed (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rescue_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        lat_lng_compressed TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        accuracy REAL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (rescue_id) REFERENCES rescues (id)
      )
    ''');

    // 轨迹摘要表 - 存储轨迹统计信息
    await db.execute('''
      CREATE TABLE track_summaries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        rescue_id TEXT NOT NULL,
        color INTEGER NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        total_distance REAL,
        total_duration INTEGER,
        point_count INTEGER DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (rescue_id) REFERENCES rescues (id)
      )
    ''');

    // 创建索引
    await db.execute(
        'CREATE INDEX idx_location_compressed_rescue_user ON location_points_compressed(rescue_id, user_id)');
    await db.execute(
        'CREATE INDEX idx_location_compressed_timestamp ON location_points_compressed(timestamp)');
    await db.execute(
        'CREATE INDEX idx_track_summaries_rescue ON track_summaries(rescue_id)');
  }

  /// 压缩经纬度数据 - 减少存储空间
  String _compressLatLng(double lat, double lng, double? altitude) {
    // 保留6位小数精度，足够0.1米精度
    final latStr = lat.toStringAsFixed(6);
    final lngStr = lng.toStringAsFixed(6);
    if (altitude != null) {
      final altStr = altitude.toStringAsFixed(1);
      return '$latStr,$lngStr,$altStr';
    }
    return '$latStr,$lngStr';
  }

  /// 解压缩经纬度数据
  Map<String, double?> _decompressLatLng(String compressed) {
    final parts = compressed.split(',');
    return {
      'latitude': double.parse(parts[0]),
      'longitude': double.parse(parts[1]),
      'altitude': parts.length > 2 ? double.parse(parts[2]) : null,
    };
  }

  /// 智能保存位置点 - 过滤重复和无意义的点
  Future<bool> saveLocationPointSmart(LocationPoint point) async {
    try {
      if (_database == null) await _initDatabase();

      // 获取最后一个位置点
      final lastPoint =
          await _getLastLocationPoint(point.rescueId, point.userId);

      // 距离过滤 - 如果移动距离小于阈值，不保存
      if (lastPoint != null) {
        final distance = point.distanceTo(lastPoint);
        if (distance < _minDistanceFilter) {
          print(
              '距离过滤: ${distance.toStringAsFixed(1)}m < ${_minDistanceFilter}m');
          return true; // 返回true但不保存
        }
      }

      // 压缩并保存
      final compressed = _compressLatLng(
        point.position.latitude,
        point.position.longitude,
        point.altitude,
      );

      await _database!.insert(
        'location_points_compressed',
        {
          'rescue_id': point.rescueId,
          'user_id': point.userId,
          'lat_lng_compressed': compressed,
          'timestamp': point.timestamp.millisecondsSinceEpoch,
          'accuracy': point.accuracy,
          'is_synced': 0,
        },
      );

      // 更新轨迹摘要
      await _updateTrackSummary(point);

      return true;
    } catch (e) {
      print('智能保存位置点失败: $e');
      return false;
    }
  }

  /// 获取最后一个位置点
  Future<LocationPoint?> _getLastLocationPoint(
      String rescueId, String userId) async {
    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'location_points_compressed',
        where: 'rescue_id = ? AND user_id = ?',
        whereArgs: [rescueId, userId],
        orderBy: 'timestamp DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final map = maps.first;
        final decompressed = _decompressLatLng(map['lat_lng_compressed']);
        return LocationPoint(
          position:
              LatLng(decompressed['latitude']!, decompressed['longitude']!),
          altitude: decompressed['altitude'],
          accuracy: map['accuracy'],
          timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
          userId: map['user_id'],
          rescueId: map['rescue_id'],
        );
      }
      return null;
    } catch (e) {
      print('获取最后位置点失败: $e');
      return null;
    }
  }

  /// 更新轨迹摘要
  Future<void> _updateTrackSummary(LocationPoint point) async {
    try {
      final trackId = 'track_${point.userId}_${point.rescueId}';

      // 检查是否已存在
      final existing = await _database!.query(
        'track_summaries',
        where: 'id = ?',
        whereArgs: [trackId],
      );

      if (existing.isEmpty) {
        // 创建新的轨迹摘要
        await _database!.insert(
          'track_summaries',
          {
            'id': trackId,
            'user_id': point.userId,
            'user_name':
                '救援员${point.userId.substring(point.userId.length - 3)}',
            'rescue_id': point.rescueId,
            'color': _generateUserColor(point.userId),
            'start_time': point.timestamp.millisecondsSinceEpoch,
            'end_time': point.timestamp.millisecondsSinceEpoch,
            'total_distance': 0.0,
            'total_duration': 0,
            'point_count': 1,
            'is_synced': 0,
          },
        );
      } else {
        // 更新现有轨迹摘要
        final summary = existing.first;
        final pointCount = (summary['point_count'] as int) + 1;
        final startTime = summary['start_time'] as int;
        final duration = point.timestamp.millisecondsSinceEpoch - startTime;

        await _database!.update(
          'track_summaries',
          {
            'end_time': point.timestamp.millisecondsSinceEpoch,
            'total_duration': duration,
            'point_count': pointCount,
            'is_synced': 0,
          },
          where: 'id = ?',
          whereArgs: [trackId],
        );
      }
    } catch (e) {
      print('更新轨迹摘要失败: $e');
    }
  }

  /// 生成用户颜色
  int _generateUserColor(String userId) {
    final colors = [
      0xFFE57373, // 红色
      0xFF64B5F6, // 蓝色
      0xFF81C784, // 绿色
      0xFFFFB74D, // 橙色
      0xFFBA68C8, // 紫色
      0xFF4DB6AC, // 青色
      0xFFF06292, // 粉色
      0xFF9575CD, // 深紫色
      0xFF4FC3F7, // 浅蓝色
      0xFFAED581, // 浅绿色
    ];

    final hash = userId.hashCode;
    final index = hash.abs() % colors.length;
    return colors[index];
  }

  /// 获取压缩的位置点
  Future<List<LocationPoint>> getCompressedLocationPoints(
      String rescueId, String userId,
      {int? limit}) async {
    try {
      if (_database == null) await _initDatabase();

      final List<Map<String, dynamic>> maps = await _database!.query(
        'location_points_compressed',
        where: 'rescue_id = ? AND user_id = ?',
        whereArgs: [rescueId, userId],
        orderBy: 'timestamp ASC',
        limit: limit,
      );

      return maps.map((map) {
        final decompressed = _decompressLatLng(map['lat_lng_compressed']);
        return LocationPoint(
          position:
              LatLng(decompressed['latitude']!, decompressed['longitude']!),
          altitude: decompressed['altitude'],
          accuracy: map['accuracy'],
          timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
          userId: map['user_id'],
          rescueId: map['rescue_id'],
        );
      }).toList();
    } catch (e) {
      print('获取压缩位置点失败: $e');
      return [];
    }
  }

  /// 获取轨迹摘要
  Future<List<Map<String, dynamic>>> getTrackSummaries(String rescueId) async {
    try {
      if (_database == null) await _initDatabase();

      return await _database!.query(
        'track_summaries',
        where: 'rescue_id = ?',
        whereArgs: [rescueId],
        orderBy: 'start_time ASC',
      );
    } catch (e) {
      print('获取轨迹摘要失败: $e');
      return [];
    }
  }

  /// 清理旧数据
  Future<bool> cleanOldData() async {
    try {
      if (_database == null) await _initDatabase();

      final cutoff = DateTime.now().subtract(Duration(days: _maxStorageDays));
      final cutoffTimestamp = cutoff.millisecondsSinceEpoch;

      // 删除旧的位置点
      await _database!.delete(
        'location_points_compressed',
        where: 'timestamp < ? AND is_synced = 1',
        whereArgs: [cutoffTimestamp],
      );

      // 删除旧的轨迹摘要
      await _database!.delete(
        'track_summaries',
        where: 'start_time < ? AND is_synced = 1',
        whereArgs: [cutoffTimestamp],
      );

      return true;
    } catch (e) {
      print('清理旧数据失败: $e');
      return false;
    }
  }

  /// 获取存储统计信息
  Future<Map<String, int>> getStorageStats() async {
    try {
      if (_database == null) await _initDatabase();

      final pointCount = Sqflite.firstIntValue(await _database!
              .rawQuery('SELECT COUNT(*) FROM location_points_compressed')) ??
          0;

      final trackCount = Sqflite.firstIntValue(await _database!
              .rawQuery('SELECT COUNT(*) FROM track_summaries')) ??
          0;

      final rescueCount = Sqflite.firstIntValue(
              await _database!.rawQuery('SELECT COUNT(*) FROM rescues')) ??
          0;

      return {
        'points': pointCount,
        'tracks': trackCount,
        'rescues': rescueCount,
      };
    } catch (e) {
      print('获取存储统计失败: $e');
      return {};
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
