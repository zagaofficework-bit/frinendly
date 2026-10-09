class Review {
  final String author, text;
  final double rating;
  final DateTime date;
  const Review({required this.author, required this.text, required this.rating, required this.date});

  factory Review.fromMap(Map<String, dynamic> map) => Review(
        author: map['author_name']?.toString() ?? 'Anonymous',
        text: map['text']?.toString() ?? '',
        rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
        date: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      );

  Map<String, dynamic> toMap(String companionId, {String? authorId}) => {
        'companion_id': companionId,
        if (authorId != null) 'author_id': authorId,
        'author_name': author,
        'rating': rating,
        'text': text,
      };
}
