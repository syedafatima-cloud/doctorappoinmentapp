// services/disease_firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/disease_model.dart';

class DiseaseFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'health_concerns';

  // Initialize disease data in Firestore (call this once to populate)
  static Future<void> initializeDiseaseData() async {
    try {
      print('Starting to initialize disease data...');
      
      final List<Disease> diseases = [
        Disease(
          name: 'Heart Problems',
          description: 'Chest pain, irregular heartbeat, blood pressure issues, heart palpitations',
          specializations: ['Cardiology', 'Internal Medicine'],
          icon: Icons.favorite,
          color: Colors.red,
        ),
        Disease(
          name: 'Stomach Issues',
          description: 'Stomach pain, nausea, digestive problems, acid reflux, bloating',
          specializations: ['Gastroenterology', 'Internal Medicine'],
          icon: Icons.restaurant,
          color: Colors.orange,
        ),
        Disease(
          name: 'Breathing Problems',
          description: 'Difficulty breathing, cough, chest tightness, asthma, wheezing',
          specializations: ['Pulmonology', 'Internal Medicine'],
          icon: Icons.air,
          color: Colors.blue,
        ),
        Disease(
          name: 'Brain & Nerves',
          description: 'Headaches, memory issues, seizures, nerve pain, migraines',
          specializations: ['Neurology'],
          icon: Icons.psychology,
          color: Colors.purple,
        ),
        Disease(
          name: 'Bones & Joints',
          description: 'Back pain, joint pain, fractures, muscle problems, arthritis',
          specializations: ['Orthopedics', 'Rheumatology'],
          icon: Icons.accessibility_new,
          color: Colors.green,
        ),
        Disease(
          name: 'Skin Problems',
          description: 'Rashes, acne, infections, skin irritation, eczema, allergies',
          specializations: ['Dermatology'],
          icon: Icons.face,
          color: Colors.pink,
        ),
        Disease(
          name: 'Mental Health',
          description: 'Depression, anxiety, stress, mood disorders, panic attacks',
          specializations: ['Psychiatry', 'Psychology'],
          icon: Icons.sentiment_very_satisfied,
          color: Colors.teal,
        ),
        Disease(
          name: 'Eye Problems',
          description: 'Vision issues, eye pain, infections, blurred vision, dry eyes',
          specializations: ['Ophthalmology'],
          icon: Icons.visibility,
          color: Colors.indigo,
        ),
        Disease(
          name: 'Ear, Nose & Throat',
          description: 'Sore throat, hearing problems, sinus issues, ear infections',
          specializations: ['ENT'],
          icon: Icons.hearing,
          color: Colors.amber,
        ),
        Disease(
          name: 'Women\'s Health',
          description: 'Gynecological issues, pregnancy, reproductive health, menstrual problems',
          specializations: ['Gynecology', 'Obstetrics'],
          icon: Icons.pregnant_woman,
          color: Colors.pinkAccent,
        ),
        Disease(
          name: 'Children\'s Health',
          description: 'Pediatric conditions, growth issues, vaccinations, child development',
          specializations: ['Pediatrics'],
          icon: Icons.child_care,
          color: Colors.lightBlue,
        ),
        Disease(
          name: 'Kidney & Urinary',
          description: 'Kidney problems, urinary issues, infections, bladder problems',
          specializations: ['Urology', 'Nephrology'],
          icon: Icons.water_drop,
          color: Colors.cyan,
        ),
        Disease(
          name: 'Hormone Issues',
          description: 'Diabetes, thyroid problems, weight issues, hormonal imbalances',
          specializations: ['Endocrinology'],
          icon: Icons.science,
          color: Colors.deepOrange,
        ),
        Disease(
          name: 'Cancer & Tumors',
          description: 'Cancer screening, tumors, oncology care, chemotherapy',
          specializations: ['Oncology'],
          icon: Icons.medical_services,
          color: Colors.red.shade800,
        ),
        Disease(
          name: 'Emergency Issues',
          description: 'Urgent medical problems, accidents, severe pain, trauma',
          specializations: ['Emergency Medicine'],
          icon: Icons.local_hospital,
          color: Colors.red.shade600,
        ),
        Disease(
          name: 'General Health',
          description: 'Fever, fatigue, routine checkups, general concerns, preventive care',
          specializations: ['General Practice', 'Family Medicine'],
          icon: Icons.health_and_safety,
          color: Colors.grey.shade600,
        ),
      ];

      // Add each disease to Firestore
      final batch = _firestore.batch();
      
      for (int i = 0; i < diseases.length; i++) {
        final disease = diseases[i];
        final docRef = _firestore.collection(_collection).doc();
        
        final diseaseData = {
          'id': docRef.id,
          'name': disease.name,
          'description': disease.description,
          'specializations': disease.specializations,
          'iconCodePoint': disease.icon.codePoint,
          'colorValue': disease.color.value,
          'isActive': true,
          'orderIndex': i,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // Additional metadata
          'searchKeywords': _generateSearchKeywords(disease),
          'category': _getCategoryFromName(disease.name),
        };
        
        batch.set(docRef, diseaseData);
      }
      
      await batch.commit();
      print('Successfully initialized ${diseases.length} health concerns in Firestore');
      
    } catch (e) {
      print('Error initializing disease data: $e');
      rethrow;
    }
  }

  // Get all diseases from Firestore
  static Future<List<Disease>> getAllDiseases() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('orderIndex')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Disease(
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          specializations: List<String>.from(data['specializations'] ?? []),
          icon: IconData(
            data['iconCodePoint'] ?? Icons.health_and_safety.codePoint,
            fontFamily: 'MaterialIcons',
          ),
          color: Color(data['colorValue'] ?? Colors.grey.value),
        );
      }).toList();
    } catch (e) {
      print('Error fetching diseases: $e');
      rethrow;
    }
  }

  // Search diseases in Firestore
  static Future<List<Disease>> searchDiseases(String query) async {
    try {
      if (query.isEmpty) return await getAllDiseases();
      
      // Search by name and description
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final List<Disease> allDiseases = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Disease(
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          specializations: List<String>.from(data['specializations'] ?? []),
          icon: IconData(
            data['iconCodePoint'] ?? Icons.health_and_safety.codePoint,
            fontFamily: 'MaterialIcons',
          ),
          color: Color(data['colorValue'] ?? Colors.grey.value),
        );
      }).toList();

      // Filter based on search query
      return allDiseases.where((disease) {
        return disease.name.toLowerCase().contains(query.toLowerCase()) ||
               disease.description.toLowerCase().contains(query.toLowerCase());
      }).toList();
      
    } catch (e) {
      print('Error searching diseases: $e');
      rethrow;
    }
  }

  // Add a new disease
  static Future<String?> addDisease(Disease disease) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      
      final diseaseData = {
        'id': docRef.id,
        'name': disease.name,
        'description': disease.description,
        'specializations': disease.specializations,
        'iconCodePoint': disease.icon.codePoint,
        'colorValue': disease.color.value,
        'isActive': true,
        'orderIndex': await _getNextOrderIndex(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'searchKeywords': _generateSearchKeywords(disease),
        'category': _getCategoryFromName(disease.name),
      };
      
      await docRef.set(diseaseData);
      return docRef.id;
      
    } catch (e) {
      print('Error adding disease: $e');
      return null;
    }
  }

  // Update a disease
  static Future<bool> updateDisease(String diseaseId, Disease disease) async {
    try {
      await _firestore.collection(_collection).doc(diseaseId).update({
        'name': disease.name,
        'description': disease.description,
        'specializations': disease.specializations,
        'iconCodePoint': disease.icon.codePoint,
        'colorValue': disease.color.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'searchKeywords': _generateSearchKeywords(disease),
        'category': _getCategoryFromName(disease.name),
      });
      
      return true;
    } catch (e) {
      print('Error updating disease: $e');
      return false;
    }
  }

  // Delete a disease (soft delete)
  static Future<bool> deleteDisease(String diseaseId) async {
    try {
      await _firestore.collection(_collection).doc(diseaseId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error deleting disease: $e');
      return false;
    }
  }

  // Get diseases by specialization
  static Future<List<Disease>> getDiseasesBySpecialization(String specialization) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('specializations', arrayContains: specialization)
          .orderBy('orderIndex')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Disease(
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          specializations: List<String>.from(data['specializations'] ?? []),
          icon: IconData(
            data['iconCodePoint'] ?? Icons.health_and_safety.codePoint,
            fontFamily: 'MaterialIcons',
          ),
          color: Color(data['colorValue'] ?? Colors.grey.value),
        );
      }).toList();
    } catch (e) {
      print('Error fetching diseases by specialization: $e');
      rethrow;
    }
  }

  // Check if disease data exists in Firestore
  static Future<bool> isDiseaseDataInitialized() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if disease data is initialized: $e');
      return false;
    }
  }

  // Helper method to generate search keywords
  static List<String> _generateSearchKeywords(Disease disease) {
    final keywords = <String>[];
    
    // Add name words
    keywords.addAll(disease.name.toLowerCase().split(' '));
    
    // Add description words
    keywords.addAll(disease.description.toLowerCase().split(' '));
    
    // Add specializations
    keywords.addAll(disease.specializations.map((s) => s.toLowerCase()));
    
    // Remove common words and duplicates
    final commonWords = ['the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'];
    return keywords
        .where((word) => word.length > 2 && !commonWords.contains(word))
        .toSet()
        .toList();
  }

  // Helper method to get category from disease name
  static String _getCategoryFromName(String name) {
    final Map<String, String> categoryMapping = {
      'Heart Problems': 'Cardiovascular',
      'Stomach Issues': 'Digestive',
      'Breathing Problems': 'Respiratory',
      'Brain & Nerves': 'Neurological',
      'Bones & Joints': 'Musculoskeletal',
      'Skin Problems': 'Dermatological',
      'Mental Health': 'Psychological',
      'Eye Problems': 'Ophthalmological',
      'Ear, Nose & Throat': 'ENT',
      'Women\'s Health': 'Gynecological',
      'Children\'s Health': 'Pediatric',
      'Kidney & Urinary': 'Urological',
      'Hormone Issues': 'Endocrine',
      'Cancer & Tumors': 'Oncological',
      'Emergency Issues': 'Emergency',
      'General Health': 'General',
    };
    
    return categoryMapping[name] ?? 'General';
  }

  // Helper method to get next order index
  static Future<int> _getNextOrderIndex() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('orderIndex', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return 0;
      
      final lastDoc = snapshot.docs.first.data() as Map<String, dynamic>;
      return (lastDoc['orderIndex'] ?? 0) + 1;
    } catch (e) {
      print('Error getting next order index: $e');
      return 0;
    }
  }
}