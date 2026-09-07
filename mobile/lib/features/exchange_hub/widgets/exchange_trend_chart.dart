import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../services/exchange_rate_service.dart';

/// Clean, responsive line trend chart for currency pairs
class ExchangeTrendChart extends StatelessWidget {
  final String pair;
  final List<HistoricalRatePoint> dataPoints;
  final Color lineColor;

  const ExchangeTrendChart({
    super.key,
    required this.pair,
    required this.dataPoints,
    this.lineColor = ZivaTheme.gold400,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('No historical data points available', style: TextStyle(color: ZivaTheme.textMuted)),
        ),
      );
    }

    final rates = dataPoints.map((p) => p.rate).toList();
    final minRate = rates.reduce(math.min);
    final maxRate = rates.reduce(math.max);
    final firstRate = rates.first;
    final lastRate = rates.last;
    final pctChange = ((lastRate - firstRate) / firstRate) * 100.0;
    final isPositive = pctChange >= 0;

    final startDateStr = DateFormat('MMM d').format(dataPoints.first.date);
    final endDateStr = DateFormat('MMM d').format(dataPoints.last.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Summary Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pair,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ZivaTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$startDateStr – $endDateStr',
                  style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  lastRate.toStringAsFixed(4),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: ZivaTheme.textPrimary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: isPositive ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${isPositive ? '+' : ''}${pctChange.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPositive ? ZivaTheme.emerald400 : ZivaTheme.rose400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Custom Canvas Chart
        SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineTrendChartPainter(
              dataPoints: dataPoints,
              minRate: minRate,
              maxRate: maxRate,
              lineColor: lineColor,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Range Boundary Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Low: ${minRate.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted, fontFamily: 'monospace'),
            ),
            Text(
              'High: ${maxRate.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted, fontFamily: 'monospace'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LineTrendChartPainter extends CustomPainter {
  final List<HistoricalRatePoint> dataPoints;
  final double minRate;
  final double maxRate;
  final Color lineColor;

  _LineTrendChartPainter({
    required this.dataPoints,
    required this.minRate,
    required this.maxRate,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    final range = (maxRate - minRate) == 0 ? 1.0 : (maxRate - minRate);
    final widthStep = size.width / (dataPoints.length - 1);

    // 1. Draw subtle horizontal grid lines
    final gridPaint = Paint()
      ..color = ZivaTheme.borderCard.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), gridPaint);

    final linePath = Path();
    final fillPath = Path();

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * widthStep;
      // Invert Y so higher rate is towards top
      final normalized = (dataPoints[i].rate - minRate) / range;
      final y = size.height - (normalized * (size.height - 20) + 10);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // 2. Draw Gradient Fill beneath curve
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.28),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 3. Draw Main Trend Line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // 4. Draw End Marker Dot
    final lastPoint = dataPoints.last;
    final lastNorm = (lastPoint.rate - minRate) / range;
    final lastX = size.width;
    final lastY = size.height - (lastNorm * (size.height - 20) + 10);

    final dotPaint = Paint()..color = lineColor;
    final haloPaint = Paint()..color = lineColor.withValues(alpha: 0.3);

    canvas.drawCircle(Offset(lastX, lastY), 6.0, haloPaint);
    canvas.drawCircle(Offset(lastX, lastY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _LineTrendChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.minRate != minRate ||
        oldDelegate.maxRate != maxRate ||
        oldDelegate.lineColor != lineColor;
  }
}
