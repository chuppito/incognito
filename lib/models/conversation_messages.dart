import 'notification_item.dart';

/// Présentation des anciens textes WhatsApp aplatis. Le contenu SQLite reste intact.
List<NotificationItem> expandConversationMessages(List<NotificationItem> sources) {
  final result = <NotificationItem>[];
  for (final item in sources) {
    if (item.sender.isNotEmpty || item.structured ||
        !{'com.whatsapp', 'com.whatsapp.w4b'}.contains(item.packageName)) {
      result.add(item);
      continue;
    }
    final lines = item.text.split('\n');
    final parts = <({String sender, String text})>[];
    String sender = '';
    final body = <String>[];
    void flush() {
      if (body.isNotEmpty) {
        parts.add((sender: sender, text: body.join('\n').trim()));
        body.clear();
      }
    }
    for (final line in lines) {
      final match = _senderHeader.firstMatch(line);
      final name = match?.group(1)?.trim();
      if (match != null && name != null && _plausibleSender(name)) {
        flush();
        sender = name;
        body.add(match.group(2)!);
      } else {
        body.add(line);
      }
    }
    flush();
    // Pas de nom reconnu : afficher le texte original sans transformation.
    if (!parts.any((part) => part.sender.isNotEmpty)) {
      result.add(item);
      continue;
    }
    for (var index = 0; index < parts.length; index++) {
      final part = parts[index];
      result.add(NotificationItem(id: item.id, packageName: item.packageName,
        appName: item.appName, title: item.title, conversationKey: item.conversationKey,
        timestamp: item.timestamp, sender: part.sender, text: part.text,
        timeKnown: parts.length == 1, displayIndex: index));
    }
  }
  result.sort((a, b) {
    final time = b.timestamp.compareTo(a.timestamp);
    if (time != 0) return time;
    final id = b.id.compareTo(a.id);
    return id != 0 ? id : b.displayIndex.compareTo(a.displayIndex);
  });
  // Une réaction republiée plusieurs fois apparaît une fois, à sa dernière capture.
  final reactions = <String>{};
  return result.where((item) {
    final reaction = ReactionInfo.parse(item.text);
    if (reaction == null) return true;
    return reactions.add('${item.sender}\u0000${reaction.emoji}\u0000${reaction.target}');
  }).toList();
}

final _senderHeader = RegExp(
  r'^\s*([~+A-Za-zÀ-ÖØ-öø-ÿ0-9][~+A-Za-zÀ-ÖØ-öø-ÿ0-9 ._’\x27()\-]{0,79}):\s+(.+)$');

bool _plausibleSender(String name) {
  const excluded = {'http', 'https', 'objet', 'attention', 'note', 'pour info',
    'information', 'rappel', 'important', 'message', 'bonjour', 'bonsoir',
    'adresse', 'date', 'heure', 'urgence', 'suite', 'exemple'};
  if (excluded.contains(name.toLowerCase())) return false;
  return RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(name) ||
    RegExp(r'^\+?[\d .()-]{6,}$').hasMatch(name);
}

class ReactionInfo {
  final String emoji;
  final String target;
  ReactionInfo(this.emoji, this.target);

  static ReactionInfo? parse(String text) {
    final match = RegExp(r'^A réagi par\s+(.+?)\s+à\s+["“](.*)["”]\s*$',
      caseSensitive: false, dotAll: true).firstMatch(text.trim());
    return match == null ? null : ReactionInfo(match.group(1)!, match.group(2)!);
  }
}
