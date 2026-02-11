import 'dart:async';
import 'package:flutter/material.dart';
import 'session_manager.dart';
import 'package:intl/intl.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key});

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  // ---------------------------------------------------------------------------
  // STATE VARIABLES
  // ---------------------------------------------------------------------------
  bool isLiveSession = true;
  Timer? _timer;

  int _sessionSeconds = 0;
  bool showWarning = true;

  // Mock data for the summary view
  final String _mockAvgHr = "132 bpm";
  final String _mockMaxHr = "165 bpm";
  final String _mockAvgTemp = "37.5°C";
  final String _mockAvgBp = "120/80 mmHg";

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

  void startTimer() {
    _timer?.cancel();
    setState(() {
      _sessionSeconds = 0;
      isLiveSession = true;
      showWarning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionSeconds++;
        });
      }
    });
  }


// Inside _LiveSessionScreenState
void endSession() {
  _timer?.cancel();

  // 1. Capture the data from the current session
  final newSession = SessionItemData(
    title: DateFormat('MMM d, h:mm a').format(DateTime.now()), // e.g. Feb 11, 2:33 PM
    duration: getFormattedTime(_sessionSeconds),
    avgHrBpm: 148, // Replace with your real logic later
    peakHeatPercent: 70, // Replace with your real logic later
    alerts: showWarning ? 1 : 0,
  );

  // 2. Save it to our Manager
  SessionManager().addSession(newSession);

  setState(() {
    isLiveSession = false;
  });
}

  String getFormattedTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // Wrap everything in a ScrollView so the whole page scrolls
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: isLiveSession ? _buildLiveView() : _buildSummaryView(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW 1: LIVE SESSION (SCROLLABLE)
  // ---------------------------------------------------------------------------
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
                const Text(
                  'Live Session',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white
                  ),
                ),
                const SizedBox(height: 4),
                // Timer
                Text(
                  getFormattedTime(_sessionSeconds),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A5CFF), // Bright Blue
                  ),
                ),
              ],
            ),
            Row(
              children: const [
                Icon(Icons.circle, color: Colors.red, size: 12),
                SizedBox(width: 8),
                Text('Recording', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Warning Banner
        if (showWarning)
          Container(
            margin: const EdgeInsets.only(bottom: 20), // Add spacing if visible
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3D210B), // Dark Brown/Orange bg
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD67B18)), // Orange border
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD67B18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Heat Stress Warning',
                        style: TextStyle(
                          color: Color(0xFFD67B18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your heat stress level is elevated. Consider slowing down and hydrating.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => showWarning = false),
                  child: const Icon(Icons.close, color: Color(0xFFD67B18), size: 20),
                ),
              ],
            ),
          ),

        // Metrics Grid
        // Note: No 'Expanded' here. Just let the Column grow.
        Row(
          children: const [
            Expanded(
              child: _LiveMetricCard(
                title: 'Heart Rate',
                value: '148',
                unit: 'BPM',
                status: 'Elevated',
                icon: Icons.favorite_border,
                color: Color(0xFFD67B18), // Orange
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _LiveMetricCard(
                title: 'Blood O₂',
                value: '97',
                unit: '%',
                status: 'Good',
                icon: Icons.water_drop_outlined,
                color: Color(0xFF007F5F), // Green
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(
              child: _LiveMetricCard(
                title: 'Heat Stress',
                value: '68',
                unit: '%',
                status: 'Warning',
                icon: Icons.thermostat,
                color: Color(0xFFD67B18), // Orange
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _LiveMetricCard(
                title: 'Breathing',
                value: '25',
                unit: 'BrPM',
                status: 'Normal',
                icon: Icons.air,
                color: Color(0xFF007F5F), // Green
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Activity Intensity
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD67B18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.show_chart, color: Color(0xFFD67B18)),
                      SizedBox(width: 8),
                      Text('Activity Intensity', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Text('70%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(
                  value: 0.7,
                  backgroundColor: Color(0xFF13181D),
                  color: Color(0xFFD67B18),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              const Text('High', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),

        const SizedBox(height: 32), // Space before button

        // End Session Button (At the very bottom of the scrollable list)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: endSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD30000), // Red
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'End Session',
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 20), // Bottom padding for safety
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW 2: SESSION SUMMARY (SCROLLABLE)
  // ---------------------------------------------------------------------------
  Widget _buildSummaryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHIFT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
            letterSpacing: 1.2
          )
        ),
        const SizedBox(height: 20),

        // Main Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF13181D), // Dark Card Bg
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Session Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white
                )
              ),
              const SizedBox(height: 24),

              // Metrics
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetricCard(
                      title: 'Duration',
                      value: getFormattedTime(_sessionSeconds),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryMetricCard(
                      title: 'Avg Heart Rate',
                      value: _mockAvgHr,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetricCard(
                      title: 'Max Heart Rate',
                      value: _mockMaxHr,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryMetricCard(
                      title: 'Avg Temperature',
                      value: _mockAvgTemp,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SummaryMetricCard(
                title: 'Avg Blood Pressure',
                value: _mockAvgBp,
                isWide: true,
              ),

              const SizedBox(height: 32), // Space before button

              // Start New Session Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: startTimer, // Go back to live view & restart
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5CFF), // Blue
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Start New Session',
                    style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20), // Bottom padding
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
// -----------------------------------------------------------------------------

class _LiveMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String status;
  final IconData icon;
  final Color color;

  const _LiveMetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
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
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Color(0xFF8A94A6))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(unit, style: const TextStyle(color: Color(0xFF8A94A6), fontSize: 12)),
              const Text(' • ', style: TextStyle(color: Color(0xFF8A94A6))),
              Text(status, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isWide;

  const _SummaryMetricCard({
    required this.title,
    required this.value,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isWide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252A30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF8A94A6), fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}