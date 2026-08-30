import 'package:flutter/material.dart';

import '../models/installed_app.dart';

class AppTile extends StatelessWidget {
  final InstalledApp app;
  final bool isListened;
  final bool showsSystemNotification;
  final ValueChanged<bool> onListenedChanged;
  final ValueChanged<bool> onNotifyChanged;

  const AppTile({
    super.key,
    required this.app,
    required this.isListened,
    required this.showsSystemNotification,
    required this.onListenedChanged,
    required this.onNotifyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: app.icon != null
                ? Image.memory(app.icon!, width: 40, height: 40)
                : Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.apps, size: 20),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              app.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Column(
            children: [
              const Text('Écouter', style: TextStyle(fontSize: 11)),
              Switch(
                value: isListened,
                onChanged: onListenedChanged,
              ),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              const Text('Notif.', style: TextStyle(fontSize: 11)),
              Switch(
                value: isListened && showsSystemNotification,
                onChanged: isListened ? onNotifyChanged : null,
                activeColor: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
