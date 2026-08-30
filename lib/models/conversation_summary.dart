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

/// Nettoie les compteurs ajoutés par certaines messageries aux titres,
/// par exemple "Marie (3)" ou "Infos CIS LGS (78 messages)".
String cleanContactName(String title) {
  final cleaned = title
      .replaceAll(
        RegExp(r'\s*\(\d+(\s*messages?)?\)\s*$', caseSensitive: false),
        '',
      )
      .trim();
  return cleaned.isNotEmpty ? cleaned : title.trim();
}

String _normalizeName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

/// Regroupe les notifications par contact/conversation.
///
/// Stratégie robuste :
/// - le nom nettoyé est utilisé pour garder ensemble les notifications d'un
///   même contact lorsque Android change son groupKey ;
/// - si plusieurs conversationKey distinctes existent pour le même nom,
///   elles sont séparées afin d'éviter de fusionner deux conversations portant
///   le même nom (par exemple deux groupes ayant le même titre) ;
/// - si aucun nom exploitable n'est disponible, conversationKey est utilisé ;
/// - les conversations restent ordonnées selon leur dernière notification.
List<ConversationSummary> buildConversations(List<NotificationItem> items) {
  final nameKeys = <String, Set<String>>{};

  for (final item in items) {
    final rawName = item.title.isNotEmpty ? item.title : item.appName;
    final name = cleanContactName(rawName);
    final normalizedName = _normalizeName(name);

    if (normalizedName.isEmpty) continue;

    final base = '${item.packageName}|name:$normalizedName';
    final conversationKey = item.conversationKey.trim();

    if (conversationKey.isNotEmpty) {
      nameKeys.putIfAbsent(base, () => <String>{}).add(conversationKey);
    } else {
      nameKeys.putIfAbsent(base, () => <String>());
    }
  }

  final grouped = <String, List<NotificationItem>>{};
  final order = <String>[];
  final displayNames = <String, String>{};

  for (final item in items) {
    final rawName = item.title.isNotEmpty ? item.title : item.appName;
    final name = cleanContactName(rawName);
    final normalizedName = _normalizeName(name);
    final base = '${item.packageName}|name:$normalizedName';
    final keys = nameKeys[base] ?? <String>{};
    final conversationKey = item.conversationKey.trim();

    String key;
    if (normalizedName.isNotEmpty && keys.length <= 1) {
      // Cas normal : le nom suffit et reste stable même si Android modifie
      // son groupKey.
      key = base;
    } else if (normalizedName.isNotEmpty && conversationKey.isNotEmpty) {
      // Même nom mais plusieurs conversations distinctes : on les sépare.
      key = '$base|conversation:$conversationKey';
    } else if (conversationKey.isNotEmpty) {
      key = '${item.packageName}|conversation:$conversationKey';
    } else {
      // Dernier recours : chaque notification sans identité exploitable reste
      // indépendante.
      key = '${item.packageName}|id:${item.id}';
    }

    grouped.putIfAbsent(key, () {
      order.add(key);
      displayNames[key] = name.isNotEmpty ? name : rawName;
      return <NotificationItem>[];
    }).add(item);
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
