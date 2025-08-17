import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/rescue_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/services/permission_service.dart';
import '../widgets/gradient_background.dart';
import '../widgets/rescue_input_card.dart';
import '../widgets/recent_rescues_list.dart';
import '../widgets/error_handler.dart';
import 'create_rescue_page.dart';
import 'rescue_page.dart';
import 'permission_page.dart';
import 'test_background_page.dart';

/// 首页
///
/// 应用的主入口页面，提供救援号输入和最近救援列表功能
/// 采用现代化设计，年轻化风格，操作简单直观
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 初始化动画
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

    // 初始化服务
    _initializeServices();
  }

  /// 初始化服务
  Future<void> _initializeServices() async {
    final locationProvider = context.read<LocationProvider>();
    final rescueProvider = context.read<RescueProvider>();

    // 加载最近救援列表
    await rescueProvider.loadRecentRescues();

    // 初始化位置服务
    await locationProvider.initialize();
  }

  /// 导航到权限页面
  void _navigateToPermissionPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PermissionPage(),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// 检查权限，如果未授权则导航到权限页面
  Future<bool> _checkAndRequestPermissions() async {
    final permissionService = PermissionService.instance;
    final hasPermission = await permissionService.hasLocationPermission();

    if (hasPermission) {
      return true;
    }

    if (!mounted) return false;

    // 导航到权限页面并等待返回
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PermissionPage()),
    );

    // 再次检查权限
    final hasPermissionNow = await permissionService.hasLocationPermission();
    if (!hasPermissionNow) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, '需要位置权限才能继续操作');
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 顶部间距
                      const SizedBox(height: 16),

                      // 应用标题
                      _buildAppTitle(),

                      const SizedBox(height: 24),

                      // 救援输入卡片
                      RescueInputCard(
                        onJoinRescue: _handleJoinRescue,
                        onCreateRescue: _handleCreateRescue,
                      ),

                      const SizedBox(height: 16),

                      // 最近救援列表
                      SizedBox(
                        height: 280,
                        child: RecentRescuesList(
                          onRescueSelected: _handleRescueSelected,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 底部版本信息和调试按钮
                      _buildVersionInfo(),

                      // 调试按钮（仅在调试模式下显示）
                      if (kDebugMode) ...[
                        const SizedBox(height: 8),
                        _buildDebugButton(),
                      ],

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建应用标题
  Widget _buildAppTitle() {
    return Column(
      children: [
        // 应用图标
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
            Icons.location_on,
            size: 40,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 16),

        // 应用名称
        const Text(
          '救援APP',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),

        const SizedBox(height: 8),

        // 应用描述
        Text(
          '多人位置共享 · 轨迹记录',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /// 构建版本信息
  Widget _buildVersionInfo() {
    return Text(
      'v0.0.1',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withOpacity(0.6),
      ),
    );
  }

  /// 构建调试按钮
  Widget _buildDebugButton() {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const TestBackgroundPage(),
          ),
        );
      },
      icon: const Icon(Icons.bug_report, color: Colors.white),
      label: const Text(
        '后台服务测试',
        style: TextStyle(color: Colors.white),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// 处理加入救援
  Future<void> _handleJoinRescue(String rescueId) async {
    final hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) return;

    final rescueProvider = context.read<RescueProvider>();

    // 显示加载对话框
    ErrorHandler.showLoadingDialog(context, message: '正在加入救援...');

    try {
      final success = await rescueProvider.joinRescue(rescueId);

      // 关闭加载对话框
      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
      }

      if (success) {
        // 加入成功，导航到救援页面
        _navigateToRescuePage();
      } else {
        // 加入失败，显示错误信息
        if (mounted) {
          ErrorHandler.showErrorSnackBar(
            context,
            rescueProvider.error ?? '加入救援失败',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        ErrorHandler.showErrorSnackBar(context, '加入救援失败: $e');
      }
    }
  }

  /// 处理创建救援
  Future<void> _handleCreateRescue() async {
    final hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const CreateRescuePage(),
      ),
    );

    if (result == true) {
      // 创建成功，导航到救援页面
      _navigateToRescuePage();
    }
  }

  /// 处理选择最近救援
  Future<void> _handleRescueSelected(String rescueId) async {
    await _handleJoinRescue(rescueId);
  }

  /// 导航到救援页面
  void _navigateToRescuePage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const RescuePage(),
      ),
    );
  }
}
