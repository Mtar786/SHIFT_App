import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'session_manager.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key});

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  // --- SESSION STATE ---
  bool isLiveSession = true;
  Timer? _timer;
  final Random _random = Random();
  int _sessionSeconds = 0;
  bool showWarning = false;

  // --- DYNAMIC DATA ---
  int _currentHeartRate = 75;
  int _currentSpO2 = 98;
  int _currentHeatStress = 32;
  int _currentBreathing = 16;

  // Track HR to calculate a real average at the end
  final List<int> _hrHistory = [];

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- LOGIC: SIMULATED SENSOR DATA ---
  void startTimer() {
    _timer?.cancel();
    setState(() {
      _sessionSeconds = 0;
      isLiveSession = true;
      _hrHistory.clear();
      _hrHistory.add(_currentHeartRate);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionSeconds++;

          // Simulate realistic sensor drift
          _currentHeartRate = _simulateSensor(_currentHeartRate, 60, 185, 3);
          _currentSpO2 = _simulateSensor(_currentSpO2, 94, 100, 1);
          _currentHeatStress = _simulateSensor(_currentHeatStress, 25, 95, 2);
          _currentBreathing = _simulateSensor(_currentBreathing, 12, 30, 1);

          _hrHistory.add(_currentHeartRate);

          // Logic: Show Warning if metrics are in danger zones
          showWarning = (_currentHeatStress > 80 || _currentHeartRate > 160);
        });
      }
    });
  }

  int _simulateSensor(int current, int min, int max, int step) {
    int drift = _random.nextInt(step * 2 + 1) - step;
    return (current + drift).clamp(min, max);
  }

  void endSession() {
    _timer?.cancel();

    // Calculate actual Average HR from the session
    int avgHr = _hrHistory.isEmpty ? 0 : (_hrHistory.reduce((a, b) => a + b) ~/ _hrHistory.length);

    final newSession = SessionItemData(
      title: DateFormat('MMM d, h:mm a').format(DateTime.now()),
      duration: _getFormattedTime(_sessionSeconds),
      avgHrBpm: avgHr,
      peakHeatPercent: _currentHeatStress, // Using last recorded heat stress
      alerts: showWarning ? 1 : 0,
    );

    SessionManager().addSession(newSession);
    setState(() => isLiveSession = false);
  }

  String _getFormattedTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // --- UI: BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: isLiveSession ? _buildLiveView() : _buildSummaryView(),
        ),
      ),
    );
  }

  Widget _buildLiveView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Session', style: TextStyle(color: Colors.white, fontSize: 18)),
                Text(_getFormattedTime(_sessionSeconds),
                    style: const TextStyle(color: Color(0xFF1A5CFF), fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
            const Row(
              children: [
                Icon(Icons.circle, color: Colors.red, size: 10),
                SizedBox(width: 8),
                Text('REC', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
        const SizedBox(height: 20),

        // Warning Banner
        if (showWarning) _buildWarningBanner(),

        // Metric Grid
        Row(
          children: [
            Expanded(
              child: _LiveMetricCard(
                title: 'Heart Rate',
                value: '$_currentHeartRate',
                unit: 'BPM',
                icon: Icons.favorite,
                // Logic: Red if > 150, Orange if > 120, else Green
                color: _currentHeartRate > 150 ? Colors.red : (_currentHeartRate > 120 ? Colors.orange : Colors.green),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _LiveMetricCard(
                title: 'Blood O₂',
                value: '$_currentSpO2',
                unit: '%',
                icon: Icons.water_drop,
                color: _currentSpO2 < 95 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _LiveMetricCard(
                title: 'Heat Stress',
                value: '$_currentHeatStress',
                unit: '%',
                icon: Icons.thermostat,
                color: _currentHeatStress > 75 ? Colors.red : (_currentHeatStress > 50 ? Colors.orange : Colors.green),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _LiveMetricCard(
                title: 'Breathing',
                value: '$_currentBreathing',
                unit: 'BrPM',
                icon: Icons.air,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: endSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD30000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('End Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryView() {
    int avgHr = _hrHistory.isEmpty ? 0 : (_hrHistory.reduce((a, b) => a + b) ~/ _hrHistory.length);

    return Column(
      children: [
        const Text("SHIFT Summary", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _SummaryMetricCard(title: "Duration", value: _getFormattedTime(_sessionSeconds)),
        const SizedBox(height: 12),
        _SummaryMetricCard(title: "Average Heart Rate", value: "$avgHr BPM"),
        const SizedBox(height: 12),
        _SummaryMetricCard(title: "Peak Heat Stress", value: "$_currentHeatStress%"),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: startTimer,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text("Start New Session", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 12),
          Text("HIGH STRESS DETECTED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- HELPER COMPONENTS ---

class _LiveMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _LiveMetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          Text("$unit • status", style: TextStyle(color: color, fontSize: 12)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryMetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF14161B), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}