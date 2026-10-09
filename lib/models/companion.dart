class Companion {
  final String id, name, bio, avatarUrl, city;
  final int age, reviewCount;
  final double hourlyRate, rating, distanceKm;
  final bool verified, backgroundChecked;
  final List<String> gallery, languages, tags, activities, badges;
  const Companion({
    required this.id, required this.name, required this.age, required this.bio,
    required this.avatarUrl, required this.city, required this.hourlyRate,
    required this.rating, required this.reviewCount, required this.distanceKm,
    this.verified = true, this.backgroundChecked = true,
    this.gallery = const [], this.languages = const [], this.tags = const [],
    this.activities = const [], this.badges = const [],
  });

  factory Companion.fromMap(Map<String, dynamic> map) {
    return Companion(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      age: (map['age'] as num?)?.toInt() ?? 18,
      bio: map['bio']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      hourlyRate: (map['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (map['review_count'] as num?)?.toInt() ?? 0,
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 1.0,
      verified: map['verified'] as bool? ?? false,
      backgroundChecked: map['background_checked'] as bool? ?? false,
      gallery: (map['gallery'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      languages: (map['languages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      activities: (map['activities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      badges: (map['badges'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'age': age,
    'city': city,
    'bio': bio,
    'avatar_url': avatarUrl,
    'gallery': gallery,
    'hourly_rate': hourlyRate,
    'rating': rating,
    'review_count': reviewCount,
    'distance_km': distanceKm,
    'verified': verified,
    'background_checked': backgroundChecked,
    'languages': languages,
    'tags': tags,
    'activities': activities,
    'badges': badges,
  };
}
