enum ChatRole { user, assistant }

/// One message in the conversation with the personal assistant
class ChatMessage {
  final ChatRole role;
  final String text;
  final String? displayText;
  final DateTime createdAt;
  final bool isError;

  ChatMessage({
    required this.role,
    required this.text,
    this.displayText,
    DateTime? createdAt,
    this.isError = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == ChatRole.user;

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    if (displayText != null) 'displayText': displayText,
    'createdAt': createdAt.toIso8601String(),
    'isError': isError,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
      text: json['text'] as String? ?? '',
      displayText: json['displayText'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isError: json['isError'] as bool? ?? false,
    );
  }
}
