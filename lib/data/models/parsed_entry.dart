/// The structured result of parsing a voice/text expense entry with Gemini.
class ParsedEntry {
  final double amount;
  final String category;
  final String description;
  final DateTime date;

  const ParsedEntry({
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });

  factory ParsedEntry.fromJson(Map<String, dynamic> json) {
    return ParsedEntry(
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }

  ParsedEntry copyWith({
    double? amount,
    String? category,
    String? description,
    DateTime? date,
  }) {
    return ParsedEntry(
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }

  @override
  String toString() =>
      'ParsedEntry(amount: $amount, category: $category, '
      'description: $description, date: $date)';
}
