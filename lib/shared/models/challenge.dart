class Challenge {
  const Challenge({
    required this.id,
    required this.optionA,
    required this.optionB,
    required this.category,
    this.difficulty = 1,
  });

  final String id;
  final String optionA;
  final String optionB;
  final String category;
  final int difficulty;

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      optionA: json['option_a'] as String,
      optionB: json['option_b'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as int? ?? 1,
    );
  }
}
