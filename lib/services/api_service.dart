import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/rescue.dart';
import '../models/track.dart';
import '../models/location_point.dart';

/// API服务类，负责与后端Firestore代理服务通信
class ApiService {
  static const String baseUrl = 'https://tools.blendiv.com';
  static const String collectionsEndpoint = '/api/firestore/collections';
  static const String documentsEndpoint = '/api/firestore/documents';

  /// 创建救援
  static Future<bool> createRescue(Rescue rescue) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$collectionsEndpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'collectionName': 'rescue_${rescue.id}',
          'documentData': {
            'rescue_info': rescue.toJson(),
            'type': 'rescue_info',
          },
          'documentId': 'rescue_info',
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('创建救援失败: $e');
      return false;
    }
  }

  /// 获取救援信息
  static Future<Rescue?> getRescue(String rescueId) async {
    try {
      final url = Uri.parse(
          '$baseUrl$documentsEndpoint?collection=rescue_$rescueId&document=rescue_info');
      print('获取救援信息URL: $url');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['success'];
        final info = data['data']['data']['rescue_info'];
        print("获取救援信息响应, $success, $info");
        if (success == true && info != null) {
          return Rescue.fromJson(info);
        }
      }
      return null;
    } catch (e) {
      print('获取救援信息失败: $e');
      return null;
    }
  }

  /// 检查救援是否存在
  static Future<bool> rescueExists(String rescueId) async {
    final rescue = await getRescue(rescueId);
    return rescue != null;
  }

  /// 上传轨迹数据（保留，用于摘要/兼容）
  static Future<bool> uploadTrack(Track track) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$documentsEndpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'collection': 'rescue_${track.rescueId}',
          'documentId': 'track_${track.userId}',
          'data': {
            'track': track.toJson(),
            'type': 'track',
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          'merge': true,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('上传轨迹失败: $e');
      return false;
    }
  }

  /// 根据新规范上传用户位置点：
  /// - 文档名：user-<userId>-<index>
  /// - 文档结构：{ user_id: string, points: ["lat,lng,alt,acc,marked,timestamp"] }
  /// - 单文档最大约1MB，保守使用 ~900KB
  static Future<bool> uploadUserPointsCompact(
    String rescueId,
    String userId,
    List<LocationPoint> points,
  ) async {
    if (points.isEmpty) return true;

    // 先获取该用户已存在的文档索引，确定起始index
    final existingIndexes = await _getUserDocIndexes(rescueId, userId);
    int index = existingIndexes.isEmpty
        ? 0
        : (existingIndexes.reduce((a, b) => a > b ? a : b) + 1);

    // 将points转为CSV字符串
    final csvList = points.map((p) => p.toCompactCSV()).toList();

    // 组包至~900KB
    const int maxBytes = 900 * 1024; // 900KB安全阈值
    List<String> current = [];
    int currentSize = 0; // 估算JSON字符串长度

    Future<bool> flush() async {
      if (current.isEmpty) return true;
      final docId = 'user-$userId-$index';
      final payload = {
        'collection': 'rescue_$rescueId',
        'documentId': docId,
        'data': {
          'user_id': userId,
          'points': current,
        },
      };
      final resp = await http.post(
        Uri.parse('$baseUrl$documentsEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        index += 1;
        current.clear();
        currentSize = 0;
        return true;
      }
      print('上传文档 $docId 失败: ${resp.statusCode} ${resp.body}');
      return false;
    }

    for (final csv in csvList) {
      // 估算增加的长度：字符串本身+引号+逗号
      final add = csv.length + 3;
      if (currentSize + add > maxBytes) {
        final ok = await flush();
        if (!ok) return false;
      }
      current.add(csv);
      currentSize += add;
    }
    // 刷新最后一个
    final ok = await flush();
    return ok;
  }

  /// 下载该救援下所有用户的紧凑轨迹文档，返回 userId -> csv列表 映射
  static Future<Map<String, List<String>>> getAllUsersCompactCSV(
      String rescueId) async {
    final result = <String, List<String>>{};
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl$documentsEndpoint?collection=rescue_$rescueId&limit=10000'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) return result;
      final data = jsonDecode(response.body);
      if (data['success'] != true || data['data'] == null) return result;
      final documents = data['data']['documents'] as List<dynamic>? ?? [];
      for (final doc in documents) {
        final id = (doc['id'] ?? doc['name'] ?? '').toString();
        if (!id.contains('user-')) continue;
        final docData = doc['data'];
        final uid = docData['user_id']?.toString();
        final points = (docData['points'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (uid == null) continue;
        result.putIfAbsent(uid, () => []).addAll(points);
      }
    } catch (e) {
      print('获取所有用户紧凑轨迹失败: $e');
    }
    return result;
  }

  /// 将紧凑CSV组装为Track列表（每用户一条）
  static Future<List<Track>> getRescueTracksFromCompact(String rescueId) async {
    final byUser = await getAllUsersCompactCSV(rescueId);
    final tracks = <Track>[];
    byUser.forEach((userId, csvs) {
      // 解析并排序
      final points = <LocationPoint>[];
      for (final csv in csvs) {
        try {
          final p = LocationPoint.fromCompactCSV(csv,
              userId: userId, rescueId: rescueId);
          points.add(p);
        } catch (_) {}
      }
      points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (points.isEmpty) return;
      tracks.add(Track(
        id: 'track_$userId',
        userId: userId,
        userName: '救援员${userId.substring(userId.length - 3)}',
        rescueId: rescueId,
        points: points,
        color: const Color(0xFF64B5F6),
        startTime: points.first.timestamp,
        endTime: points.last.timestamp,
        isActive: true,
      ));
    });
    return tracks;
  }

  /// 获取救援中的所有轨迹（旧track文档）
  static Future<List<Track>> getRescueTracks(String rescueId) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl$documentsEndpoint?collection=rescue_$rescueId&limit=100'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final documents = data['data']['documents'] as List<dynamic>;
          final tracks = <Track>[];

          for (final doc in documents) {
            final docData = doc['data'];
            if (docData['type'] == 'track') {
              try {
                final track = Track.fromJson(docData['track']);
                tracks.add(track);
              } catch (e) {
                print('解析轨迹数据失败: $e');
              }
            }
          }

          return tracks;
        }
      }
      return [];
    } catch (e) {
      print('获取救援轨迹失败: $e');
      return [];
    }
  }

  /// 辅助：获取该用户已存在的文档索引集合
  static Future<List<int>> _getUserDocIndexes(
      String rescueId, String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl$documentsEndpoint?collection=rescue_$rescueId&limit=10000'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data['success'] != true || data['data'] == null) return [];
      final documents = data['data']['documents'] as List<dynamic>? ?? [];
      final indexes = <int>[];
      for (final doc in documents) {
        final id = (doc['id'] ?? doc['name'] ?? '').toString();
        final prefix = 'user-$userId-';
        if (id.contains(prefix)) {
          final tail = id.substring(id.indexOf(prefix) + prefix.length);
          final idx = int.tryParse(tail);
          if (idx != null) indexes.add(idx);
        }
      }
      return indexes;
    } catch (e) {
      print('获取用户文档索引失败: $e');
      return [];
    }
  }

  /// 删除救援
  static Future<bool> deleteRescue(String rescueId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$collectionsEndpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'collectionName': 'rescue_$rescueId',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('删除救援失败: $e');
      return false;
    }
  }
}
