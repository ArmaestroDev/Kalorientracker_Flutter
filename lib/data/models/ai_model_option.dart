class AiModelOption {
  final String id;
  final String label;
  final bool free;

  const AiModelOption({
    required this.id,
    required this.label,
    required this.free,
  });

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'free': free};

  factory AiModelOption.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is String ? rawId : '';
    final rawLabel = json['label'];
    final label = rawLabel is String ? rawLabel : id;
    final rawFree = json['free'];
    return AiModelOption(
      id: id,
      label: label,
      free: rawFree is bool ? rawFree : false,
    );
  }

  @override
  bool operator ==(Object other) => other is AiModelOption && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => label;
}
