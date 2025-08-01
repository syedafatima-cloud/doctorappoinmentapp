
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorRegistration {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String specialization;
  final String licenseNumber;
  final String hospital;
  final String address;
  final int experienceYears;
  final String qualifications;
  final String profileImageUrl;
  final String? profileImage;
  final bool isVerified;
  final DateTime registrationDate;
  final List<String> availableDays;
  final String startTime;
  final String endTime;
  final double consultationFee;

  DoctorRegistration({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.specialization,
    required this.licenseNumber,
    required this.hospital,
    required this.address,
    required this.experienceYears,
    required this.qualifications,
    this.profileImageUrl = '',
    this.profileImage,
    this.isVerified = false,
    required this.registrationDate,
    required this.availableDays,
    required this.startTime,
    required this.endTime,
    required this.consultationFee,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': fullName,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'specialization': specialization,
      'licenseNumber': licenseNumber,
      'hospital': hospital,
      'address': address,
      'experienceYears': experienceYears,
      'qualifications': qualifications,
      'profileImageUrl': profileImageUrl,
      'profileImage': profileImage,
      'isVerified': isVerified,
      'registrationDate': registrationDate.toIso8601String(),
      'availableDays': availableDays,
      'startTime': startTime,
      'endTime': endTime,
      'consultationFee': consultationFee,
      'isActive': true,
    };
  }

  factory DoctorRegistration.fromMap(Map<String, dynamic> map) {
    return DoctorRegistration(
      id: map['id'] ?? '',
      fullName: map['fullName'] ?? map['name'] ?? '', // Handle both 'fullName' and 'name' fields
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      specialization: map['specialization'] ?? '',
      licenseNumber: map['licenseNumber'] ?? '',
      hospital: map['hospital'] ?? '',
      address: map['address'] ?? '',
      experienceYears: map['experienceYears'] ?? 0,
      qualifications: map['qualifications'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      profileImage: map['profileImage'],
      isVerified: map['isVerified'] ?? false,
      registrationDate: map['registrationDate'] != null 
          ? (map['registrationDate'] is String 
              ? DateTime.parse(map['registrationDate']) 
              : (map['registrationDate'] as Timestamp).toDate())
          : DateTime.now(),
      availableDays: List<String>.from(map['availableDays'] ?? []),
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      consultationFee: map['consultationFee']?.toDouble() ?? 0.0,
    );
  }

  DoctorRegistration copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? specialization,
    String? licenseNumber,
    String? hospital,
    String? address,
    int? experienceYears,
    String? qualifications,
    String? profileImageUrl,
    String? profileImage,
    bool? isVerified,
    DateTime? registrationDate,
    List<String>? availableDays,
    String? startTime,
    String? endTime,
    double? consultationFee,
  }) {
    return DoctorRegistration(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      specialization: specialization ?? this.specialization,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      hospital: hospital ?? this.hospital,
      address: address ?? this.address,
      experienceYears: experienceYears ?? this.experienceYears,
      qualifications: qualifications ?? this.qualifications,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileImage: profileImage ?? this.profileImage,
      isVerified: isVerified ?? this.isVerified,
      registrationDate: registrationDate ?? this.registrationDate,
      availableDays: availableDays ?? this.availableDays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      consultationFee: consultationFee ?? this.consultationFee,
    );
  }
}