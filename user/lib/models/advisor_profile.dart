class AdvisorProfile {
  final String id;
  final String fullName;
  final String initial;
  final String licenseType = "SEBI RA";
  final String specialties = "Quantitative, Growth, Technical";
  final int experience = 8;
  final int followerCount;
  final double hitRate;

  AdvisorProfile({
    required this.id,
    required this.fullName,
    required this.initial,
    required this.followerCount,
    required this.hitRate,
  });

  factory AdvisorProfile.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] ?? '';
    final lastName = json['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    int followers = 0;
    double rate = 0.0;

    // --- THIS IS THE FIX ---
    // Check if the nested object exists and treat it as a Map, not a List.
    if (json['advisor_statistics'] != null) {
      final stats = json['advisor_statistics'] as Map<String, dynamic>;
      followers = stats['follower_count'] ?? 0;
      rate = (stats['hit_rate'] as num?)?.toDouble() ?? 0.0;
    }

    return AdvisorProfile(
      id: json['id'],
      fullName: fullName,
      initial: initial,
      followerCount: followers,
      hitRate: rate,
    );
  }
}
