import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notification_item.dart';

Color senderColor(String name, bool dark) {
  const light = [Color(0xFF1565C0), Color(0xFF6A43B9), Color(0xFF008577),
    Color(0xFFAD4E16), Color(0xFFB02F6A), Color(0xFF447528)];
  const night = [Color(0xFF8AB4F8), Color(0xFFB9A0F4), Color(0xFF7FD3C4),
    Color(0xFFF3B68F), Color(0xFFF2A0C5), Color(0xFFACD88F)];
  final value = name.runes.fold<int>(0, (sum, rune) => sum + rune);
  return (dark ? night : light)[value % light.length];
}

class MessageBubble extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onLongPress;

  const MessageBubble({super.key, required this.item, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = senderColor(item.sender, dark);
    return LayoutBuilder(builder: (context, constraints) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 36, child: item.sender.isEmpty ? null : CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(dark ? 0.25 : 0.16),
            child: Text(item.sender.characters.first.toUpperCase(),
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 6),
          Flexible(child: GestureDetector(
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: (constraints.maxWidth - 42) * 0.94),
              child: Container(
                padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF202C33) : Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(3),
                    topRight: Radius.circular(12), bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                    blurRadius: 2, offset: const Offset(0, 1))],
                ),
                child: IntrinsicWidth(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item.sender.isNotEmpty) Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(item.sender, style: TextStyle(color: color,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    SelectableText(item.text.isEmpty ? 'Notification sans texte.' : item.text,
                      style: TextStyle(color: dark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                        fontSize: 17, height: 1.25)),
                    const SizedBox(height: 3),
                    Align(alignment: Alignment.centerRight,
                      child: Text(DateFormat('HH:mm').format(item.timestamp),
                        style: TextStyle(fontSize: 11,
                          color: dark ? const Color(0xFF8696A0) : const Color(0xFF667781)))),
                  ],
                )),
              ),
            ),
          )),
        ]),
      );
    });
  }
}
