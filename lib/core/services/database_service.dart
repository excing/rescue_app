import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/rescue_model.dart';
import '../models/track_point_model.dart';

/// 数据库服务
///
/// 负责本地SQLite数据库的管理，包括救援数据、轨迹数据的存储和查询
/// 采用单例模式，确保数据库连接的唯一性和线程安全
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// 获取单例实例
  static DatabaseService get instance => _instance;

  /// 获取数据库实例
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  static Future<void> initDatabase() async {
    await _instance.database;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'rescue_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 创建救援表
    await db.execute('''
      CREATE TABLE rescues (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        synced INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 创建轨迹点表
    await db.execute('''
      CREATE TABLE track_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rescue_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        latitude INTEGER NOT NULL,
        longitude INTEGER NOT NULL,
        altitude INTEGER NOT NULL,
        accuracy INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        marked INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (rescue_id) REFERENCES rescues (id) ON DELETE CASCADE
      )
    ''');

    // 创建用户轨迹文档表（用于记录Firestore文档信息）
    await db.execute('''
      CREATE TABLE user_track_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rescue_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        document_index INTEGER NOT NULL DEFAULT 0,
        point_count INTEGER NOT NULL DEFAULT 0,
        last_sync_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(rescue_id, user_id, document_index),
        FOREIGN KEY (rescue_id) REFERENCES rescues (id) ON DELETE CASCADE
      )
    ''');

    // 创建索引
    await db.execute(
        'CREATE INDEX idx_track_points_rescue_user ON track_points (rescue_id, user_id)');
    await db.execute(
        'CREATE INDEX idx_track_points_timestamp ON track_points (timestamp)');
    await db.execute(
        'CREATE INDEX idx_user_track_documents_rescue_user ON user_track_documents (rescue_id, user_id)');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 暂时不需要升级逻辑
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // ==================== 救援数据操作 ====================

  /// 插入救援数据
  Future<void> insertRescue(RescueModel rescue) async {
    final db = await database;
    await db.insert(
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
        'synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取救援数据
  Future<RescueModel?> getRescue(String rescueId) async {
    final db = await database;
    final maps = await db.query(
      'rescues',
      where: 'id = ?',
      whereArgs: [rescueId],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return RescueModel(
      id: map['id'] as String,
      description: map['description'] as String,
      location: LocationCoordinate(
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
      ),
      altitude: map['altitude'] as double,
      createdAt: DateTime.parse(map['created_at'] as String),
      createdBy: map['created_by'] as String,
      isActive: (map['is_active'] as int) == 1,
    );
  }

  /// 获取所有救援数据
  Future<List<RescueModel>> getAllRescues() async {
    final db = await database;
    final maps = await db.query(
      'rescues',
      orderBy: 'created_at DESC',
    );

    return maps
        .map((map) => RescueModel(
              id: map['id'] as String,
              description: map['description'] as String,
              location: LocationCoordinate(
                latitude: map['latitude'] as double,
                longitude: map['longitude'] as double,
              ),
              altitude: map['altitude'] as double,
              createdAt: DateTime.parse(map['created_at'] as String),
              createdBy: map['created_by'] as String,
              isActive: (map['is_active'] as int) == 1,
            ))
        .toList();
  }

  /// 删除救援数据
  Future<void> deleteRescue(String rescueId) async {
    final db = await database;
    await db.delete(
      'rescues',
      where: 'id = ?',
      whereArgs: [rescueId],
    );
  }

  /// 标记救援为已同步
  Future<void> markRescueSynced(String rescueId) async {
    final db = await database;
    await db.update(
      'rescues',
      {
        'synced': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [rescueId],
    );
  }

  // ==================== 轨迹点数据操作 ====================

  /// 插入轨迹点
  Future<void> insertTrackPoint(
      String rescueId, String userId, TrackPointModel point) async {
    final db = await database;
    await db.insert(
      'track_points',
      {
        'rescue_id': rescueId,
        'user_id': userId,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'altitude': point.altitude,
        'accuracy': point.accuracy,
        'timestamp': point.timestamp,
        'marked': point.marked ? 1 : 0,
        'synced': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// 批量插入轨迹点
  Future<void> insertTrackPoints(
      String rescueId, String userId, List<TrackPointModel> points) async {
    final db = await database;
    final batch = db.batch();

    for (final point in points) {
      batch.insert(
        'track_points',
        {
          'rescue_id': rescueId,
          'user_id': userId,
          'latitude': point.latitude,
          'longitude': point.longitude,
          'altitude': point.altitude,
          'accuracy': point.accuracy,
          'timestamp': point.timestamp,
          'marked': point.marked ? 1 : 0,
          'synced': 0,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    }

    await batch.commit(noResult: true);
  }

  /// 获取用户在指定救援中的轨迹点
  Future<List<TrackPointModel>> getUserTrackPoints(
      String rescueId, String userId) async {
    final db = await database;
    final maps = await db.query(
      'track_points',
      where: 'rescue_id = ? AND user_id = ?',
      whereArgs: [rescueId, userId],
      orderBy: 'timestamp ASC',
    );

    return maps
        .map((map) => TrackPointModel(
              latitude: map['latitude'] as int,
              longitude: map['longitude'] as int,
              altitude: map['altitude'] as int,
              accuracy: map['accuracy'] as int,
              timestamp: map['timestamp'] as int,
              marked: (map['marked'] as int) == 1,
            ))
        .toList();
  }

  /// 获取救援中所有用户的轨迹点
  Future<Map<String, List<TrackPointModel>>> getAllTrackPoints(
      String rescueId) async {
    final db = await database;
    final maps = await db.query(
      'track_points',
      where: 'rescue_id = ?',
      whereArgs: [rescueId],
      orderBy: 'user_id ASC, timestamp ASC',
    );

    final result = <String, List<TrackPointModel>>{};
    for (final map in maps) {
      final userId = map['user_id'] as String;
      final point = TrackPointModel(
        latitude: map['latitude'] as int,
        longitude: map['longitude'] as int,
        altitude: map['altitude'] as int,
        accuracy: map['accuracy'] as int,
        timestamp: map['timestamp'] as int,
        marked: (map['marked'] as int) == 1,
      );

      result.putIfAbsent(userId, () => []).add(point);
    }

    return result;
  }

  /// 更新轨迹点标记状态
  Future<void> updateTrackPointMarked(
      String rescueId, String userId, int timestamp, bool marked) async {
    final db = await database;
    await db.update(
      'track_points',
      {
        'marked': marked ? 1 : 0,
        'synced': 0,
      },
      where: 'rescue_id = ? AND user_id = ? AND timestamp = ?',
      whereArgs: [rescueId, userId, timestamp],
    );
  }

  /// 删除用户轨迹点
  Future<void> deleteUserTrackPoints(String rescueId, String userId) async {
    final db = await database;
    await db.delete(
      'track_points',
      where: 'rescue_id = ? AND user_id = ?',
      whereArgs: [rescueId, userId],
    );
  }

  /// 标记轨迹点为已同步
  Future<void> markTrackPointsSynced(String rescueId, String userId) async {
    final db = await database;
    await db.update(
      'track_points',
      {'synced': 1},
      where: 'rescue_id = ? AND user_id = ?',
      whereArgs: [rescueId, userId],
    );
  }

  /// 获取未同步的轨迹点数量
  Future<int> getUnsyncedTrackPointsCount(
      String rescueId, String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM track_points WHERE rescue_id = ? AND user_id = ? AND synced = 0',
      [rescueId, userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
