import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 救援输入卡片组件
///
/// 提供救援号输入和创建救援功能
/// 采用现代化卡片设计，支持动画效果
class RescueInputCard extends StatefulWidget {
  /// 加入救援回调
  final Function(String rescueId) onJoinRescue;

  /// 创建救援回调
  final VoidCallback onCreateRescue;

  const RescueInputCard({
    super.key,
    required this.onJoinRescue,
    required this.onCreateRescue,
  });

  @override
  State<RescueInputCard> createState() => _RescueInputCardState();
}

class _RescueInputCardState extends State<RescueInputCard>
    with SingleTickerProviderStateMixin {
  final TextEditingController _rescueIdController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isInputValid = false;

  @override
  void initState() {
    super.initState();

    // 初始化动画
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // 监听输入变化
    _rescueIdController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _rescueIdController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 验证输入
  void _validateInput() {
    final text = _rescueIdController.text.trim();
    final isValid = text.length == 4 && RegExp(r'^\d{4}$').hasMatch(text);

    if (isValid != _isInputValid) {
      setState(() {
        _isInputValid = isValid;
      });
    }
  }

  /// 处理加入救援
  void _handleJoinRescue() {
    if (_isInputValid) {
      final rescueId = _rescueIdController.text.trim();
      widget.onJoinRescue(rescueId);
    }
  }

  /// 处理按钮按下
  void _handleButtonDown() {
    _animationController.forward();
  }

  /// 处理按钮释放
  void _handleButtonUp() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 12,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.95),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              _buildTitle(),

              const SizedBox(height: 24),

              // 救援号输入框
              _buildRescueIdInput(),

              const SizedBox(height: 24),

              // 加入救援按钮
              _buildJoinButton(),

              const SizedBox(height: 16),

              // 分割线
              _buildDivider(),

              const SizedBox(height: 16),

              // 创建救援按钮
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标题
  Widget _buildTitle() {
    return Column(
      children: [
        Icon(
          Icons.emergency,
          size: 48,
          color: Colors.orange[600],
        ),
        const SizedBox(height: 12),
        const Text(
          '加入救援',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '输入4位数字救援号',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 构建救援号输入框
  Widget _buildRescueIdInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isInputValid ? Colors.green : Colors.grey[300]!,
          width: 2,
        ),
        color: Colors.grey[50],
      ),
      child: TextField(
        controller: _rescueIdController,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 4,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 8,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          hintText: '0000',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            letterSpacing: 8,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          counterText: '',
          suffixIcon: _isInputValid
              ? const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                )
              : null,
        ),
        onSubmitted: (_) => _handleJoinRescue(),
      ),
    );
  }

  /// 构建加入按钮
  Widget _buildJoinButton() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: GestureDetector(
                onTapDown: (_) => _handleButtonDown(),
                onTapUp: (_) => _handleButtonUp(),
                onTapCancel: _handleButtonUp,
                child: ElevatedButton(
                  onPressed: _isInputValid ? _handleJoinRescue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isInputValid ? Colors.blue[600] : Colors.grey[300],
                    foregroundColor: Colors.white,
                    elevation: _isInputValid ? 8 : 2,
                    shadowColor: Colors.blue.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.login,
                        size: 24,
                        color: _isInputValid ? Colors.white : Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '加入救援',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              _isInputValid ? Colors.white : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建分割线
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey[300],
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '或者',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey[300],
            thickness: 1,
          ),
        ),
      ],
    );
  }

  /// 构建创建按钮
  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: widget.onCreateRescue,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Colors.orange[600]!,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 24,
              color: Colors.orange[600],
            ),
            const SizedBox(width: 8),
            Text(
              '创建新救援',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
