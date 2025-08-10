import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../models/rescue.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import 'rescue_screen.dart';

/// 创建救援页面
class CreateRescueScreen extends StatefulWidget {
  const CreateRescueScreen({super.key});

  @override
  State<CreateRescueScreen> createState() => _CreateRescueScreenState();
}

class _CreateRescueScreenState extends State<CreateRescueScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final LocationService _locationService = LocationService();
  
  String _rescueId = '';
  LatLng? _selectedLocation;
  double? _selectedAltitude;
  bool _isLoading = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _generateRescueId();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// 生成4位数字救援号
  void _generateRescueId() {
    final random = Random();
    _rescueId = (1000 + random.nextInt(9000)).toString();
  }

  /// 获取当前位置
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final initialized = await _locationService.initialize();
      if (!initialized) {
        _showToast('无法获取位置权限');
        return;
      }

      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _selectedAltitude = position.altitude;
        });
      } else {
        _showToast('无法获取当前位置');
      }
    } catch (e) {
      _showToast('获取位置失败: $e');
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  /// 创建救援
  Future<void> _createRescue() async {
    final description = _descriptionController.text.trim();
    
    if (description.isEmpty) {
      _showToast('请输入救援描述');
      return;
    }

    if (_selectedLocation == null) {
      _showToast('请先获取位置信息');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 检查救援号是否已存在
      final exists = await ApiService.rescueExists(_rescueId);
      if (exists) {
        // 重新生成救援号
        _generateRescueId();
        _showToast('救援号已存在，已重新生成');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 创建救援对象
      final rescue = Rescue(
        id: _rescueId,
        description: description,
        location: _selectedLocation!,
        altitude: _selectedAltitude,
        createdAt: DateTime.now(),
        createdBy: 'user_${DateTime.now().millisecondsSinceEpoch}', // 临时用户ID
        isActive: true,
      );

      // 保存到本地
      await StorageService().saveRescue(rescue);

      // 上传到服务器
      final success = await ApiService.createRescue(rescue);
      
      if (success) {
        _showToast('救援创建成功');
        
        // 保存最近使用的救援号
        await StorageService().saveUserPreference('last_rescue_id', _rescueId);
        
        // 进入救援页面
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RescueScreen(rescueId: _rescueId),
            ),
          );
        }
      } else {
        _showToast('创建救援失败，请重试');
      }
    } catch (e) {
      _showToast('网络错误，请检查网络连接');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建救援'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange[600]!,
              Colors.orange[50]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 救援号显示
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.confirmation_number,
                            color: Colors.orange[600],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '救援号',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              _generateRescueId();
                              setState(() {});
                            },
                            icon: Icon(
                              Icons.refresh,
                              color: Colors.orange[600],
                            ),
                            tooltip: '重新生成',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange[200]!,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _rescueId,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                                letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _rescueId));
                                _showToast('救援号已复制');
                              },
                              icon: Icon(
                                Icons.copy,
                                color: Colors.orange[600],
                              ),
                              tooltip: '复制救援号',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 救援描述输入
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            color: Colors.blue[600],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '救援描述',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: InputDecoration(
                          hintText: '请描述救援任务的详细信息...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.blue[600]!,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 位置信息
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.green[600],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '救援位置',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const Spacer(),
                          if (_isGettingLocation)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              onPressed: _getCurrentLocation,
                              icon: Icon(
                                Icons.my_location,
                                color: Colors.green[600],
                              ),
                              tooltip: '重新获取位置',
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_selectedLocation != null) ...[
                        _buildLocationInfo('纬度', _selectedLocation!.latitude.toStringAsFixed(6)),
                        const SizedBox(height: 8),
                        _buildLocationInfo('经度', _selectedLocation!.longitude.toStringAsFixed(6)),
                        if (_selectedAltitude != null) ...[
                          const SizedBox(height: 8),
                          _buildLocationInfo('海拔', '${_selectedAltitude!.toStringAsFixed(1)}m'),
                        ],
                      ] else
                        Text(
                          '正在获取位置信息...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // 创建按钮
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _selectedLocation == null) ? null : _createRescue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '创建救援',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInfo(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
