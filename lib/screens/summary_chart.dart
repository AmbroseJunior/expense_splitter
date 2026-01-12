import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/expense_store.dart';
import '../logic/settlement.dart';

class SummaryChart extends StatelessWidget {
  const SummaryChart({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();

    if (store.expenses.isEmpty) {
      return const Center(
        child: Text(
          "No expenses yet\nAdd one to see the chart",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final net = calculateNet(store.users, store.expenses);
    final values = store.users.map((u) => net[u.id] ?? 0.0).toList();

    final maxAbs =
        values.fold<double>(0.0, (m, v) => v.abs() > m ? v.abs() : m);
    final bound = maxAbs == 0 ? 1.0 : maxAbs;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: bound,
          minY: -bound,

          // ✅ grid + baseline
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                strokeWidth: 1,
                dashArray: [6, 6],
              ),
            ],
          ),

          borderData: FlBorderData(show: false),

          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= store.users.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      store.users[i].name,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),

          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final name = store.users[group.x].name;
                final v = values[group.x];
                final sign = v >= 0 ? "+" : "";
                return BarTooltipItem(
                  "$name\n$sign${v.toStringAsFixed(2)}€",
                  const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
          ),

          barGroups: List.generate(store.users.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
