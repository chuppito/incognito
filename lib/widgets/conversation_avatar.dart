import 'dart:typed_data';
import 'package:flutter/material.dart';

class ConversationAvatar extends StatelessWidget {
  final String name;
  final Uint8List? appIcon;
  final double radius;

  const ConversationAvatar({super.key, required this.name, this.appIcon, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2);
    final initials = words.map((e) => e.characters.first.toUpperCase()).join();
    return SizedBox(width: radius * 2, height: radius * 2, child: Stack(children: [
      CircleAvatar(radius: radius, backgroundColor: const Color(0xFFD9EEE8),
        child: Text(initials.isEmpty ? '?' : initials,
          style: TextStyle(color: const Color(0xFF246855), fontSize: radius * 0.66,
            fontWeight: FontWeight.w600))),
      if (appIcon != null) Positioned(right: 0, bottom: 0, child: ClipOval(
        child: Image.memory(appIcon!, width: radius * 0.7, height: radius * 0.7,
          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      )),
    ]));
  }
}
