import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/conversation_summary.dart';
import '../models/notification_item.dart';
import '../services/incognito_channel.dart';

class ConversationThreadScreen extends StatefulWidget {
  final ConversationSummary conversation;
  final Uint8List? appIcon;
  final ValueNotifier<List<NotificationItem>>? history;
  const ConversationThreadScreen(
      {super.key,
      required this.conversation,
      required this.appIcon,
      this.history});
  @override
  State<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState extends State<ConversationThreadScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    if (widget.history == null) return _build(context, widget.conversation);
    return ValueListenableBuilder<List<NotificationItem>>(
      valueListenable: widget.history!,
      builder: (context, items, _) {
        final matches = buildConversations(items)
            .where((c) => c.key == widget.conversation.key);
        return _build(
            context, matches.isEmpty ? widget.conversation : matches.first);
      },
    );
  }

  Widget _build(BuildContext context, ConversationSummary conversation) {
    final colors = Theme.of(context).colorScheme;
    final all = conversation.items.toList()
      ..sort((a, b) {
        final time = b.timestamp.compareTo(a.timestamp);
        return time != 0 ? time : b.id.compareTo(a.id);
      });
    final messages = all
        .where((m) => '${m.sender} ${m.text}'
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(conversation.contactName, overflow: TextOverflow.ellipsis),
          Text('${conversation.appName} • ${all.length} éléments capturés',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        leading: const BackButton(),
      ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher dans cette conversation',
                    border: OutlineInputBorder(),
                    isDense: true))),
        Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('Aucun résultat'))
                : SelectionArea(
                    child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final item = messages[index];
                          final day =
                              DateFormat('dd/MM/yyyy').format(item.timestamp);
                          final showDay = index == messages.length - 1 ||
                              DateFormat('dd/MM/yyyy')
                                      .format(messages[index + 1].timestamp) !=
                                  day;
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showDay)
                                  Center(
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          child: Chip(label: Text(day)))),
                                Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 10, 14, 8),
                                    decoration: BoxDecoration(
                                        color: colors.surfaceContainerLow,
                                        border: Border.all(
                                            color: colors.outlineVariant),
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (item.sender.isNotEmpty)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 6),
                                                child: Text(item.sender,
                                                    style: TextStyle(
                                                        color: colors.primary,
                                                        fontWeight:
                                                            FontWeight.w700))),
                                          if (item.sender.isEmpty &&
                                              item.text.contains('\n'))
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 6),
                                                child: Text(
                                                    'Contenu de la notification',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall)),
                                          Text(
                                              item.text.isEmpty
                                                  ? 'Notification sans texte'
                                                  : item.text,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(height: 1.35)),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                    DateFormat('HH:mm')
                                                        .format(item.timestamp),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall),
                                                IconButton(
                                                    tooltip:
                                                        'Copier le message',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    icon: const Icon(
                                                        Icons.copy_outlined,
                                                        size: 16),
                                                    onPressed: () async {
                                                      await Clipboard.setData(
                                                          ClipboardData(
                                                              text: item.text));
                                                      if (!context.mounted)
                                                        return;
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                              const SnackBar(
                                                                  content: Text(
                                                                      'Message copié')));
                                                    }),
                                              ]),
                                        ])),
                              ]);
                        }))),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                            'Ouvrir ${conversation.appName} pour répondre'),
                        onPressed: () async {
                          final opened = await IncognitoChannel.instance
                              .openApp(conversation.packageName);
                          if (!context.mounted || opened) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Application indisponible')));
                        })))),
      ]),
    );
  }
}
