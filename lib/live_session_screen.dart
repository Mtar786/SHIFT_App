import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'session_manager.dart';

class LiveSessionScreen extends StatefulWidget {
  final double bpm;
  final double oxygen;
  final double temperature;
  final int quality;
  final String alarms;

  const LiveSessionScreen({
    super.key,
    required this.bpm,
    required this.oxygen,
    required this.temperature,
    required this.quality,
    required this.alarms,
  });

  @override
  State<LiveSessionScreen> createState() => LiveSessionScreenState();
}

class LiveSessionScreenState extends State<LiveSessionScreen> {
  bool isLiveSession = true;
  Timer? _timer;
  int _sessionSeconds = 0;

  final List<double> _bpmHistory = [];
  final List<double> _oxygenHistory = [];
  final List<double> _tempHistory = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    _timer?.cancel();
    setState(() {
      _sessionSeconds = 0;
      isLiveSession = true;
      _bpmHistory.clear();
      _oxygenHistory.clear();
      _tempHistory.clear();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionSeconds++;
          if (widget.bpm > 0) _bpmHistory.add(widget.bpm);
          if (widget.oxygen > 0) _oxygenHistory.add(widget.oxygen);
          if (widget.temperature > 0) _tempHistory.add(widget.temperature);
        });
      }
    });
  }

  void endSession() {
    _timer?.cancel();

    // Calculate Heart Rate Average
    double avgBpm = _bpmHistory.isEmpty
        ? 0
        : (_bpmHistory.reduce((a, b) => a + b) / _bpmHistory.length);

    // Calculate Oxygen Average
    double avgOxy = _oxygenHistory.isEmpty
        ? 0
        : (_oxygenHistory.reduce((a, b) => a + b) / _oxygenHistory.length);

    // Calculate Temp Average
    double avgTemp = _tempHistory.isEmpty
        ? 0
        : (_tempHistory.reduce((a, b) => a + b) / _tempHistory.length);

    final newSession = SessionItemData(
      title: DateFormat('MMM d, h:mm a').format(DateTime.now()),
      duration: _getFormattedTime(_sessionSeconds),
      avgHrBpm: avgBpm,
      avgOxygen: avgOxy,            // Passing new data
      avgTemperature: avgTemp,      // Passing new data
      peakHeatPercent: widget.quality,
      alerts: (widget.alarms != "OK" && widget.alarms.isNotEmpty) ? 1 : 0,
    );

    SessionManager().addSession(newSession);
    setState(() => isLiveSession = false);
  }

  String _getFormattedTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

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
    bool hasAlarm = widget.alarms != "OK" && widget.alarms.isNotEmpty;

    // --- DYNAMIC THRESHOLD LOGIC ---
    Color bpmColor = Colors.greenAccent;
    if (widget.bpm > 160) bpmColor = Colors.red;
    else if (widget.bpm > 120) bpmColor = Colors.orange;

    Color oxyColor = Colors.blueAccent;
    if (widget.oxygen > 0 && widget.oxygen < 92) oxyColor = Colors.red;
    else if (widget.oxygen > 0 && widget.oxygen < 95) oxyColor = Colors.orange;

    Color tempColor = Colors.green;
    if (widget.temperature > 38.5) tempColor = Colors.red;
    else if (widget.temperature > 37.5) tempColor = Colors.orange;

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

        if (hasAlarm) _buildWarningBanner(widget.alarms),

        // Row 1: Heart Rate & Blood Oxygen
        Row(
          children: [
            Expanded(
              child: _LiveMetricCard(
                title: 'Heart Rate',
                value: widget.bpm > 0 ? '${widget.bpm}' : '--',
                unit: 'BPM',
                icon: Icons.favorite,
                color: bpmColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _LiveMetricCard(
                title: 'Blood Oxygen',
                value: widget.oxygen > 0 ? '${widget.oxygen}' : '--',
                unit: '%',
                icon: Icons.water_drop,
                color: oxyColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Row 2: Body Temp & Vest Status
        Row(
          children: [
            Expanded(
              child: _LiveMetricCard(
                title: 'Body Temp',
                value: widget.temperature > 0 ? widget.temperature.toStringAsFixed(1) : '--',
                unit: '°C',
                icon: Icons.thermostat,
                color: tempColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _LiveMetricCard(
                title: 'Signal Quality',
                value: widget.quality > 0 ? '${widget.quality}' : '--',
                unit: 'system',
                icon: Icons.shield,
                color: widget.alarms == "OK" ? Colors.green : Colors.red,
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
    double avgBpm = _bpmHistory.isEmpty ? 0 : (_bpmHistory.reduce((a, b) => a + b) / _bpmHistory.length);
    double avgOxy = _oxygenHistory.isEmpty ? 0 : (_oxygenHistory.reduce((a, b) => a + b) / _oxygenHistory.length);
    double avgTemp = _tempHistory.isEmpty ? 0 : (_tempHistory.reduce((a, b) => a + b) / _tempHistory.length);

    return Column(
      children: [
        const Text("SHIFT Summary", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _SummaryMetricCard(title: "Duration", value: _getFormattedTime(_sessionSeconds)),
        const SizedBox(height: 12),
        _SummaryMetricCard(title: "Average Heart Rate", value: "${avgBpm.toStringAsFixed(1)} BPM"),
        const SizedBox(height: 12),
        _SummaryMetricCard(title: "Average Blood Oxygen", value: "${avgOxy.toStringAsFixed(1)}%"),
        const SizedBox(height: 12),
        _SummaryMetricCard(title: "Average Body Temp", value: "${avgTemp.toStringAsFixed(1)}°C"),
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

  Widget _buildWarningBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 12),
          Text(message.toUpperCase(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

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