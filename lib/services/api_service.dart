import 'dart:convert';
import 'package:http/http.dart' as http;
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
      final response = await http.get(
        Uri.parse('$baseUrl$documentsEndpoint?collection=rescue_$rescueId&document=rescue_info'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final rescueData = data['data']['data']['rescue_info'];
          return Rescue.fromJson(rescueData);
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

  /// 上传轨迹数据
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

  /// 上传位置点（批量）
  static Future<bool> uploadLocationPoints(String rescueId, String userId, List<LocationPoint> points) async {
    if (points.isEmpty) return true;

    try {
      // 将位置点按时间分组，避免单个文档过大
      final batches = _batchLocationPoints(points, 100); // 每批100个点
      
      for (int i = 0; i < batches.length; i++) {
        final batch = batches[i];
        final batchId = '${DateTime.now().millisecondsSinceEpoch}_$i';
        
        final response = await http.post(
          Uri.parse('$baseUrl$documentsEndpoint'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'collection': 'rescue_$rescueId',
            'documentId': 'points_${userId}_$batchId',
            'data': {
              'points': batch.map((p) => p.toJson()).toList(),
              'userId': userId,
              'type': 'location_points',
              'batchId': batchId,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          }),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          print('上传位置点批次 $i 失败');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('上传位置点失败: $e');
      return false;
    }
  }

  /// 获取救援中的所有轨迹
  static Future<List<Track>> getRescueTracks(String rescueId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$documentsEndpoint?collection=rescue_$rescueId&limit=100'),
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

  /// 获取用户的位置点
  static Future<List<LocationPoint>> getUserLocationPoints(String rescueId, String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$documentsEndpoint?collection=rescue_$rescueId&limit=100'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final documents = data['data']['documents'] as List<dynamic>;
          final allPoints = <LocationPoint>[];
          
          for (final doc in documents) {
            final docData = doc['data'];
            if (docData['type'] == 'location_points' && docData['userId'] == userId) {
              try {
                final points = docData['points'] as List<dynamic>;
                for (final pointData in points) {
                  final point = LocationPoint.fromJson(pointData);
                  allPoints.add(point);
                }
              } catch (e) {
                print('解析位置点数据失败: $e');
              }
            }
          }
          
          // 按时间排序
          allPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return allPoints;
        }
      }
      return [];
    } catch (e) {
      print('获取用户位置点失败: $e');
      return [];
    }
  }

  /// 将位置点分批
  static List<List<LocationPoint>> _batchLocationPoints(List<LocationPoint> points, int batchSize) {
    final batches = <List<LocationPoint>>[];
    for (int i = 0; i < points.length; i += batchSize) {
      final end = (i + batchSize < points.length) ? i + batchSize : points.length;
      batches.add(points.sublist(i, end));
    }
    return batches;
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
