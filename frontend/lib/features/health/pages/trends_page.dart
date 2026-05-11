import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<FlSpot> _glucoseSpots = [];
  List<FlSpot> _bpSpots = [];
  bool _isLoading = true;
  String _aiInsight = 'Analyzing your health trends...';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await _supabase
          .from('health_metrics')
          .select()
          .order('recorded_at', ascending: true)
          .limit(10);
      
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);
      
      setState(() {
        _glucoseSpots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['glucose_level'] ?? 100).toDouble())).toList();
        _bpSpots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['systolic_bp'] ?? 120).toDouble())).toList();
        
        if (data.isNotEmpty) {
          _aiInsight = 'Based on your last ${data.length} readings, your glucose levels are stabilizing.';
        } else {
          _aiInsight = 'No health metrics found. Add your first reading to see AI insights.';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _aiInsight = 'Error fetching trends. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChartSection(context, 'Blood Glucose (mg/dL)', _glucoseSpots),
                const SizedBox(height: 30),
                _buildChartSection(context, 'Blood Pressure (mmHg)', _bpSpots),
                const SizedBox(height: 30),
                _buildInsightCard(context),
              ],
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // In a real app, this would open a dialog to insert data into health_metrics
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual entry coming soon!')));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, String title, List<FlSpot> spots) {
    if (spots.isEmpty) return const SizedBox.shrink();
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
      child: Row(
        children: [
          const Icon(Icons.auto_graph, color: Colors.white, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI INSIGHT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text(
                  _aiInsight,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
