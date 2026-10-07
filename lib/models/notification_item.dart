class NotificationItem {
  final int id;
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final DateTime timestamp;
  final String conversationKey;
  final String sender;
  final bool structured;
  final bool timeKnown;
  final int displayIndex;

  NotificationItem({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.timestamp,
    this.conversationKey = '',
    this.sender = '',
    this.structured = false,
    this.timeKnown = true,
    this.displayIndex = 0,
  });

  factory NotificationItem.fromMap(Map<dynamic, dynamic> map) {
    return NotificationItem(
      id: (map['id'] as num).toInt(),
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num).toInt(),
      ),
      conversationKey: map['conversationKey'] as String? ?? '',
      sender: map['sender'] as String? ?? '',
      structured: map['structured'] == true,
    );
  }
}

