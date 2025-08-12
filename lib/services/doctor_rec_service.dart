// services/doctor_recommendation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:doctorappoinmentapp/models/doctor_model.dart';
import 'package:doctorappoinmentapp/models/doctor_recommendation_model.dart';
import 'package:doctorappoinmentapp/services/appointment_service.dart';
import 'package:flutter/material.dart';
import '../models/disease_model.dart';

class DoctorRecommendationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<DoctorRecommendation>> findDoctorsForDiseases(
  List<Disease> selectedDiseases,
  List<String> requiredSpecializations,
) async {
  try {
    print('🔍 DEBUG: Required specializations: $requiredSpecializations');
    
    // Use the same service as homescreen
    final AppointmentService appointmentService = AppointmentService();
    final doctorsList = await appointmentService.getAllDoctors();
    
    List<Doctor> doctors;
    if (doctorsList is List<Doctor>) {
      doctors = doctorsList.cast<Doctor>();
    } else {
      doctors = (doctorsList as List)
          .map((doc) => Doctor.fromMap(doc as Map<String, dynamic>))
          .toList();
    }
    
    print('🔍 DEBUG: Total doctors found: ${doctors.length}');
    
    List<DoctorRecommendation> recommendations = [];

    for (Doctor doctor in doctors) {
      print('👨‍⚕️ Doctor: ${doctor.name}, Specialization: "${doctor.specialization}"');
      
      if (requiredSpecializations.contains(doctor.specialization)) {
        print('✅ MATCH FOUND for ${doctor.specialization}');
        
        // Calculate match score and create recommendation
        double matchScore = _calculateMatchScore(selectedDiseases, doctor.specialization);
        List<String> matchingConditions = _getMatchingConditions(selectedDiseases, doctor.specialization);
        bool isAvailable = _checkDoctorAvailability(doctor); // Pass doctor object directly
        
        recommendations.add(
          DoctorRecommendation.fromDoctorData(
            doctor.id,
            _doctorToMap(doctor), // Convert Doctor to Map using helper method
            matchScore,
            matchingConditions,
            isAvailable,
          ),
        );
      }
    }
    
   
      // Sort by match score (highest first), then by rating, then by availability
      recommendations.sort((a, b) {
        int scoreComparison = b.matchScore.compareTo(a.matchScore);
        if (scoreComparison != 0) return scoreComparison;

        int ratingComparison = b.rating.compareTo(a.rating);
        if (ratingComparison != 0) return ratingComparison;

        return b.isAvailable ? 1 : -1;
      });

      return recommendations;
    } catch (e) {
      print('Error finding doctors: $e');
      rethrow;
    }
  }

  // Helper method to convert Doctor object to Map
  static Map<String, dynamic> _doctorToMap(Doctor doctor) {
    return {
      'id': doctor.id,
      'name': doctor.name,
      'email': doctor.email,
      'phone': doctor.phone,
      'specialization': doctor.specialization,
      'experience': doctor.experience,
      'rating': doctor.rating,
      'consultationFee': doctor.consultationFee,
      'profileImage': doctor.profileImage,
      'profileImageUrl': doctor.profileImageUrl,
      'licenseNumber': doctor.licenseNumber,
      'hospital': doctor.hospital,
      'address': doctor.address,
      'experienceYears': doctor.experienceYears,
      'qualifications': doctor.qualifications,
      'isVerified': doctor.isVerified,
      'registrationDate': doctor.registrationDate?.toIso8601String(),
      'availableDays': doctor.availableDays,
      'startTime': doctor.startTime,
      'endTime': doctor.endTime,
    };
  }

  // Calculate match score based on disease-specialization alignment
  static double _calculateMatchScore(
    List<Disease> selectedDiseases,
    String doctorSpecialization,
  ) {
    double totalScore = 0.0;
    int matchingDiseases = 0;

    for (Disease disease in selectedDiseases) {
      if (disease.specializations.contains(doctorSpecialization)) {
        matchingDiseases++;
        
        // Base score for matching specialization
        double diseaseScore = 0.6;
        
        // Bonus for primary specialization (first in list)
        if (disease.specializations.first == doctorSpecialization) {
          diseaseScore += 0.4;
        }
        
        // Bonus for having fewer specializations (more specific match)
        if (disease.specializations.length == 1) {
          diseaseScore += 0.2;
        } else if (disease.specializations.length == 2) {
          diseaseScore += 0.1;
        }
        
        totalScore += diseaseScore;
      }
    }

    // Normalize score (0-100)
    if (matchingDiseases == 0) return 0.0;
    
    double normalizedScore = (totalScore / selectedDiseases.length) * 100;
    return normalizedScore.clamp(0.0, 100.0);
  }

  // Get list of conditions this doctor can treat
  static List<String> _getMatchingConditions(
    List<Disease> selectedDiseases,
    String doctorSpecialization,
  ) {
    return selectedDiseases
        .where((disease) => disease.specializations.contains(doctorSpecialization))
        .map((disease) => disease.name)
        .toList();
  }

  // Check if doctor is currently available based on schedule
  static bool _checkDoctorAvailability(Doctor doctor) {
    try {
      final List<String>? availableDays = doctor.availableDays;
      final String? startTime = doctor.startTime;
      final String? endTime = doctor.endTime;

      // Get current day and time
      final DateTime now = DateTime.now();
      final String currentDay = _getDayName(now.weekday);

      // Check if today is in available days
      if (availableDays == null || !availableDays.contains(currentDay)) {
        return false;
      }

      // Check if current time is within working hours
      if (startTime != null && endTime != null && startTime.isNotEmpty && endTime.isNotEmpty) {
        final TimeOfDay currentTime = TimeOfDay.now();
        final TimeOfDay doctorStartTime = _parseTimeString(startTime);
        final TimeOfDay doctorEndTime = _parseTimeString(endTime);

        return _isTimeInRange(currentTime, doctorStartTime, doctorEndTime);
      }

      return true; // Available if no time constraints
    } catch (e) {
      print('Error checking doctor availability: $e');
      return false;
    }
  }

  // Helper method to get day name from weekday number
  static String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  // Helper method to parse time string (HH:MM format)
  static TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    return const TimeOfDay(hour: 9, minute: 0); // Default fallback
  }

  // Helper method to check if current time is within doctor's working hours
  static bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  // Get specialization recommendations based on symptoms/keywords
  static List<String> getRecommendedSpecializations(List<String> symptoms) {
    final Map<String, List<String>> symptomToSpecialization = {
      // Cardiovascular symptoms
      'chest pain': ['Cardiology'],
      'heart': ['Cardiology'],
      'blood pressure': ['Cardiology', 'Internal Medicine'],
      'palpitations': ['Cardiology'],
      
      // Digestive symptoms
      'stomach': ['Gastroenterology', 'Internal Medicine'],
      'nausea': ['Gastroenterology', 'Internal Medicine'],
      'abdominal': ['Gastroenterology', 'Internal Medicine'],
      'heartburn': ['Gastroenterology'],
      'bloating': ['Gastroenterology'],
      
      // Respiratory symptoms
      'breathing': ['Pulmonology', 'Internal Medicine'],
      'cough': ['Pulmonology', 'ENT'],
      'asthma': ['Pulmonology'],
      'wheezing': ['Pulmonology'],
      
      // Neurological symptoms
      'headache': ['Neurology', 'Internal Medicine'],
      'migraine': ['Neurology'],
      'memory': ['Neurology'],
      'seizure': ['Neurology'],
      
      // Musculoskeletal symptoms
      'back pain': ['Orthopedics', 'General Practice'],
      'joint': ['Orthopedics', 'Rheumatology'],
      'arthritis': ['Rheumatology', 'Orthopedics'],
      'muscle': ['Orthopedics', 'Sports Medicine'],
      
      // Skin symptoms
      'skin': ['Dermatology'],
      'rash': ['Dermatology', 'General Practice'],
      'acne': ['Dermatology'],
      'eczema': ['Dermatology'],
      
      // Mental health symptoms
      'depression': ['Psychiatry', 'Psychology'],
      'anxiety': ['Psychiatry', 'Psychology'],
      'stress': ['Psychiatry', 'Psychology', 'General Practice'],
      
      // Eye symptoms
      'vision': ['Ophthalmology'],
      'eye': ['Ophthalmology', 'General Practice'],
      
      // ENT symptoms
      'throat': ['ENT', 'General Practice'],
      'hearing': ['ENT', 'Audiology'],
      'sinus': ['ENT', 'General Practice'],
      
      // General symptoms
      'fever': ['General Practice', 'Internal Medicine'],
      'fatigue': ['General Practice', 'Internal Medicine'],
      'weight': ['Endocrinology', 'General Practice'],
    };

    Set<String> recommendedSpecs = {};

    for (String symptom in symptoms) {
      symptomToSpecialization.forEach((key, specializations) {
        if (symptom.toLowerCase().contains(key.toLowerCase())) {
          recommendedSpecs.addAll(specializations);
        }
      });
    }

    return recommendedSpecs.toList();
  }

  // Search diseases by keyword
  static Future<List<Disease>> searchDiseases(String query) async {
    // This would typically search your disease database
    // For now, returning mock data based on the query
    return []; // Implement based on your disease storage strategy
  }
}