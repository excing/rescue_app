import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/providers/rescue_provider.dart';
import '../../core/models/rescue_model.dart';

/// 最近救援列表组件
///
/// 显示用户最近参与的救援列表
/// 支持点击快速加入救援
class RecentRescuesList extends StatelessWidget {
  /// 救援选择回调
  final Function(String rescueId) onRescueSelected;

  const RecentRescuesList({
    super.key,
    required this.onRescueSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RescueProvider>(
      builder: (context, rescueProvider, child) {
        final recentRescues = rescueProvider.recentRescues;

        if (recentRescues.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            _buildTitle(),

            const SizedBox(height: 8),

            // 救援列表
            Expanded(
              child: _buildRescueList(recentRescues),
            ),
          ],
        );
      },
    );
  }

  /// 构建标题
  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(
            Icons.history,
            color: Colors.white.withOpacity(0.9),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '最近救援',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建救援列表
  Widget _buildRescueList(List<RescueModel> rescues) {
    return ListView.builder(
      itemCount: rescues.length,
      itemBuilder: (context, index) {
        final rescue = rescues[index];
        return _buildRescueItem(rescue, index);
      },
    );
  }

  /// 构建救援项
  Widget _buildRescueItem(RescueModel rescue, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => onRescueSelected(rescue.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                // 救援图标
                _buildRescueIcon(rescue),

                const SizedBox(width: 16),

                // 救援信息
                Expanded(
                  child: _buildRescueInfo(rescue),
                ),

                // 箭头图标
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建救援图标
  Widget _buildRescueIcon(RescueModel rescue) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: rescue.isActive ? Colors.green[100] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rescue.isActive ? Colors.green[300]! : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Icon(
        rescue.isActive ? Icons.emergency : Icons.emergency_outlined,
        color: rescue.isActive ? Colors.green[600] : Colors.grey[600],
        size: 24,
      ),
    );
  }

  /// 构建救援信息
  Widget _buildRescueInfo(RescueModel rescue) {
    final dateFormat = DateFormat('MM-dd HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 救援号和状态
        Row(
          children: [
            Text(
              '救援 ${rescue.id}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(rescue),
          ],
        ),

        const SizedBox(height: 4),

        // 救援描述
        Text(
          rescue.description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // 创建时间和位置
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 12,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 4),
            Text(
              dateFormat.format(rescue.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.location_on,
              size: 12,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 4),
            Text(
              '${rescue.altitude.toStringAsFixed(0)}m',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建状态徽章
  Widget _buildStatusBadge(RescueModel rescue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: rescue.isActive ? Colors.green[100] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        rescue.isActive ? '进行中' : '已结束',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: rescue.isActive ? Colors.green[700] : Colors.grey[700],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无最近救援',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '创建或加入救援后会显示在这里',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
