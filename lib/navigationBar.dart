import 'package:flutter/material.dart';
import 'history_screen.dart';
import 'live_session_screen.dart';
import 'ai_chatbot.dart';
import 'device_page.dart';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _currentIndex = 0;
  bool _isUnlocked = false;

  // --- SHARED SENSOR DATA ---
  // These variables hold the values parsed from the JSON
  double _bpm = 0.0;
  double _oxygen = 0.0;
  double _temperature = 0.0;
  int _quality = 0;
  String _alarms = "OK";

  final GlobalKey<LiveSessionScreenState> _sessionKey = GlobalKey();

  // This is the function called by DevicePage whenever a new BLE packet arrives
  void _handleDataUpdate(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      // Keys: "o" -> Oxygen, "t" -> Temp, "q" -> Quality, "a" -> Alarms, "b" -> Battery
      _bpm = (data['b'] ?? 0.0).toDouble();
      _oxygen = (data['o'] ?? 0.0).toDouble();
      _temperature = (data['t'] ?? 0.0).toDouble();
      _quality = (data['q'] ?? 0).toInt();

      if (data['a'] != null && (data['a'] as List).isNotEmpty) {
        _alarms = data['a'][0].toString();
      }
    });
  }

  void _unlockAndStart() {
    setState(() {
      _isUnlocked = true;
      _currentIndex = 1; // Auto-navigate to session
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionKey.currentState?.startTimer();
    });
  }

  // We define the pages inside build so they receive the updated variables
  List<Widget> _getPages() {
    return [
      DevicePage(
        onStartSession: _unlockAndStart,
        onDataReceived: _handleDataUpdate, // Pass the callback
      ),
      LiveSessionScreen(
        key: _sessionKey,
        bpm: _bpm,
        oxygen: _oxygen,       // Pass live data down
        temperature: _temperature,
        quality: _quality,
        alarms: _alarms,
      ),
      HistoryScreen(key: ValueKey('history_tab_$_currentIndex')),
      const AIChatbot(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _getPages(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1 && !_isUnlocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Connect device and click 'Start Session' first"),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(_isUnlocked ? Icons.timeline : Icons.lock_outline),
            label: 'Session',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Coach'),
        ],
      ),
    );
  }
}