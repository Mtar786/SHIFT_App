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

  final GlobalKey<LiveSessionScreenState> _sessionKey = GlobalKey();

  void _unlockAndStart() {
    setState(() {
      _isUnlocked = true;
      _currentIndex = 1; // Auto-navigate to session
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionKey.currentState?.startTimer();
    });
  }

  List<Widget> get _pages => [
    DevicePage(onStartSession: _unlockAndStart), // Pass the new function
    LiveSessionScreen(key: _sessionKey),
    HistoryScreen(key: ValueKey('history_tab_$_currentIndex')),
    const AIChatbot(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index){
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            // Change icon based on lock state
            icon: Icon(_isUnlocked ? Icons.timeline : Icons.lock_outline),
            label: 'Session',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Coach'),
        ],
      ),
    );
  }
}
