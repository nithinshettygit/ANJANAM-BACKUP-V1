import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:ecommerce_app/core/theme/app_colors.dart';
import '../services/admin_service.dart';

class AdminOrdersChart extends StatelessWidget {
  final List<DailyMetricPoint> points;

  const AdminOrdersChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Orders Per Day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: points.isEmpty
                  ? const Center(child: Text('No order data'))
                  : BarChart(
                      BarChartData(
                        minY: 0,
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
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
                        barGroups: [
                          for (var i = 0; i < points.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: points[i].value,
                                  color: AppColors.marigoldOrange,
                                  borderRadius: BorderRadius.circular(4),
                                  width: 10,
                                ),
                              ],
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
