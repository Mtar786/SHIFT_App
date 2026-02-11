import 'package:flutter/material.dart';
import 'device_page.dart';
import 'history_screen.dart';
import 'live_session_screen.dart';
import 'ai_chatbot.dart'; 



class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _currentIndex = 0;

  List<Widget> get _pages => [
        // Tab 0: Device Page
        DevicePage(
          onStartSession: () {
            setState(() {
              _currentIndex = 1; // Jump to Session tab
            });
          },
        ),

        // Tab 1: Live Session
        const LiveSessionScreen(),


        // Tab 2: History Page (REAL implementation)
        const HistoryScreen(),

        // Tab 3: AI Coach (placeholder for now)
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
