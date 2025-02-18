import 'package:flutter/material.dart';

class BusRouteDetails extends StatelessWidget {
  final Map<String, dynamic> busData;

  const BusRouteDetails({super.key, required this.busData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeName = busData['route_name'] ?? '未知路线';
    final date = busData['abscissa'] ?? '';
    final time = busData['yaxis'] ?? '';
    final margin = busData['row']['margin'] ?? 0;
    final id = busData['bus_id']?.toString() ?? 'N/A';
    final period = busData['time_id']?.toString() ?? 'N/A';

    return Stack(
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 360),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withAlpha((0.05 * 255).toInt()),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 路线信息
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary
                          .withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_bus_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '班车路线',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          routeName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            fontSize: routeName.length > 10 ? 18 : 20,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 40),
                ],
              ),
              SizedBox(height: 16),

              // 分隔线和装饰圆点
              Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(double.infinity, 1),
                    painter: DashedLinePainter(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  Row(
                    children: [
                      _buildCircle(theme),
                      Spacer(),
                      _buildCircle(theme),
                    ],
                  ),
                ],
              ),

              // 主要信息区域
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMainInfo(
                        context,
                        icon: Icons.access_time_rounded,
                        label: '出发时间',
                        value: time,
                        subValue: date,
                      ),
                    ),
                    Container(
                      height: 50,
                      width: 1,
                      color: theme.colorScheme.outlineVariant
                          .withAlpha((0.5 * 255).toInt()),
                    ),
                    Expanded(
                      child: _buildMainInfo(
                        context,
                        icon: Icons.people_rounded,
                        label: '已约人数',
                        value: (900 - margin).toString(),
                        subValue: '当前预约',
                      ),
                    ),
                  ],
                ),
              ),

              // 详细信息
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withAlpha((0.3 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withAlpha((0.5 * 255).toInt()),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                        context, '班车编号', id, Icons.confirmation_number_rounded),
                    Divider(height: 12, thickness: 0.5),
                    _buildDetailRow(
                        context, '时段编号', period, Icons.schedule_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 关闭按钮
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filledTonal(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withAlpha((0.5 * 255).toInt()),
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              padding: EdgeInsets.all(8),
              minimumSize: Size(32, 32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircle(ThemeData theme) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildMainInfo(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          subValue,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// 虚线画笔
class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashWidth = 5;
    const dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
