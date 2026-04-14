class FundItem {
  const FundItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.status,
    required this.notes,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final String status;
  final String notes;
  final DateTime updatedAt;

  factory FundItem.fromMap(Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    final parsedAmount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0;

    return FundItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled fund item',
      category: map['category']?.toString() ?? 'General',
      amount: parsedAmount,
      status: map['status']?.toString() ?? 'open',
      notes: map['notes']?.toString() ?? 'No notes yet.',
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
