import 'package:flutter/material.dart';

/// 渐变背景组件
/// 
/// 提供可自定义的渐变背景，支持动画效果
/// 用于创建现代化的视觉效果
class GradientBackground extends StatelessWidget {
  /// 渐变配置
  final Gradient gradient;
  
  /// 子组件
  final Widget child;
  
  /// 是否启用动画
  final bool animated;
  
  /// 动画持续时间
  final Duration animationDuration;

  const GradientBackground({
    super.key,
    required this.gradient,
    required this.child,
    this.animated = false,
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  Widget build(BuildContext context) {
    if (animated) {
      return _AnimatedGradientBackground(
        gradient: gradient,
        duration: animationDuration,
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}

/// 动画渐变背景
class _AnimatedGradientBackground extends StatefulWidget {
  final Gradient gradient;
  final Duration duration;
  final Widget child;

  const _AnimatedGradientBackground({
    required this.gradient,
    required this.duration,
    required this.child,
  });

  @override
  State<_AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<_AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: _createAnimatedGradient(),
          ),
          child: widget.child,
        );
      },
    );
  }

  /// 创建动画渐变
  Gradient _createAnimatedGradient() {
    if (widget.gradient is LinearGradient) {
      final linear = widget.gradient as LinearGradient;
      return LinearGradient(
        begin: linear.begin,
        end: linear.end,
        colors: linear.colors.map((color) {
          return Color.lerp(
            color,
            color.withOpacity(0.8),
            _animation.value,
          )!;
        }).toList(),
        stops: linear.stops,
      );
    }
    
    return widget.gradient;
  }
}

/// 预定义的渐变样式
class GradientStyles {
  /// 首页渐变
  static const LinearGradient home = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF667eea),
      Color(0xFF764ba2),
    ],
  );

  /// 创建救援页渐变
  static const LinearGradient createRescue = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFF9800),
      Color(0xFFFFF3E0),
    ],
  );

  /// 救援页渐变（地图背景）
  static const LinearGradient rescue = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF2196F3),
      Color(0xFFE3F2FD),
    ],
  );

  /// 成功状态渐变
  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4CAF50),
      Color(0xFFE8F5E8),
    ],
  );

  /// 错误状态渐变
  static const LinearGradient error = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF44336),
      Color(0xFFFFEBEE),
    ],
  );

  /// 警告状态渐变
  static const LinearGradient warning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF9800),
      Color(0xFFFFF3E0),
    ],
  );

  /// 夜间模式渐变
  static const LinearGradient dark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF263238),
      Color(0xFF37474F),
    ],
  );

  /// 获取随机渐变
  static LinearGradient get random {
    final gradients = [
      home,
      createRescue,
      success,
      warning,
    ];
    gradients.shuffle();
    return gradients.first;
  }
}

/// 渐变工具类
class GradientUtils {
  /// 创建线性渐变
  static LinearGradient createLinear({
    required List<Color> colors,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
    List<double>? stops,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors,
      stops: stops,
    );
  }

  /// 创建径向渐变
  static RadialGradient createRadial({
    required List<Color> colors,
    Alignment center = Alignment.center,
    double radius = 0.5,
    List<double>? stops,
  }) {
    return RadialGradient(
      center: center,
      radius: radius,
      colors: colors,
      stops: stops,
    );
  }

  /// 创建扫描渐变
  static SweepGradient createSweep({
    required List<Color> colors,
    Alignment center = Alignment.center,
    double startAngle = 0.0,
    double endAngle = 6.28318530718, // 2 * pi
    List<double>? stops,
  }) {
    return SweepGradient(
      center: center,
      startAngle: startAngle,
      endAngle: endAngle,
      colors: colors,
      stops: stops,
    );
  }

  /// 混合两个颜色
  static Color blendColors(Color color1, Color color2, double ratio) {
    return Color.lerp(color1, color2, ratio) ?? color1;
  }

  /// 创建颜色变化序列
  static List<Color> createColorSequence(
    Color startColor,
    Color endColor,
    int steps,
  ) {
    final colors = <Color>[];
    for (int i = 0; i < steps; i++) {
      final ratio = i / (steps - 1);
      colors.add(blendColors(startColor, endColor, ratio));
    }
    return colors;
  }
}
