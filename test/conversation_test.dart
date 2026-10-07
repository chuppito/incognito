import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incognito/models/conversation_summary.dart';
import 'package:incognito/models/notification_item.dart';
import 'package:incognito/screens/conversation_thread_screen.dart';
import 'package:incognito/widgets/message_bubble.dart';

NotificationItem message(int id, {String sender = 'Marie', String text = 'Bonjour',
  String package = 'com.whatsapp', String key = 'group-a', int minute = 0}) => NotificationItem(
    id: id, packageName: package, appName: 'WhatsApp', title: 'Mon groupe',
    text: text, sender: sender, conversationKey: key,
    timestamp: DateTime(2026, 10, 7, 12, minute), structured: true);

void main() {
  test('Trie les messages et préserve deux textes identiques à des heures différentes', () {
    final conversations = buildConversations([message(1), message(2, minute: 1)]);
    expect(conversations, hasLength(1));
    expect(conversations.single.items.map((e) => e.id), [2, 1]);
  });

  test('Sépare deux groupes de même nom et deux applications', () {
    final conversations = buildConversations([
      message(1), message(2, key: 'group-b'), message(3, package: 'org.telegram.messenger'),
    ]);
    expect(conversations, hasLength(3));
  });

  test('Lit un ancien enregistrement sans modifier son contenu', () {
    final item = NotificationItem.fromMap({
      'id': 1, 'timestamp': 1000, 'text': 'Première ligne\nPaul: deuxième ligne',
    });
    expect(item.sender, isEmpty);
    expect(item.structured, isFalse);
    expect(item.text, 'Première ligne\nPaul: deuxième ligne');
  });

  testWidgets('Affiche les expéditeurs séparément et conserve les retours à la ligne', (tester) async {
    final conversation = buildConversations([
      message(1, sender: 'Marie', text: 'Bonjour\nDeuxième ligne'),
      message(2, sender: 'Paul', text: 'Bonsoir', minute: 1),
    ]).single;
    await tester.pumpWidget(MaterialApp(home: ConversationThreadScreen(
      conversation: conversation, appIcon: null)));
    expect(find.byType(MessageBubble), findsNWidgets(2));
    expect(find.text('Marie'), findsOneWidget);
    expect(find.text('Paul'), findsOneWidget);
    expect(find.text('Bonjour\nDeuxième ligne'), findsOneWidget);
    expect(find.text('Bonsoir'), findsOneWidget);
    expect(find.text('Mon groupe'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    await tester.tap(find.byTooltip('Rechercher dans la conversation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Paul');
    await tester.pump();
    expect(find.text('Bonsoir'), findsOneWidget);
    expect(find.text('Bonjour\nDeuxième ligne'), findsNothing);
  });
}
