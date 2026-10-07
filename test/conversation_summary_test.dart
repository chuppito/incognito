import 'package:flutter_test/flutter_test.dart';
import 'package:incognito/models/conversation_summary.dart';
import 'package:incognito/models/notification_item.dart';

NotificationItem item(int id, String title, String key,
        {String package = 'com.whatsapp'}) =>
    NotificationItem(
        id: id,
        title: title,
        conversationKey: key,
        packageName: package,
        appName: 'WhatsApp',
        text: 'Texte\navec retour à la ligne',
        sender: 'Auteur',
        timestamp: DateTime.fromMillisecondsSinceEpoch(id * 1000));

void main() {
  test(
      'sorts messages and joins old Android group keys to a single identified conversation',
      () {
    final result = buildConversations([
      item(1, 'Groupe (3 messages)', 'com.whatsapp|group:old'),
      item(3, 'Groupe', 'com.whatsapp|shortcut:42'),
      item(2, 'Groupe', 'com.whatsapp|group:new'),
    ]);
    expect(result.length, 1);
    expect(result.single.items.map((e) => e.id), [3, 2, 1]);
    expect(result.single.contactName, 'Groupe');
    expect(result.single.latest.sender, 'Auteur');
    expect(result.single.latest.text, 'Texte\navec retour à la ligne');
  });
  test('keeps groups with the same name and distinct shortcuts separate', () {
    expect(
        buildConversations([
          item(1, 'Groupe', 'com.whatsapp|shortcut:1'),
          item(2, 'Groupe', 'com.whatsapp|shortcut:2'),
        ]).length,
        2);
  });
  test('keeps applications separate', () {
    expect(
        buildConversations([
          item(1, 'Marie', ''),
          item(2, 'Marie', '', package: 'org.telegram.messenger'),
        ]).length,
        2);
  });
  test('reads older rows without a sender', () {
    expect(NotificationItem.fromMap({'id': 1, 'timestamp': 1000}).sender, '');
  });
}
