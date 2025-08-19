// Recommendation result model
class DoctorRecommendation {
  final String doctorId;
  final String doctorName;
  final String specialization;
  final double matchScore;
  final List<String> matchingConditions;
  final String profileImageUrl;
  final double rating;
  final int consultationFee;
  final bool isAvailable;
  final String hospital;
  final List<String> availableDays;
  final String startTime;
  final String endTime;

  DoctorRecommendation({
    required this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.matchScore,
    required this.matchingConditions,
    required this.profileImageUrl,
    required this.rating,
    required this.consultationFee,
    required this.isAvailable,
    required this.hospital,
    required this.availableDays,
    required this.startTime,
    required this.endTime,
  });

  factory DoctorRecommendation.fromDoctorData(
  String doctorId,
  Map<String, dynamic> doctorData,
  double matchScore,
  List<String> matchingConditions,
  bool isAvailable,
) {
  return DoctorRecommendation(
    doctorId: doctorId,
    doctorName: doctorData['fullName'] ?? 
                doctorData['name'] ?? 
                doctorData['doctorName'] ?? 
                'Unknown Doctor',
    specialization: doctorData['specialization'] ?? '',
    matchScore: matchScore,
    matchingConditions: matchingConditions,
    profileImageUrl: doctorData['profileImageUrl'] ?? '',
    rating: (doctorData['rating'] ?? 0.0).toDouble(),
    consultationFee: (doctorData['consultationFee'] ?? 0).toInt(),
    isAvailable: isAvailable,
    hospital: doctorData['hospital'] ?? '',
    availableDays: List<String>.from(doctorData['availableDays'] ?? []),
    startTime: doctorData['startTime'] ?? '',
    endTime: doctorData['endTime'] ?? '',
  );
}
}