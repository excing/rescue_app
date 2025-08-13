import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../core/services/background_location_service.dart';

/// 后台服务测试页面
/// 
/// 用于测试后台位置服务的功能
/// 包含启动、停止、状态检查等功能
class TestBackgroundPage extends StatefulWidget {
  const TestBackgroundPage({super.key});

  @override
  State<TestBackgroundPage> createState() => _TestBackgroundPageState();
}

class _TestBackgroundPageState extends State<TestBackgroundPage> {
  bool _isTracking = false;
  bool _isServiceRunning = false;
  String _lastLocationUpdate = '暂无位置更新';
  
  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _listenToLocationUpdates();
  }

  /// 检查服务状态
  Future<void> _checkServiceStatus() async {
    final isTracking = await BackgroundLocationService.isTracking();
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    setState(() {
      _isTracking = isTracking;
      _isServiceRunning = isRunning;
    });
  }

  /// 监听位置更新
  void _listenToLocationUpdates() {
    final service = FlutterBackgroundService();
    service.on('location_update').listen((event) {
      if (event != null) {
        final data = event;
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final timestamp = data['timestamp'] as int?;
        
        if (lat != null && lng != null && timestamp != null) {
          final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
          setState(() {
            _lastLocationUpdate = '位置: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}\n时间: ${time.toString()}';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('后台服务测试'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 服务状态卡片
            _buildStatusCard(),
            
            const SizedBox(height: 16),
            
            // 位置更新卡片
            _buildLocationCard(),
            
            const SizedBox(height: 24),
            
            // 控制按钮
            _buildControlButtons(),
            
            const SizedBox(height: 16),
            
            // 刷新按钮
            ElevatedButton.icon(
              onPressed: _checkServiceStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新状态'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建状态卡片
  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '服务状态',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _isServiceRunning ? Icons.check_circle : Icons.cancel,
                  color: _isServiceRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text('后台服务: ${_isServiceRunning ? "运行中" : "已停止"}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isTracking ? Icons.location_on : Icons.location_off,
                  color: _isTracking ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text('位置追踪: ${_isTracking ? "进行中" : "已停止"}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建位置卡片
  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最新位置更新',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _lastLocationUpdate,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建控制按钮
  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isTracking ? null : _startTracking,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始追踪'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isTracking ? _stopTracking : null,
            icon: const Icon(Icons.stop),
            label: const Text('停止追踪'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// 开始追踪
  Future<void> _startTracking() async {
    try {
      // 使用测试数据
      const testRescueId = '1234';
      const testUserId = 'test_user_001';
      
      final success = await BackgroundLocationService.startTracking(testRescueId, testUserId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('后台位置追踪已启动'),
            backgroundColor: Colors.green,
          ),
        );
        await _checkServiceStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('启动后台位置追踪失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('启动失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 停止追踪
  Future<void> _stopTracking() async {
    try {
      await BackgroundLocationService.stopTracking();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('后台位置追踪已停止'),
          backgroundColor: Colors.orange,
        ),
      );
      
      await _checkServiceStatus();
      
      setState(() {
        _lastLocationUpdate = '暂无位置更新';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('停止失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
