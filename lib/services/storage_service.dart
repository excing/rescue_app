import 'dart:convert';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rescue.dart';
import '../models/location_point.dart';
import '../models/track.dart';
import '../models/user.dart';

/// 本地存储服务类，负责离线数据存储和同步
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Database? _database;
  SharedPreferences? _prefs;

  /// 初始化存储服务
  Future<bool> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _initDatabase();
      return true;
    } catch (e) {
      print('初始化存储服务失败: $e');
      return false;
    }
  }

  /// 初始化数据库
  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'rescue_app.db');

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
        created_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 位置点表
    await db.execute('''
      CREATE TABLE location_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rescue_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        accuracy REAL,
        speed REAL,
        heading REAL,
        timestamp TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (rescue_id) REFERENCES rescues (id)
      )
    ''');

    // 轨迹表
    await db.execute('''
      CREATE TABLE tracks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        rescue_id TEXT NOT NULL,
        color INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        total_distance REAL,
        total_duration INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (rescue_id) REFERENCES rescues (id)
      )
    ''');

    // 用户表
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        track_color INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        last_active_at TEXT,
        is_online INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_location_points_rescue_user ON location_points(rescue_id, user_id)');
    await db.execute('CREATE INDEX idx_location_points_timestamp ON location_points(timestamp)');
    await db.execute('CREATE INDEX idx_tracks_rescue ON tracks(rescue_id)');
  }

  /// 保存救援信息
  Future<bool> saveRescue(Rescue rescue) async {
    try {
      if (_database == null) await _initDatabase();
      
      await _database!.insert(
        'rescues',
        {
          'id': rescue.id,
          'description': rescue.description,
          'latitude': rescue.location.latitude,
          'longitude': rescue.location.longitude,
          'altitude': rescue.altitude,
          'created_at': rescue.createdAt.toIso8601String(),
          'created_by': rescue.createdBy,
          'is_active': rescue.isActive ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return true;
    } catch (e) {
      print('保存救援信息失败: $e');
      return false;
    }
  }

  /// 获取救援信息
  Future<Rescue?> getRescue(String rescueId) async {
    try {
      if (_database == null) await _initDatabase();
      
      final List<Map<String, dynamic>> maps = await _database!.query(
        'rescues',
        where: 'id = ?',
        whereArgs: [rescueId],
      );

      if (maps.isNotEmpty) {
        final map = maps.first;
        return Rescue.fromJson({
          'id': map['id'],
          'description': map['description'],
          'location': {
            'latitude': map['latitude'],
            'longitude': map['longitude'],
          },
          'altitude': map['altitude'],
          'createdAt': map['created_at'],
          'createdBy': map['created_by'],
          'isActive': map['is_active'] == 1,
        });
      }
      
      return null;
    } catch (e) {
      print('获取救援信息失败: $e');
      return null;
    }
  }

  /// 保存位置点
  Future<bool> saveLocationPoint(LocationPoint point) async {
    try {
      if (_database == null) await _initDatabase();
      
      await _database!.insert(
        'location_points',
        {
          'rescue_id': point.rescueId,
          'user_id': point.userId,
          'latitude': point.position.latitude,
          'longitude': point.position.longitude,
          'altitude': point.altitude,
          'accuracy': point.accuracy,
          'speed': point.speed,
          'heading': point.heading,
          'timestamp': point.timestamp.toIso8601String(),
          'is_synced': 0,
        },
      );
      
      return true;
    } catch (e) {
      print('保存位置点失败: $e');
      return false;
    }
  }

  /// 批量保存位置点
  Future<bool> saveLocationPoints(List<LocationPoint> points) async {
    try {
      if (_database == null) await _initDatabase();
      
      final batch = _database!.batch();
      for (final point in points) {
        batch.insert(
          'location_points',
          {
            'rescue_id': point.rescueId,
            'user_id': point.userId,
            'latitude': point.position.latitude,
            'longitude': point.position.longitude,
            'altitude': point.altitude,
            'accuracy': point.accuracy,
            'speed': point.speed,
            'heading': point.heading,
            'timestamp': point.timestamp.toIso8601String(),
            'is_synced': 0,
          },
        );
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      print('批量保存位置点失败: $e');
      return false;
    }
  }

  /// 获取未同步的位置点
  Future<List<LocationPoint>> getUnsyncedLocationPoints(String rescueId, String userId) async {
    try {
      if (_database == null) await _initDatabase();
      
      final List<Map<String, dynamic>> maps = await _database!.query(
        'location_points',
        where: 'rescue_id = ? AND user_id = ? AND is_synced = 0',
        whereArgs: [rescueId, userId],
        orderBy: 'timestamp ASC',
      );

      return maps.map((map) => LocationPoint.fromJson({
        'position': {
          'latitude': map['latitude'],
          'longitude': map['longitude'],
        },
        'altitude': map['altitude'],
        'accuracy': map['accuracy'],
        'speed': map['speed'],
        'heading': map['heading'],
        'timestamp': map['timestamp'],
        'userId': map['user_id'],
        'rescueId': map['rescue_id'],
      })).toList();
    } catch (e) {
      print('获取未同步位置点失败: $e');
      return [];
    }
  }

  /// 标记位置点为已同步
  Future<bool> markLocationPointsSynced(String rescueId, String userId, DateTime fromTime, DateTime toTime) async {
    try {
      if (_database == null) await _initDatabase();
      
      await _database!.update(
        'location_points',
        {'is_synced': 1},
        where: 'rescue_id = ? AND user_id = ? AND timestamp >= ? AND timestamp <= ?',
        whereArgs: [
          rescueId,
          userId,
          fromTime.toIso8601String(),
          toTime.toIso8601String(),
        ],
      );
      
      return true;
    } catch (e) {
      print('标记位置点已同步失败: $e');
      return false;
    }
  }

  /// 保存轨迹
  Future<bool> saveTrack(Track track) async {
    try {
      if (_database == null) await _initDatabase();
      
      await _database!.insert(
        'tracks',
        {
          'id': track.id,
          'user_id': track.userId,
          'user_name': track.userName,
          'rescue_id': track.rescueId,
          'color': track.color.value,
          'start_time': track.startTime.toIso8601String(),
          'end_time': track.endTime?.toIso8601String(),
          'is_active': track.isActive ? 1 : 0,
          'total_distance': track.totalDistance,
          'total_duration': track.totalDuration?.inMilliseconds,
          'is_synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return true;
    } catch (e) {
      print('保存轨迹失败: $e');
      return false;
    }
  }

  /// 获取救援的所有轨迹
  Future<List<Track>> getRescueTracks(String rescueId) async {
    try {
      if (_database == null) await _initDatabase();
      
      final List<Map<String, dynamic>> maps = await _database!.query(
        'tracks',
        where: 'rescue_id = ?',
        whereArgs: [rescueId],
        orderBy: 'start_time ASC',
      );

      final tracks = <Track>[];
      for (final map in maps) {
        // 获取轨迹的位置点
        final points = await getUserLocationPoints(rescueId, map['user_id']);
        
        tracks.add(Track.fromJson({
          'id': map['id'],
          'userId': map['user_id'],
          'userName': map['user_name'],
          'rescueId': map['rescue_id'],
          'points': points.map((p) => p.toJson()).toList(),
          'color': map['color'],
          'startTime': map['start_time'],
          'endTime': map['end_time'],
          'isActive': map['is_active'] == 1,
          'totalDistance': map['total_distance'],
          'totalDuration': map['total_duration'],
        }));
      }
      
      return tracks;
    } catch (e) {
      print('获取救援轨迹失败: $e');
      return [];
    }
  }

  /// 获取用户的位置点
  Future<List<LocationPoint>> getUserLocationPoints(String rescueId, String userId) async {
    try {
      if (_database == null) await _initDatabase();
      
      final List<Map<String, dynamic>> maps = await _database!.query(
        'location_points',
        where: 'rescue_id = ? AND user_id = ?',
        whereArgs: [rescueId, userId],
        orderBy: 'timestamp ASC',
      );

      return maps.map((map) => LocationPoint.fromJson({
        'position': {
          'latitude': map['latitude'],
          'longitude': map['longitude'],
        },
        'altitude': map['altitude'],
        'accuracy': map['accuracy'],
        'speed': map['speed'],
        'heading': map['heading'],
        'timestamp': map['timestamp'],
        'userId': map['user_id'],
        'rescueId': map['rescue_id'],
      })).toList();
    } catch (e) {
      print('获取用户位置点失败: $e');
      return [];
    }
  }

  /// 保存用户偏好设置
  Future<bool> saveUserPreference(String key, String value) async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      return await _prefs!.setString(key, value);
    } catch (e) {
      print('保存用户偏好失败: $e');
      return false;
    }
  }

  /// 获取用户偏好设置
  Future<String?> getUserPreference(String key) async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      return _prefs!.getString(key);
    } catch (e) {
      print('获取用户偏好失败: $e');
      return null;
    }
  }

  /// 清理旧数据
  Future<bool> cleanOldData(Duration maxAge) async {
    try {
      if (_database == null) await _initDatabase();
      
      final cutoff = DateTime.now().subtract(maxAge);
      
      // 删除旧的位置点
      await _database!.delete(
        'location_points',
        where: 'timestamp < ? AND is_synced = 1',
        whereArgs: [cutoff.toIso8601String()],
      );
      
      return true;
    } catch (e) {
      print('清理旧数据失败: $e');
      return false;
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
