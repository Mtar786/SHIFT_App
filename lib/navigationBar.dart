import 'package:flutter/material.dart';
import 'device_page.dart';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _currentIndex = 0;

  // We move the list into a getter so we can pass the callback properly
  List<Widget> get _pages => [
    // Tab 0: Device Page with the jump logic
    DevicePage(onStartSession: () {
      setState(() {
        _currentIndex = 1; // Jumps to the Session tab
      });
    }),
    const Center(child: Text("Live Session", style: TextStyle(color: Colors.white))), // Tab 1
    const Center(child: Text("History", style: TextStyle(color: Colors.white))),      // Tab 2
    const Center(child: Text("AI Coach", style: TextStyle(color: Colors.white))),     // Tab 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Important: Use the list from the getter
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