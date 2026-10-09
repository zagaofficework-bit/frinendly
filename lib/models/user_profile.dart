class UserProfile {
  final String id;
  final String email;
  final String? phone;
  final String displayName;
  final String? avatarUrl;
  final String role; // 'client', 'companion', 'admin'
  final double walletBalance;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.phone,
    required this.displayName,
    this.avatarUrl,
    this.role = 'client',
    this.walletBalance = 0.0,
    required this.createdAt,
  });

  bool get isCompanion => role == 'companion';
  bool get isAdmin => role == 'admin';

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString(),
      displayName: map['display_name']?.toString() ?? 'User',
      avatarUrl: map['avatar_url']?.toString(),
      role: map['role']?.toString() ?? 'client',
      walletBalance: (map['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'phone': phone,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'role': role,
    'wallet_balance': walletBalance,
  };

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? phone,
    String? role,
    double? walletBalance,
  }) {
    return UserProfile(
      id: id,
      email: email,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      walletBalance: walletBalance ?? this.walletBalance,
      createdAt: createdAt,
    );
  }
}
