import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/conversation_summary.dart';
import '../services/incognito_channel.dart';

class ConversationThreadScreen extends StatelessWidget {
  final ConversationSummary conversation;
  final Uint8List? appIcon;

  const ConversationThreadScreen({
    super.key,
    required this.conversation,
    required this.appIcon,
  });

  @override
  Widget build(BuildContext context) {
    final messages = conversation.items.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _buildAppIcon(context),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                conversation.contactName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${conversation.appName} • ${messages.length} '
              '${messages.length == 1 ? 'message' : 'messages'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SelectionArea(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final item = messages[index];
                  final timeLabel =
                      DateFormat('dd/MM HH:mm').format(item.timestamp);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            item.text.isNotEmpty
                                ? item.text
                                : 'Cette notification ne contient pas de texte.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openSourceApp(context),
                  icon: const Icon(Icons.reply_rounded),
                  label: Text('Répondre dans ${conversation.appName}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon(BuildContext context) {
    if (appIcon != null) {
      return ClipOval(
        child: Image.memory(
          appIcon!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(context),
        ),
      );
    }
    return _fallbackIcon(context);
  }

  Widget _fallbackIcon(BuildContext context) {
    return Icon(
      Icons.chat_bubble_outline_rounded,
      size: 30,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  Future<void> _openSourceApp(BuildContext context) async {
    final opened = await IncognitoChannel.instance.openApp(
      conversation.packageName,
    );

    if (!context.mounted) return;

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${conversation.appName} est introuvable ou n\'est plus installée.',
          ),
        ),
      );
    }
  }
}
