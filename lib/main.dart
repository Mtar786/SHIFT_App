import 'package:flutter/material.dart';
import 'navigationBar.dart';

void main() => runApp(const ShiftApp());


class ShiftApp extends StatelessWidget {
  const ShiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHIFT Performance',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.blue,
      ),
      home: const NavigationWrapper(),
    );
  }
}
