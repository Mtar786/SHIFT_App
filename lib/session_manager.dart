import 'package:flutter/material.dart';

class SessionItemData {
  final String title;
  final String duration;
  final double avgHrBpm;
  final double avgOxygen;      // New field
  final double avgTemperature; // New field
  final int peakHeatPercent;
  final int alerts;

  SessionItemData({
    required this.title,
    required this.duration,
    required this.avgHrBpm,
    required this.avgOxygen,
    required this.avgTemperature,
    required this.peakHeatPercent,
    required this.alerts,
  });
}

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final List<SessionItemData> _history = [];

  List<SessionItemData> get history => _history;

  void addSession(SessionItemData session) {
    _history.insert(0, session);
    // This will show in your VS Code / Android Studio console
    debugPrint("✅ SESSION SAVED: ${session.title} | Duration: ${session.duration}");
  }
}