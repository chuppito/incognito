import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incognito/models/conversation_messages.dart';
import 'package:incognito/models/conversation_summary.dart';
import 'package:incognito/models/notification_item.dart';
import 'package:incognito/screens/conversation_thread_screen.dart';
import 'package:incognito/widgets/conversation_tile.dart';
import 'package:incognito/widgets/message_bubble.dart';

NotificationItem captured(String text, {int id = 1, String package = 'com.whatsapp'}) =>
  NotificationItem(id: id, packageName: package, appName: 'WhatsApp',
    title: 'Groupe test', text: text, timestamp: DateTime(2026, 10, 7, 15, id));

const sixMessages = 'jean DUPONT: 📄 Document.pdf (3 pages)\n'
  'Marie MARTIN: Bonsoir\nVoici la deuxième ligne du même message.\n'
  'Paul DURAND: 🎤 Message vocal (0:03)\n'
  '~ Olivier: Bonjour à tous.\n'
  '~ Olivier: Je réessaie ce midi\n'
  'Marie MARTIN: Merci pour les informations.';

void main() {
  test('Sépare les six messages d’un bloc, sans perdre les lignes ni inventer leurs heures', () {
    final source = captured(sixMessages);
    final messages = expandConversationMessages([source]);
    expect(messages, hasLength(6));
    expect(messages.where((e) => e.sender == '~ Olivier'), hasLength(2));
    expect(messages.any((e) => e.text == 'Bonsoir\nVoici la deuxième ligne du même message.'), isTrue);
    expect(messages.every((e) => !e.timeKnown), isTrue);
    expect(source.text, sixMessages);
  });

  test('Extrait aussi le nom d’un ancien message unique', () {
    final item = expandConversationMessages([captured('Paul DURAND: Bonjour')]).single;
    expect(item.sender, 'Paul DURAND');
    expect(item.text, 'Bonjour');
  });

  test('Ne confond pas une URL, une heure ou un intitulé usuel avec un auteur', () {
    const body = 'Marie MARTIN: Infos\nhttps://example.org\n10:30 départ\nAttention: rester disponible';
    final messages = expandConversationMessages([captured(body)]);
    expect(messages, hasLength(1));
    expect(messages.single.text, contains('Attention: rester disponible'));
    expect(messages.single.text, contains('10:30 départ'));
    expect(expandConversationMessages([captured(sixMessages, package: 'other.app')]), hasLength(1));
  });

  test('Reconnaît une réaction et regroupe ses republications identiques', () {
    const body = 'Paul DURAND: A réagi par 👍 à "Bonjour à tous"';
    final messages = expandConversationMessages([captured(body), captured(body, id: 2)]);
    expect(messages, hasLength(1));
    expect(messages.single.id, 2);
    final reaction = ReactionInfo.parse(messages.single.text)!;
    expect(reaction.emoji, '👍');
    expect(reaction.target, 'Bonjour à tous');
  });

  testWidgets('Le compteur du groupe compte les messages contenus dans l’ancien bloc', (tester) async {
    final conversation = buildConversations([captured(sixMessages)]).single;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ConversationTile(
      conversation: conversation, appIcon: null, onTap: () {}))));
    expect(find.text('Groupe test'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('Un ancien bloc affiche des bulles avec noms et une heure de capture commune', (tester) async {
    final conversation = buildConversations([captured('Marie MARTIN: Bonjour\nPaul DURAND: Bonsoir')]).single;
    await tester.pumpWidget(MaterialApp(home: ConversationThreadScreen(
      conversation: conversation, appIcon: null)));
    expect(find.byType(MessageBubble), findsNWidgets(2));
    expect(find.text('Marie MARTIN'), findsOneWidget);
    expect(find.text('Paul DURAND'), findsOneWidget);
    expect(find.text('Capture du 07/10 15:01'), findsOneWidget);
    expect(find.text('15:01'), findsNothing);
  });
}
