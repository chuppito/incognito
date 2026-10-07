import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incognito/models/conversation_summary.dart';
import 'package:incognito/models/notification_item.dart';
import 'package:incognito/screens/conversation_thread_screen.dart';

void main() {
  testWidgets('separates authors and filters messages, then updates while open',
      (tester) async {
    NotificationItem message(int id, String sender, String text) =>
        NotificationItem(
            id: id,
            sender: sender,
            text: text,
            title: 'Groupe',
            appName: 'WhatsApp',
            packageName: 'com.whatsapp',
            timestamp: DateTime(2026, 10, 7, 15, id));
    final history = ValueNotifier(
        [message(2, 'Karine', 'Bonsoir'), message(1, 'Jérôme', 'Note jointe')]);
    await tester.pumpWidget(MaterialApp(
        home: ConversationThreadScreen(
            conversation: buildConversations(history.value).single,
            appIcon: null,
            history: history)));
    expect(find.text('Karine'), findsOneWidget);
    expect(find.text('Jérôme'), findsOneWidget);
    expect(find.text('Bonsoir'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Note');
    await tester.pump();
    expect(find.text('Bonsoir'), findsNothing);
    expect(find.text('Note jointe'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    history.value = [
      message(3, 'Olivier', 'Nouveau message'),
      ...history.value
    ];
    await tester.pump();
    expect(find.text('Nouveau message'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    history.dispose();
  });
}
