// services/disease_firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/disease_model.dart';

class DiseaseFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'health_concerns';

  // Define a static mapping of icon names to IconData
  static const Map<String, IconData> _iconMapping = {
    'favorite': Icons.favorite,
    'restaurant': Icons.restaurant,
    'air': Icons.air,
    'psychology': Icons.psychology,
    'accessibility_new': Icons.accessibility_new,
    'face': Icons.face,
    'sentiment_very_satisfied': Icons.sentiment_very_satisfied,
    'visibility': Icons.visibility,
    'hearing': Icons.hearing,
    'pregnant_woman': Icons.pregnant_woman,
    'child_care': Icons.child_care,
    'water_drop': Icons.water_drop,
    'science': Icons.science,
    'medical_services': Icons.medical_services,
    'local_hospital': Icons.local_hospital,
    'health_and_safety': Icons.health_and_safety,
  };

  // Color mapping for consistent colors
  static const Map<String, Color> _colorMapping = {
    'red': Colors.red,
    'orange': Colors.orange,
    'blue': Colors.blue,
    'purple': Colors.purple,
    'green': Colors.green,
    'pink': Colors.pink,
    'teal': Colors.teal,
    'indigo': Colors.indigo,
    'amber': Colors.amber,
    'pinkAccent': Colors.pinkAccent,
    'lightBlue': Colors.lightBlue,
    'cyan': Colors.cyan,
    'deepOrange': Colors.deepOrange,
    'redDark': Color(0xFFC62828), // Colors.red.shade800
    'redMedium': Color(0xFFE53935), // Colors.red.shade600
    'greyMedium': Color(0xFF757575), // Colors.grey.shade600
  };

  // Initialize disease data in Firestore (call this once to populate)
  static Future<void> initializeDiseaseData() async {
    try {
      print('Starting to initialize disease data...');
      
      final List<Map<String, dynamic>> diseases = [
        {
          'name': 'Heart Problems',
          'description': 'Chest pain, irregular heartbeat, blood pressure issues, heart palpitations',
          'specializations': ['Cardiology', 'Internal Medicine'],
          'iconName': 'favorite',
          'colorName': 'red',
        },
        {
          'name': 'Stomach Issues',
          'description': 'Stomach pain, nausea, digestive problems, acid reflux, bloating',
          'specializations': ['Gastroenterology', 'Internal Medicine'],
          'iconName': 'restaurant',
          'colorName': 'orange',
        },
        {
          'name': 'Breathing Problems',
          'description': 'Difficulty breathing, cough, chest tightness, asthma, wheezing',
          'specializations': ['Pulmonology', 'Internal Medicine'],
          'iconName': 'air',
          'colorName': 'blue',
        },
        {
          'name': 'Brain & Nerves',
          'description': 'Headaches, memory issues, seizures, nerve pain, migraines',
          'specializations': ['Neurology'],
          'iconName': 'psychology',
          'colorName': 'purple',
        },
        {
          'name': 'Bones & Joints',
          'description': 'Back pain, joint pain, fractures, muscle problems, arthritis',
          'specializations': ['Orthopedics', 'Rheumatology'],
          'iconName': 'accessibility_new',
          'colorName': 'green',
        },
        {
          'name': 'Skin Problems',
          'description': 'Rashes, acne, infections, skin irritation, eczema, allergies',
          'specializations': ['Dermatology'],
          'iconName': 'face',
          'colorName': 'pink',
        },
        {
          'name': 'Mental Health',
          'description': 'Depression, anxiety, stress, mood disorders, panic attacks',
          'specializations': ['Psychiatry', 'Psychology'],
          'iconName': 'sentiment_very_satisfied',
          'colorName': 'teal',
        },
        {
          'name': 'Eye Problems',
          'description': 'Vision issues, eye pain, infections, blurred vision, dry eyes',
          'specializations': ['Ophthalmology'],
          'iconName': 'visibility',
          'colorName': 'indigo',
        },
        {
          'name': 'Ear, Nose & Throat',
          'description': 'Sore throat, hearing problems, sinus issues, ear infections',
          'specializations': ['ENT'],
          'iconName': 'hearing',
          'colorName': 'amber',
        },
        {
          'name': 'Women\'s Health',
          'description': 'Gynecological issues, pregnancy, reproductive health, menstrual problems',
          'specializations': ['Gynecology', 'Obstetrics'],
          'iconName': 'pregnant_woman',
          'colorName': 'pinkAccent',
        },
        {
          'name': 'Children\'s Health',
          'description': 'Pediatric conditions, growth issues, vaccinations, child development',
          'specializations': ['Pediatrics'],
          'iconName': 'child_care',
          'colorName': 'lightBlue',
        },
        {
          'name': 'Kidney & Urinary',
          'description': 'Kidney problems, urinary issues, infections, bladder problems',
          'specializations': ['Urology', 'Nephrology'],
          'iconName': 'water_drop',
          'colorName': 'cyan',
        },
        {
          'name': 'Hormone Issues',
          'description': 'Diabetes, thyroid problems, weight issues, hormonal imbalances',
          'specializations': ['Endocrinology'],
          'iconName': 'science',
          'colorName': 'deepOrange',
        },
        {
          'name': 'Cancer & Tumors',
          'description': 'Cancer screening, tumors, oncology care, chemotherapy',
          'specializations': ['Oncology'],
          'iconName': 'medical_services',
          'colorName': 'redDark',
        },
        {
          'name': 'Emergency Issues',
          'description': 'Urgent medical problems, accidents, severe pain, trauma',
          'specializations': ['Emergency Medicine'],
          'iconName': 'local_hospital',
          'colorName': 'redMedium',
        },
        {
          'name': 'General Health',
          'description': 'Fever, fatigue, routine checkups, general concerns, preventive care',
          'specializations': ['General Practice', 'Family Medicine'],
          'iconName': 'health_and_safety',
          'colorName': 'greyMedium',
        },
      ];

      // Add each disease to Firestore
      final batch = _firestore.batch();
      
      for (int i = 0; i < diseases.length; i++) {
        final diseaseData = diseases[i];
        final docRef = _firestore.collection(_collection).doc();
        
        final firestoreData = {
          'id': docRef.id,
          'name': diseaseData['name'],
          'description': diseaseData['description'],
          'specializations': diseaseData['specializations'],
          'iconName': diseaseData['iconName'], // Store icon name instead of codePoint
          'colorName': diseaseData['colorName'], // Store color name instead of value
          'isActive': true,
          'orderIndex': i,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // Additional metadata
          'searchKeywords': _generateSearchKeywords(diseaseData['name'], diseaseData['description']),
          'category': _getCategoryFromName(diseaseData['name']),
        };
        
        batch.set(docRef, firestoreData);
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
        return _createDiseaseFromFirestoreData(data);
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
        return _createDiseaseFromFirestoreData(data);
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
  static Future<String?> addDisease(Disease disease, String iconName, String colorName) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      
      final diseaseData = {
        'id': docRef.id,
        'name': disease.name,
        'description': disease.description,
        'specializations': disease.specializations,
        'iconName': iconName,
        'colorName': colorName,
        'isActive': true,
        'orderIndex': await _getNextOrderIndex(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'searchKeywords': _generateSearchKeywords(disease.name, disease.description),
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
  static Future<bool> updateDisease(String diseaseId, Disease disease, String iconName, String colorName) async {
    try {
      await _firestore.collection(_collection).doc(diseaseId).update({
        'name': disease.name,
        'description': disease.description,
        'specializations': disease.specializations,
        'iconName': iconName,
        'colorName': colorName,
        'updatedAt': FieldValue.serverTimestamp(),
        'searchKeywords': _generateSearchKeywords(disease.name, disease.description),
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
        return _createDiseaseFromFirestoreData(data);
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

  // Helper method to create Disease object from Firestore data
  static Disease _createDiseaseFromFirestoreData(Map<String, dynamic> data) {
    final iconName = data['iconName'] ?? 'health_and_safety';
    final colorName = data['colorName'] ?? 'greyMedium';
    
    return Disease(
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      specializations: List<String>.from(data['specializations'] ?? []),
      icon: _iconMapping[iconName] ?? Icons.health_and_safety,
      color: _colorMapping[colorName] ?? Colors.grey,
    );
  }

  // Helper method to generate search keywords
  static List<String> _generateSearchKeywords(String name, String description) {
    final keywords = <String>[];
    
    // Add name words
    keywords.addAll(name.toLowerCase().split(' '));
    
    // Add description words
    keywords.addAll(description.toLowerCase().split(' '));
    
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

  // Getter methods for the mappings (useful for UI components)
  static Map<String, IconData> get availableIcons => _iconMapping;
  static Map<String, Color> get availableColors => _colorMapping;
}