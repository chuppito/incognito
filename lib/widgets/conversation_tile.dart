import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/conversation_summary.dart';
import '../utils/relative_time.dart';

class ConversationTile extends StatelessWidget {
  final ConversationSummary conversation;
  final Uint8List? appIcon;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.appIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final latest = conversation.latest;
    final messageCount = conversation.items.length;

    return ListTile(
      onTap: onTap,
      leading: _buildAvatar(context),
      title: Text(
        conversation.contactName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        latest.text.isNotEmpty
            ? '${conversation.appName} • ${latest.text}'
            : '${conversation.appName} • (Notification sans texte)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatRelativeTime(latest.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (messageCount > 1) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$messageCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    if (appIcon != null) {
      return ClipOval(
        child: Image.memory(
          appIcon!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _letterAvatar(context),
        ),
      );
    }
    return _letterAvatar(context);
  }

  Widget _letterAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        conversation.contactName.isNotEmpty
            ? conversation.contactName[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
