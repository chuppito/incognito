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

/// Certaines apps (WhatsApp notamment) ajoutent un compteur au titre quand
/// les messages non lus s'accumulent, ex. "Infos CIS LGS (78 messages)" ou
/// "Marie (3)". On retire ce suffixe pour que le regroupement reste stable
/// dans le temps : sinon la même conversation se scinde en plusieurs lignes
/// à chaque fois que le compteur change.
String _cleanContactName(String title) {
  final cleaned = title
      .replaceAll(
        RegExp(r'\s*\(\d+(\s*messages?)?\)\s*$', caseSensitive: false),
        '',
      )
      .trim();
  return cleaned.isNotEmpty ? cleaned : title.trim();
}

/// Regroupe une liste d'items (déjà triée du plus récent au plus ancien)
/// par conversation. On priorise le nom de contact nettoyé (stable dans le
/// temps) plutôt que `conversationKey` (le groupKey Android peut changer
/// d'une notification à l'autre pour un même contact).
List<ConversationSummary> buildConversations(List<NotificationItem> items) {
  final grouped = <String, List<NotificationItem>>{};
  final order = <String>[];
  final displayNames = <String, String>{};

  for (final item in items) {
    final rawName = item.title.isNotEmpty ? item.title : item.appName;
    final cleanedName = _cleanContactName(rawName);

    final key = cleanedName.isNotEmpty
        ? '${item.packageName}|name:${cleanedName.toLowerCase()}'
        : (item.conversationKey.isNotEmpty
            ? item.conversationKey
            : '${item.packageName}|id:${item.id}');

    if (!grouped.containsKey(key)) {
      grouped[key] = [];
      order.add(key);
      displayNames[key] = cleanedName.isNotEmpty ? cleanedName : rawName;
    }
    grouped[key]!.add(item);
  }

  return order.map((key) {
    final list = grouped[key]!;
    final latest = list.first;
    return ConversationSummary(
      key: key,
      contactName: displayNames[key]!,
      packageName: latest.packageName,
      appName: latest.appName,
      items: list,
    );
  }).toList();
}
