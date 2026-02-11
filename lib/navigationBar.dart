import 'package:flutter/material.dart';
import 'history_screen.dart';
import 'live_session_screen.dart';
import 'ai_chatbot.dart';
// import 'device_page.dart'; // Uncomment this when you use it

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _currentIndex = 0;

  // We use a getter here so the ValueKey updates based on the current index
  List<Widget> get _pages => [
        // Tab 0: Home/Device (Placeholder for now)
        const Center(child: Text("Home Page", style: TextStyle(color: Colors.white))),

        // Tab 1: Live Session
        const LiveSessionScreen(),

        // Tab 2: History (KEY CHANGE HERE: remove 'const' and add 'key')
        HistoryScreen(key: ValueKey('history_tab_$_currentIndex')),

        // Tab 3: AI Coach
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
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Session'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Coach'),
        ],
      ),
    );
  }
}