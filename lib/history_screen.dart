import 'package:flutter/material.dart';
import 'session_manager.dart';

class HistoryScreen extends StatefulWidget {
  // The 'super.key' allows the ValueKey from the Navigator to work
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(data.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(data.duration, style: const TextStyle(color: Colors.blueAccent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniMetric("Avg HR", "${data.avgHrBpm}"),
              _miniMetric("Heat", "${data.peakHeatPercent}%"),
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(value, style: TextStyle(color: isRed ? Colors.red : Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}