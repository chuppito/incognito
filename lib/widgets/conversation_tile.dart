import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/conversation_summary.dart';
import '../models/conversation_messages.dart';
import '../utils/relative_time.dart';
import 'conversation_avatar.dart';

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
    final messages = expandConversationMessages(conversation.items);
    final latest = messages.first;
    final messageCount = messages.length;

    return ListTile(
      onTap: onTap,
      leading: ConversationAvatar(name: conversation.contactName, appIcon: appIcon),
      title: Text(
        conversation.contactName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        latest.text.isNotEmpty
            ? '${conversation.appName} • ${latest.sender.isEmpty ? '' : '${latest.sender} : '}${latest.text}'
            : '${conversation.appName} • (Notification sans texte)',
        maxLines: 2,
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

}
