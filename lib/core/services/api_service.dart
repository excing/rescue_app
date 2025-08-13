import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/rescue_model.dart';
import '../models/user_track_model.dart';

/// API服务
///
/// 负责与后端Firestore API的交互，包括救援数据和轨迹数据的同步
/// 使用Dio进行HTTP请求，提供统一的错误处理和重试机制
class ApiService {
  static final ApiService _instance = ApiService._internal();
  late final Dio _dio;

  factory ApiService() => _instance;
  ApiService._internal() {
    _initDio();
  }

  /// 获取单例实例
  static ApiService get instance => _instance;

  /// 初始化Dio
  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://tools.blendiv.com/api/firestore',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 添加拦截器
    _dio.interceptors.add(LogInterceptor(
      requestBody: kDebugMode,
      responseBody: kDebugMode,
      logPrint: (obj) => debugPrint(obj.toString()),
    ));

    // 添加重试拦截器
    _dio.interceptors.add(RetryInterceptor());
  }

  // ==================== 救援数据API ====================

  /// 创建救援
  Future<ApiResponse<String>> createRescue(RescueModel rescue) async {
    try {
      final response = await _dio.post(
        '/collections',
        data: {
          'collectionName': 'rescue-${rescue.id}',
          'documentId': 'rescue-info',
          'documentData': rescue.toJson(),
        },
      );

      if (response.data['success'] == true) {
        return ApiResponse.success(rescue.id);
      } else {
        return ApiResponse.error(response.data['error'] ?? '创建救援失败');
      }
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// 获取救援信息
  Future<ApiResponse<RescueModel>> getRescue(String rescueId) async {
    try {
      final response = await _dio.get(
        '/documents',
        queryParameters: {
          'collection': 'rescue-$rescueId',
          'document': 'rescue-info',
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data']['data'] as Map<String, dynamic>;
        final rescue = RescueModel.fromJson(data);
        return ApiResponse.success(rescue);
      } else {
        return ApiResponse.error(response.data['error'] ?? '获取救援信息失败');
      }
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// 检查救援是否存在
  Future<ApiResponse<bool>> checkRescueExists(String rescueId) async {
    final result = await getRescue(rescueId);
    return ApiResponse.success(result.isSuccess);
  }

  // ==================== 轨迹数据API ====================

  /// 上传用户轨迹数据
  Future<ApiResponse<String>> uploadUserTrack(
      String rescueId, UserTrackModel userTrack) async {
    try {
      final response = await _dio.post(
        '/documents',
        data: {
          'collection': 'rescue-$rescueId',
          'documentId': userTrack.documentId,
          'data': userTrack.toJson(),
          'merge': true,
        },
      );

      if (response.data['success'] == true) {
        return ApiResponse.success(userTrack.documentId);
      } else {
        return ApiResponse.error(response.data['error'] ?? '上传轨迹数据失败');
      }
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// 获取救援中所有用户的轨迹数据
  Future<ApiResponse<List<UserTrackModel>>> getAllUserTracks(
      String rescueId) async {
    try {
      final response = await _dio.get(
        '/documents',
        queryParameters: {
          'collection': 'rescue-$rescueId',
          'limit': 100,
          'orderBy': 'updatedAt',
          'orderDirection': 'desc',
        },
      );

      if (response.data['success'] == true) {
        final documents = response.data['data']['documents'] as List<dynamic>;
        final userTracks = <UserTrackModel>[];

        for (final doc in documents) {
          final docId = doc['id'] as String;
          final docData = doc['data'] as Map<String, dynamic>;

          // 跳过救援信息文档
          if (docId == 'rescue-info') continue;

          // 解析用户轨迹文档
          if (docId.startsWith('user-')) {
            try {
              final userTrack = UserTrackModel.fromJson(docData);
              userTracks.add(userTrack);
            } catch (e) {
              debugPrint('解析用户轨迹数据失败: $docId, error: $e');
            }
          }
        }

        return ApiResponse.success(userTracks);
      } else {
        return ApiResponse.error(response.data['error'] ?? '获取轨迹数据失败');
      }
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// 获取指定用户的轨迹数据
  Future<ApiResponse<List<UserTrackModel>>> getUserTracks(
      String rescueId, String userId) async {
    try {
      final userTracks = <UserTrackModel>[];
      int index = 0;

      // 获取用户的所有轨迹文档（可能有多个分片）
      while (true) {
        final documentId = index == 0 ? 'user-$userId' : 'user-$userId-$index';

        final response = await _dio.get(
          '/documents',
          queryParameters: {
            'collection': 'rescue-$rescueId',
            'document': documentId,
          },
        );

        if (response.data['success'] == true) {
          final docData = response.data['data']['data'] as Map<String, dynamic>;
          final userTrack = UserTrackModel.fromJson(docData);
          userTracks.add(userTrack);
          index++;
        } else {
          // 没有更多文档了
          break;
        }
      }

      return ApiResponse.success(userTracks);
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// 删除用户轨迹数据
  Future<ApiResponse<bool>> deleteUserTracks(
      String rescueId, String userId) async {
    try {
      bool hasError = false;
      int index = 0;

      // 删除用户的所有轨迹文档
      while (true) {
        final documentId = index == 0 ? 'user-$userId' : 'user-$userId-$index';

        final response = await _dio.delete(
          '/documents',
          data: {
            'collection': 'rescue-$rescueId',
            'documentId': documentId,
          },
        );

        if (response.data['success'] == true) {
          index++;
        } else {
          // 没有更多文档了
          break;
        }
      }

      return ApiResponse.success(!hasError);
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  // ==================== 工具方法 ====================

  /// 处理错误
  String _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '网络连接超时，请检查网络连接';
        case DioExceptionType.badResponse:
          return '服务器响应错误: ${error.response?.statusCode}';
        case DioExceptionType.cancel:
          return '请求已取消';
        case DioExceptionType.connectionError:
          return '网络连接失败，请检查网络连接';
        default:
          return '网络请求失败: ${error.message}';
      }
    }
    return error.toString();
  }
}

/// API响应封装类
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  const ApiResponse._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse._(isSuccess: true, data: data);
  }

  factory ApiResponse.error(String error) {
    return ApiResponse._(isSuccess: false, error: error);
  }

  @override
  String toString() {
    return 'ApiResponse(isSuccess: $isSuccess, data: $data, error: $error)';
  }
}

/// 重试拦截器
class RetryInterceptor extends Interceptor {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err) && err.requestOptions.extra['retryCount'] == null) {
      err.requestOptions.extra['retryCount'] = 0;
    }

    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

    if (retryCount < maxRetries && _shouldRetry(err)) {
      err.requestOptions.extra['retryCount'] = retryCount + 1;

      await Future.delayed(retryDelay * (retryCount + 1));

      try {
        final response = await Dio().fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        // 继续重试或返回错误
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.type == DioExceptionType.badResponse &&
            err.response?.statusCode != null &&
            err.response!.statusCode! >= 500);
  }
}
