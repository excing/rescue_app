import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/providers/rescue_provider.dart';
import '../../core/providers/location_provider.dart';
import '../widgets/gradient_background.dart';

/// 创建救援页面
///
/// 用于创建新的救援任务
/// 包含救援号生成、描述输入、位置获取等功能
class CreateRescuePage extends StatefulWidget {
  const CreateRescuePage({super.key});

  @override
  State<CreateRescuePage> createState() => _CreateRescuePageState();
}

class _CreateRescuePageState extends State<CreateRescuePage>
    with TickerProviderStateMixin {
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _descriptionFocusNode = FocusNode();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _rescueId = '';
  bool _isCreating = false;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();

    // 初始化动画
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // 启动动画
    _fadeController.forward();
    _slideController.forward();

    // 生成救援号
    _generateRescueId();

    // 获取当前位置
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// 生成救援号
  void _generateRescueId() {
    final rescueProvider = context.read<RescueProvider>();
    _rescueId = rescueProvider.generateRescueId();
    setState(() {});
  }

  /// 获取当前位置
  Future<void> _getCurrentLocation() async {
    final locationProvider = context.read<LocationProvider>();
    final success = await locationProvider.getCurrentPosition();
    setState(() {
      _hasLocation = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFF9800),
            Color(0xFFFFF3E0),
          ],
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // 自定义AppBar
                  _buildCustomAppBar(),

                  // 主要内容
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),

                          // 救援号卡片
                          _buildRescueIdCard(),

                          const SizedBox(height: 24),

                          // 描述输入卡片
                          _buildDescriptionCard(),

                          const SizedBox(height: 24),

                          // 位置信息卡片
                          _buildLocationCard(),

                          const SizedBox(height: 32),

                          // 创建按钮
                          _buildCreateButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建自定义AppBar
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            ),
          ),

          // 标题
          const Expanded(
            child: Text(
              '创建救援',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // 占位符（保持对称）
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// 构建救援号卡片
  Widget _buildRescueIdCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.orange[50]!,
            ],
          ),
        ),
        child: Column(
          children: [
            // 图标
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.tag,
                size: 30,
                color: Colors.orange[600],
              ),
            ),

            const SizedBox(height: 16),

            // 标题
            const Text(
              '救援号',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            // 救援号显示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _copyRescueId,
                    icon: Icon(
                      Icons.copy,
                      color: Colors.orange[600],
                    ),
                    tooltip: '复制救援号',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 重新生成按钮
            TextButton.icon(
              onPressed: _generateRescueId,
              icon: Icon(
                Icons.refresh,
                color: Colors.orange[600],
              ),
              label: Text(
                '重新生成',
                style: TextStyle(
                  color: Colors.orange[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建描述输入卡片
  Widget _buildDescriptionCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: Colors.orange[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  '救援描述',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 描述输入框
            TextField(
              controller: _descriptionController,
              focusNode: _descriptionFocusNode,
              maxLines: 3,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: '请输入救援任务的简要描述...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.orange[600]!,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建位置信息卡片
  Widget _buildLocationCard() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        return Card(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color:
                          _hasLocation ? Colors.green[600] : Colors.grey[600],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '救援位置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (!_hasLocation)
                      TextButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新获取'),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // 位置信息
                if (_hasLocation &&
                    locationProvider.currentPosition != null) ...[
                  _buildLocationInfo(
                      '经纬度', locationProvider.currentLocationString),
                  const SizedBox(height: 8),
                  _buildLocationInfo(
                      '海拔', locationProvider.currentAltitudeString),
                  const SizedBox(height: 8),
                  _buildLocationInfo(
                      '精度', locationProvider.currentAccuracyString),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_off,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '正在获取位置信息...',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建位置信息行
  Widget _buildLocationInfo(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建创建按钮
  Widget _buildCreateButton() {
    return Consumer2<RescueProvider, LocationProvider>(
      builder: (context, rescueProvider, locationProvider, child) {
        final canCreate = _descriptionController.text.trim().isNotEmpty &&
            _hasLocation &&
            !_isCreating;

        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canCreate ? _handleCreateRescue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canCreate ? Colors.orange[600] : Colors.grey[300],
              foregroundColor: Colors.white,
              elevation: canCreate ? 8 : 2,
              shadowColor: Colors.orange.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isCreating
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '创建中...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle,
                        size: 24,
                        color: canCreate ? Colors.white : Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '创建救援',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: canCreate ? Colors.white : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  /// 复制救援号
  void _copyRescueId() {
    Clipboard.setData(ClipboardData(text: _rescueId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('救援号 $_rescueId 已复制到剪贴板'),
        backgroundColor: Colors.orange[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// 处理创建救援
  Future<void> _handleCreateRescue() async {
    if (_isCreating) return;

    final rescueProvider = context.read<RescueProvider>();
    final locationProvider = context.read<LocationProvider>();
    final position = locationProvider.currentPosition;

    if (position == null) {
      _showErrorDialog('无法获取当前位置，请重试');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final success = await rescueProvider.createRescue(
        description: _descriptionController.text.trim(),
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
      );

      if (success) {
        // 创建成功，返回首页
        Navigator.of(context).pop(true);
      } else {
        _showErrorDialog(rescueProvider.error ?? '创建救援失败');
      }
    } catch (e) {
      _showErrorDialog('创建救援失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  /// 显示错误对话框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
