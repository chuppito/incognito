import '../models/notification_item.dart';

class ConversationSummary {
  final String key;
  final String contactName;
  final String packageName;
  final String appName;

  /// Messages de cette conversation, du plus récent au plus ancien.
  final List<NotificationItem> items;

  ConversationSummary({
    required this.key,
    required this.contactName,
    required this.packageName,
    required this.appName,
    required this.items,
  });

  NotificationItem get latest => items.first;
}

/// Regroupe une liste d'items (déjà triée du plus récent au plus ancien)
/// par conversation : par `conversationKey` quand elle est disponible
/// (thread WhatsApp/Telegram détecté), sinon par contact (titre) + app.
List<ConversationSummary> buildConversations(List<NotificationItem> items) {
  final grouped = <String, List<NotificationItem>>{};
  final order = <String>[];

  for (final item in items) {
    final key = item.conversationKey.isNotEmpty
        ? item.conversationKey
        : '${item.packageName}|title:${item.title}';

    if (!grouped.containsKey(key)) {
      grouped[key] = [];
      order.add(key);
    }
    grouped[key]!.add(item);
  }

  return order.map((key) {
    final list = grouped[key]!;
    final latest = list.first;
    return ConversationSummary(
      key: key,
      contactName: latest.title.isNotEmpty ? latest.title : latest.appName,
      packageName: latest.packageName,
      appName: latest.appName,
      items: list,
    );
  }).toList();
}
