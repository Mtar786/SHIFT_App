import 'package:flutter/material.dart';
import 'session_manager.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final sessions = SessionManager().history;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Session History',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Sessions: ${sessions.length}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: sessions.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildSessionTile(sessions[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        "No sessions recorded.\nGo to 'Session' and hit 'End Session'.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildSessionTile(SessionItemData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14161B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232633)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date and Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(data.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(data.duration, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          // Single Row for all critical metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniMetric("Avg HR", "${data.avgHrBpm.toStringAsFixed(1)}"),
              _miniMetric("O2", "${data.avgOxygen.toStringAsFixed(1)}%"),
              _miniMetric("Temp", "${data.avgTemperature.toStringAsFixed(1)}°"),
              _miniMetric("Alerts", "${data.alerts}", isRed: data.alerts > 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, {bool isRed = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isRed ? Colors.redAccent : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          )
        ),
      ],
    );
  }
}