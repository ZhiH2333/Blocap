class Comment {
  final String id;
  String text;
  DateTime timestamp;

  Comment({required this.id, required this.text, required this.timestamp});

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };
}






