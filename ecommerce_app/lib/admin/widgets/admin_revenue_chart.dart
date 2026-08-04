import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:ecommerce_app/core/theme/app_colors.dart';
import '../services/admin_service.dart';

class AdminRevenueChart extends StatelessWidget {
  final List<DailyMetricPoint> points;
  final String title;

  const AdminRevenueChart({
    super.key,
    required this.points,
    this.title = 'Revenue Trend',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: points.isEmpty
                  ? const Center(child: Text('No revenue data'))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: points.length > 10 ? 4 : 1,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                final d = points[idx].date;
                                return Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10));
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < points.length; i++)
                                FlSpot(i.toDouble(), points[i].value),
                            ],
                            isCurved: true,
                            color: AppColors.deepGold,
                            dotData: const FlDotData(show: false),
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.deepGold.withValues(alpha: 0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
