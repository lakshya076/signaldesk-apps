import 'dart:math' as math;
import 'package:flutter/material.dart';

class LiveTradeIndicator extends StatelessWidget {
  final double stopLoss;
  final double target;
  final double entryPrice;
  final double currentPrice;
  final String tradeDirection;

  const LiveTradeIndicator({
    super.key,
    required this.stopLoss,
    required this.target,
    required this.entryPrice,
    required this.currentPrice,
    required this.tradeDirection,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 50),
      painter: _TradeIndicatorPainter(
        stopLoss: stopLoss,
        target: target,
        entryPrice: entryPrice,
        currentPrice: currentPrice,
        tradeDirection: tradeDirection,

        profitColor: Theme.of(context).colorScheme.secondary,
        lossColor: Theme.of(context).colorScheme.error,
        textColor: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
      ),
    );
  }
}

class _TradeIndicatorPainter extends CustomPainter {
  final double stopLoss;
  final double target;
  final double entryPrice;
  final double currentPrice;
  final String tradeDirection;
  final Color profitColor;
  final Color lossColor;
  final Color textColor;

  _TradeIndicatorPainter({
    required this.stopLoss,
    required this.target,
    required this.entryPrice,
    required this.currentPrice,
    required this.tradeDirection,
    required this.profitColor,
    required this.lossColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minVal = math.min(stopLoss, target);
    final maxVal = math.max(stopLoss, target);
    final totalRange = maxVal - minVal;
    if (totalRange <= 0) return;

    double getX(double price) {
      final clampedPrice = price.clamp(minVal, maxVal);
      return ((clampedPrice - minVal) / totalRange) * size.width;
    }

    final paint = Paint()..strokeCap = StrokeCap.round;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final lineY = size.height / 2;

    final currentX = getX(currentPrice);

    // UPDATED: Profit/loss logic now depends on tradeDirection
    bool isProfit;
    if (tradeDirection == 'Buy') {
      isProfit = currentPrice >= entryPrice;
    } else {
      // 'Sell'
      isProfit = currentPrice <= entryPrice;
    }
    final progressColor = isProfit ? profitColor : lossColor;

    // Draw the colored part of the line
    paint.color = progressColor;
    paint.strokeWidth = 4;
    canvas.drawLine(Offset(0, lineY), Offset(currentX, lineY), paint);

    // Draw the remaining gray part of the line
    paint.color = Colors.grey.shade600;
    paint.strokeWidth = 2;
    canvas.drawLine(Offset(currentX, lineY), Offset(size.width, lineY), paint);

    // Draw a distinct point for the current live price
    paint.color = progressColor;
    canvas.drawCircle(Offset(currentX, lineY), 6, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(currentX, lineY), 3, paint);

    // Helper function to draw markers and labels
    void drawMarker(double price, String label, {bool isAbove = false}) {
      final x = getX(price);
      paint.color = Colors.grey.shade400;
      paint.strokeWidth = 1.5;
      canvas.drawLine(Offset(x, lineY - 8), Offset(x, lineY + 8), paint);

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      final yPos = isAbove ? lineY - textPainter.height - 12 : lineY + 12;
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), yPos));
    }

    drawMarker(stopLoss, 'SL');
    drawMarker(entryPrice, 'Entry', isAbove: true);
    drawMarker(target, 'Target');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
