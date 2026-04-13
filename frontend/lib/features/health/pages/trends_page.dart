import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartSection(context, 'Blood Glucose (mg/dL)', _glucoseData()),
            const SizedBox(height: 30),
            _buildChartSection(context, 'Blood Pressure (mmHg)', _bpData()),
            const SizedBox(height: 30),
            _buildInsightCard(context),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // TODO: Open Manual Entry Dialog
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, String title, List<FlSpot> spots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 20),
        Container(
          height: 200,
          padding: const EdgeInsets.only(right: 20, top: 20),
          decoration: BoxDecoration(color: Colors.black.withAlpha(13), borderRadius: BorderRadius.circular(15)),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.primary.withAlpha(50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[900]!, Colors.blue[800]!]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_graph, color: Colors.white, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI INSIGHT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text(
                  'Your average sugar level decreased by 5% this week. Keep it up!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _glucoseData() {
    return [
      const FlSpot(0, 110),
      const FlSpot(1, 130),
      const FlSpot(2, 120),
      const FlSpot(3, 145),
      const FlSpot(4, 115),
      const FlSpot(5, 110),
      const FlSpot(6, 120),
    ];
  }

  List<FlSpot> _bpData() {
    return [
      const FlSpot(0, 120),
      const FlSpot(1, 118),
      const FlSpot(2, 125),
      const FlSpot(3, 130),
      const FlSpot(4, 122),
      const FlSpot(5, 119),
      const FlSpot(6, 121),
    ];
  }
}
