import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/permission_service.dart';
import '../widgets/gradient_background.dart';

/// 权限管理页面
///
/// 引导用户授权必要的权限，包括位置权限、通知权限等
/// 提供友好的权限说明和引导流程
class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final PermissionService _permissionService = PermissionService.instance;

  bool _isRequestingPermissions = false;
  Map<String, bool> _permissionStatus = {
    'location': false,
    'backgroundLocation': false,
    'notification': false,
  };

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

    // 检查当前权限状态
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// 检查权限状态
  Future<void> _checkPermissionStatus() async {
    final locationGranted = await _permissionService.hasLocationPermission();
    final backgroundLocationGranted =
        await _permissionService.hasBackgroundLocationPermission();
    final notificationGranted =
        await _permissionService.hasNotificationPermission();

    setState(() {
      _permissionStatus['location'] = locationGranted;
      _permissionStatus['backgroundLocation'] = backgroundLocationGranted;
      _permissionStatus['notification'] = notificationGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4CAF50),
            Color(0xFFE8F5E8),
          ],
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 顶部间距
                    const SizedBox(height: 40),

                    // 标题
                    _buildTitle(),

                    const SizedBox(height: 40),

                    // 权限列表
                    Expanded(
                      child: _buildPermissionList(),
                    ),

                    // 底部按钮
                    _buildBottomButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标题
  Widget _buildTitle() {
    return Column(
      children: [
        // 图标
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.security,
            size: 40,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 16),

        // 标题
        const Text(
          '权限设置',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),

        const SizedBox(height: 8),

        // 描述
        Text(
          '为了提供最佳的救援体验，需要您授权以下权限',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /// 构建权限列表
  Widget _buildPermissionList() {
    return Column(
      children: [
        // 位置权限
        _buildPermissionCard(
          icon: Icons.location_on,
          title: '位置权限',
          description: '获取您的位置信息，用于记录救援轨迹',
          isGranted: _permissionStatus['location']!,
          onTap: _requestLocationPermission,
        ),

        const SizedBox(height: 16),

        // 后台位置权限
        _buildPermissionCard(
          icon: Icons.location_history,
          title: '后台位置权限',
          description: '在应用后台时继续记录位置，确保轨迹完整',
          isGranted: _permissionStatus['backgroundLocation']!,
          onTap: _requestBackgroundLocationPermission,
        ),

        const SizedBox(height: 16),

        // 通知权限
        _buildPermissionCard(
          icon: Icons.notifications,
          title: '通知权限',
          description: '发送重要的救援状态通知',
          isGranted: _permissionStatus['notification']!,
          onTap: _requestNotificationPermission,
        ),
      ],
    );
  }

  /// 构建权限卡片
  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isGranted ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.95),
              ],
            ),
          ),
          child: Row(
            children: [
              // 图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isGranted ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isGranted ? Colors.green[600] : Colors.orange[600],
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // 文本信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 状态图标
              Icon(
                isGranted ? Icons.check_circle : Icons.arrow_forward_ios,
                color: isGranted ? Colors.green[600] : Colors.grey[400],
                size: isGranted ? 24 : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildBottomButtons() {
    final allGranted = _permissionStatus.values.every((granted) => granted);

    return Column(
      children: [
        // 一键授权按钮
        if (!allGranted)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed:
                  _isRequestingPermissions ? null : _requestAllPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: Colors.green.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isRequestingPermissions
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
                          '请求权限中...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.security, size: 24),
                        SizedBox(width: 8),
                        Text(
                          '一键授权',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

        if (!allGranted) const SizedBox(height: 16),

        // 完成按钮
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: Colors.white,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              allGranted ? '完成' : '稍后设置',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 请求位置权限
  Future<void> _requestLocationPermission() async {
    final result = await _permissionService.requestLocationPermission();
    setState(() {
      _permissionStatus['location'] = result == PermissionStatus.granted;
    });
  }

  /// 请求后台位置权限
  Future<void> _requestBackgroundLocationPermission() async {
    final result =
        await _permissionService.requestBackgroundLocationPermission();
    setState(() {
      _permissionStatus['backgroundLocation'] =
          result == PermissionStatus.granted;
    });
  }

  /// 请求通知权限
  Future<void> _requestNotificationPermission() async {
    final result = await _permissionService.requestNotificationPermission();
    setState(() {
      _permissionStatus['notification'] = result == PermissionStatus.granted;
    });
  }

  /// 请求所有权限
  Future<void> _requestAllPermissions() async {
    setState(() {
      _isRequestingPermissions = true;
    });

    try {
      final result = await _permissionService.requestLocationPermissions();

      setState(() {
        _permissionStatus['location'] = result.locationGranted;
        _permissionStatus['backgroundLocation'] =
            result.backgroundLocationGranted;
        _permissionStatus['notification'] = result.notificationGranted;
      });

      // 显示结果
      _showPermissionResult(result);
    } finally {
      setState(() {
        _isRequestingPermissions = false;
      });
    }
  }

  /// 显示权限请求结果
  void _showPermissionResult(LocationPermissionResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.hasBasicPermissions ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
