class Message {
  final String text;
  final bool isUser;
  final List<Map<String, String>>? attachments;
  
  Message({
    required this.text, 
    required this.isUser,
    this.attachments,});

  Map<String, dynamic> toJson() => {
    'text': text, 
    'isUser': isUser,
    'attachments': attachments,
    };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
          text: json['text'] ?? '',
          isUser: json['isUser'] ?? false,
          attachments: (json['attachments'] as List?)
            ?.map((e) => Map<String, String>.from(e))
            .toList(),
            );
}