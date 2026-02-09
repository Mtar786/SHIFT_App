// lib/screens/history_screen.dart
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder values (use variables, not fixed UI text)
    final int totalSessions = 5;
    final int avgDurationMinutes = 49;

    final List<SessionItemData> sessions = <SessionItemData>[
      SessionItemData(
        title: 'Today, 2:30 PM',
        duration: '45:32',
        avgHrBpm: 148,
        peakHeatPercent: 78,
        alerts: 3,
      ),
      SessionItemData(
        title: 'Yesterday, 10:15 AM',
        duration: '62:18',
        avgHrBpm: 142,
        peakHeatPercent: 65,
        alerts: 1,
      ),
    ];

    final List<Widget> sessionTiles = sessions.map(_buildSessionTile).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Session History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Review your past performance data',
                style: TextStyle(
                  color: Color(0xFFA7ABB3),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              // Stats cards row
              Row(
                children: <Widget>[
                  Expanded(
                    child: _StatCard(
                      icon: Icons.analytics_outlined,
                      label: 'Total Sessions',
                      value: '$totalSessions',
                      valueSuffix: '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.schedule,
                      label: 'Avg Duration',
                      value: '$avgDurationMinutes',
                      valueSuffix: 'minutes',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Session list
              Expanded(
                child: ListView.separated(
                  itemCount: sessionTiles.length,
                  separatorBuilder: (BuildContext context, int index) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    return sessionTiles[index];
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTile(SessionItemData data) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14161B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232633)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // TODO: Navigate to session detail screen
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Title row
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Color(0xFFA7ABB3),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFA7ABB3),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Duration: ${data.duration}',
                style: const TextStyle(
                  color: Color(0xFFA7ABB3),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),

              // Metrics row (Avg HR / Peak Heat / Alerts)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _SmallMetric(
                    label: 'Avg HR',
                    value: '${data.avgHrBpm} BPM',
                    valueColor: Colors.white,
                  ),
                  _SmallMetric(
                    label: 'Peak Heat',
                    value: '${data.peakHeatPercent}%',
                    valueColor: Colors.white,
                  ),
                  _SmallMetric(
                    label: 'Alerts',
                    value: '${data.alerts}',
                    valueColor: const Color(0xFFFF5252),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SessionItemData {
  SessionItemData({
    required this.title,
    required this.duration,
    required this.avgHrBpm,
    required this.peakHeatPercent,
    required this.alerts,
  });

  final String title;
  final String duration;
  final int avgHrBpm;
  final int peakHeatPercent;
  final int alerts;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueSuffix,
  });

  final IconData icon;
  final String label;
  final String value;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final List<Widget> valueLine = <Widget>[
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];

    if (valueSuffix.isNotEmpty) {
      valueLine.add(const SizedBox(width: 6));
      valueLine.add(
        Text(
          valueSuffix,
          style: const TextStyle(
            color: Color(0xFFA7ABB3),
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14161B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232633)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: const Color(0xFF3DDC97)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFA7ABB3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: valueLine),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFA7ABB3),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
