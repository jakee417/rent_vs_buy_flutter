import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChartSpot {
  ChartSpot({
    required this.index,
    required this.value,
  });
  double index;
  double value;
}

class ChartData {
  ChartData({
    required this.series,
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.minX,
    required this.maxX,
    required this.length,
  });

  List<ChartSpot> spots;
  String series;
  double minY;
  double maxY;
  double minX;
  double maxX;
  int length;

  double get baselineY => invertY(0.0);

  double invertY(double value) {
    return value * (maxY - minY) + minY;
  }

  double invertX(double value) {
    return value * (maxX - minX) + minX;
  }

  double get xInterval => 1 / length;
}

class ChartWidget extends StatefulWidget {
  ChartWidget({
    super.key,
    required this.chartData,
    required this.title,
  });
  final String title;
  final ChartData chartData;
  final Color betweenColor = Colors.red.withOpacity(0.5);

  @override
  State<ChartWidget> createState() => _ChartWidget();
}

class _ChartWidget extends State<ChartWidget> {
  final compact = NumberFormat.compact();
  final compactSimpleCurrency = NumberFormat.compactSimpleCurrency();
  final style = const TextStyle(fontSize: 12);

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(compactSimpleCurrency.format(widget.chartData.invertY(value)),
          style: style),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    if (value < 0) {
      return const SizedBox.shrink();
    }
    if (value > 1) {
      return const SizedBox.shrink();
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child:
          Text(compact.format(widget.chartData.invertX(value)), style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lineBarsData = [
      LineChartBarData(
        isCurved: true,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (p0, p1, p2, p3) {
            return FlDotCirclePainter(
              color: widget.chartData.invertY(p0.y) >= 0
                  ? Colors.green
                  : Colors.red,
            );
          },
        ),
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9),
        spots: widget.chartData.spots
            .map(
              (i) => FlSpot(i.index, i.value),
            )
            .toList(),
      ),
    ];
    final lineChartData = LineChartData(
      clipData: const FlClipData.none(),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) {
            return widget.chartData.invertY(touchedSpot.y) >= 0
                ? Colors.green
                : Colors.red;
          },
          getTooltipItems: (value) {
            return value
                .map(
                  (e) => LineTooltipItem(
                    "(${compact.format(widget.chartData.invertX(e.x))}, ${compactSimpleCurrency.format(widget.chartData.invertY(e.y))})",
                    const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
                .toList();
          },
        ),
      ),
      baselineY: widget.chartData.baselineY,
      minY: -0.05,
      maxY: 1.15,
      minX: -0.15,
      maxX: 1.15,
      // betweenBarsData: [
      //   BetweenBarsData(
      //     fromIndex: 0,
      //     toIndex: 1,
      //     color: widget.betweenColor,
      //   )
      // ],
      lineBarsData: lineBarsData,
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: bottomTitleWidgets,
            interval: 0.2,
            reservedSize: 50,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: leftTitleWidgets,
            interval: 0.2,
            reservedSize: 60,
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      gridData: const FlGridData(show: true),
    );
    final chart = AspectRatio(
      aspectRatio: MediaQuery.of(context).size.aspectRatio,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: LineChart(lineChartData),
      ),
    );
    final infoButton = ElevatedButton(
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (BuildContext context) {
            return SizedBox(
              height: 250,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Spacer(),
                      const Text(
                        "Rent vs. Buy Chart",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        "This chart shows the Rent vs. Buy tradeoff for various values of ${widget.title.toLowerCase()}.\n\n Positive values indicate buying is a better option. Negative values indicate renting is a better option.",
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      ElevatedButton(
                        child: const Text("Done"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        fixedSize: const Size(10, 10),
      ),
      child: const Icon(Icons.info),
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.title),
            infoButton,
          ],
        ),
      ),
      body: Center(
        child: chart,
      ),
    );
  }
}
