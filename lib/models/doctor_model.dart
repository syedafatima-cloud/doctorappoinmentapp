class Doctor {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String specialization;
  final dynamic experience;
  final double rating;
  final dynamic consultationFee;
  final String? profileImage;
  final String? profileImageUrl;
  final String? licenseNumber;
  final String? hospital;
  final String? address;
  final int? experienceYears;
  final String? qualifications;
  final bool? isVerified;
  final DateTime? registrationDate;
  final List<String>? availableDays;
  final String? startTime;
  final String? endTime;

  Doctor({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.specialization,
    this.experience,
    this.rating = 0.0,
    this.consultationFee,
    this.profileImage,
    this.profileImageUrl,
    this.licenseNumber,
    this.hospital,
    this.address,
    this.experienceYears,
    this.qualifications,
    this.isVerified,
    this.registrationDate,
    this.availableDays,
    this.startTime,
    this.endTime,
  });

  factory Doctor.fromMap(Map<String, dynamic> map) {
    return Doctor(
      id: map['id'] ?? '',
      name: map['name'] ?? map['fullName'] ?? 'Unknown Doctor',
      email: map['email'] ?? '',
      phone: map['phone'] ?? map['phoneNumber'] ?? '',
      specialization: map['specialization'] ?? '',
      experience: map['experience'] ?? map['experienceYears'],
      rating: (map['rating'] is int)
          ? (map['rating'] as int).toDouble()
          : (map['rating'] ?? 0.0),
      consultationFee: map['consultationFee'] != null ? (map['consultationFee'] is int ? (map['consultationFee'] as int).toDouble() : map['consultationFee']) : null,
      profileImage: map['profileImage'],
      profileImageUrl: map['profileImageUrl'] ?? '',
      licenseNumber: map['licenseNumber'],
      hospital: map['hospital'],
      address: map['address'],
      experienceYears: map['experienceYears'],
      qualifications: map['qualifications'],
      isVerified: map['isVerified'],
      registrationDate: map['registrationDate'] != null ? DateTime.tryParse(map['registrationDate']) : null,
      availableDays: map['availableDays'] != null ? List<String>.from(map['availableDays']) : null,
      startTime: map['startTime'],
      endTime: map['endTime'],
    );
  }
}
