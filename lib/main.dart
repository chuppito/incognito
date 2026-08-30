import 'package:flutter/material.dart';

import 'screens/history_screen.dart';

void main() {
  runApp(const IncognitoApp());
}

class IncognitoApp extends StatelessWidget {
  const IncognitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Incognito',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HistoryScreen(),
    );
  }
}
