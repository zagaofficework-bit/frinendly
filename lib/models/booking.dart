import 'companion.dart';

enum BookingStatus { pending, confirmed, completed, canceled }

class Pricing {
  static const feeRate = 0.15;
  static double fee(double subtotal) => subtotal * feeRate;
  static double total(double rate, int hours) => rate * hours + fee(rate * hours);
}

class Booking {
  final String id, activity, location;
  final Companion companion;
  final DateTime start;
  final int hours;
  final BookingStatus status;
  final String? clientName;
  final String? clientAvatar;
  const Booking({
    required this.id, required this.companion, required this.start,
    required this.hours, required this.activity, required this.location,
    this.status = BookingStatus.pending,
    this.clientName,
    this.clientAvatar,
  });
  double get subtotal => companion.hourlyRate * hours;
  double get total => Pricing.total(companion.hourlyRate, hours);
  bool get isUpcoming =>
      (status == BookingStatus.pending || status == BookingStatus.confirmed) && start.isAfter(DateTime.now());
  Booking copyWith({
    BookingStatus? status,
    String? clientName,
    String? clientAvatar,
  }) => Booking(
      id: id, companion: companion, start: start, hours: hours,
      activity: activity, location: location, status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      clientAvatar: clientAvatar ?? this.clientAvatar,
  );

  factory Booking.fromMap(Map<String, dynamic> map, Companion companion) {
    return Booking(
      id: map['id']?.toString() ?? '',
      companion: companion,
      start: map['start_time'] != null ? DateTime.parse(map['start_time'].toString()) : DateTime.now(),
      hours: (map['hours'] as num?)?.toInt() ?? 1,
      activity: map['activity']?.toString() ?? 'Meetup',
      location: map['location']?.toString() ?? 'Public Place',
      clientName: map['client_name']?.toString() ?? (map['profiles'] != null ? map['profiles']['display_name']?.toString() : null),
      clientAvatar: map['client_avatar']?.toString() ?? (map['profiles'] != null ? map['profiles']['avatar_url']?.toString() : null),
      status: switch (map['status']?.toString()) {
        'confirmed' => BookingStatus.confirmed,
        'completed' => BookingStatus.completed,
        'canceled' => BookingStatus.canceled,
        _ => BookingStatus.pending,
      },
    );
  }

  Map<String, dynamic> toMap({required String clientId}) => {
        'client_id': clientId,
        'companion_id': companion.id,
        'start_time': start.toIso8601String(),
        'hours': hours,
        'activity': activity,
        'location': location,
        'status': status.name,
        'subtotal': subtotal,
        'total': total,
        if (clientName != null) 'client_name': clientName,
        if (clientAvatar != null) 'client_avatar': clientAvatar,
      };
}
