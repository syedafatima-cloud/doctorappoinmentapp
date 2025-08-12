// screens/disease_selection_screen.dart
import 'package:doctorappoinmentapp/services/doctor_rec_service.dart';
import 'package:flutter/material.dart';
import '../../models/disease_model.dart';
import '../../services/disease_firestore_service.dart';
import 'doctor_list_screen.dart';

class DiseaseSelectionScreen extends StatefulWidget {
  const DiseaseSelectionScreen({super.key});

  @override
  State<DiseaseSelectionScreen> createState() => _DiseaseSelectionScreenState();
}

class _DiseaseSelectionScreenState extends State<DiseaseSelectionScreen> {
  String _searchQuery = '';
  final List<Disease> _selectedDiseases = [];
  List<Disease> _availableDiseases = [];
  bool _isLoading = false;
  bool _isLoadingDiseases = true;
  String _errorMessage = '';

  // Fallback disease data in case Firestore fails
  final List<Disease> _fallbackDiseases = [
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
      color: const Color(0xFFB71C1C),
    ),
    Disease(
      name: 'Emergency Issues',
      description: 'Urgent medical problems, accidents, severe pain, trauma',
      specializations: ['Emergency Medicine'],
      icon: Icons.local_hospital,
      color: const Color(0xFFD32F2F),
    ),
    Disease(
      name: 'General Health',
      description: 'Fever, fatigue, routine checkups, general concerns, preventive care',
      specializations: ['General Practice', 'Family Medicine'],
      icon: Icons.health_and_safety,
      color: Colors.grey,
    ),
  ];

  List<Disease> get _filteredDiseases {
    if (_searchQuery.isEmpty) {
      return _availableDiseases;
    }
    return _availableDiseases
        .where((disease) =>
            disease.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            disease.description.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _initializeDiseaseData();
  }

  Future<void> _initializeDiseaseData() async {
    try {
      setState(() {
        _isLoadingDiseases = true;
        _errorMessage = '';
      });

      // Try to load from Firestore first
      try {
        // Check if data exists, if not initialize it
        final bool dataExists = await DiseaseFirestoreService.isDiseaseDataInitialized();
        
        if (!dataExists) {
          print('Initializing disease data in Firestore...');
          await DiseaseFirestoreService.initializeDiseaseData();
        }
        
        // Load diseases from Firestore
        final diseases = await DiseaseFirestoreService.getAllDiseases();
        
        if (diseases.isNotEmpty) {
          if (mounted) {
            setState(() {
              _availableDiseases = diseases;
              _isLoadingDiseases = false;
            });
          }
          return;
        }
      } catch (firestoreError) {
        print('Firestore error, falling back to local data: $firestoreError');
      }

      // Fallback to local data if Firestore fails
      if (mounted) {
        setState(() {
          _availableDiseases = _fallbackDiseases;
          _isLoadingDiseases = false;
          _errorMessage = 'Using offline data. Some features may be limited.';
        });
      }
      
    } catch (e) {
      print('Error initializing disease data: $e');
      if (mounted) {
        setState(() {
          _availableDiseases = _fallbackDiseases;
          _isLoadingDiseases = false;
          _errorMessage = 'Using offline data due to connection issues.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What\'s your health concern?'),
        centerTitle: true,
      ),
      body: _isLoadingDiseases
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading health concerns...'),
                ],
              ),
            )
          : Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Search health concerns...',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.secondary),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.secondary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select the areas where you\'re experiencing problems',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Error Message
                if (_errorMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Selected Diseases Counter
                if (_selectedDiseases.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedDiseases.length} area(s) selected',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedDiseases.clear();
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.secondary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                  ),
                
                // Disease Grid
                Expanded(
                  child: _buildDiseaseGrid(),
                ),
                
                // Continue Button
                if (_selectedDiseases.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _findRecommendedDoctors,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 3,
                          shadowColor: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.medical_services, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Find Doctors (${_selectedDiseases.length})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDiseaseGrid() {
    final filteredDiseases = _filteredDiseases;
    
    if (filteredDiseases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No health concerns found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredDiseases.length,
      itemBuilder: (context, index) {
        final disease = filteredDiseases[index];
        return _buildDiseaseCard(disease);
      },
    );
  }

  Widget _buildDiseaseCard(Disease disease) {
    final isSelected = _selectedDiseases.contains(disease);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDiseases.remove(disease);
          } else {
            _selectedDiseases.add(disease);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).cardColor
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).primaryColor.withOpacity(0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? Theme.of(context).colorScheme.secondary.withOpacity(0.25)
                  : Theme.of(context).primaryColor.withOpacity(0.1),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Icon with background
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected 
                        ? [
                            Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          ]
                        : [
                            disease.color.withOpacity(0.15),
                            disease.color.withOpacity(0.05),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  disease.icon,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.secondary
                      : disease.color,
                  size: 28,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Disease name
              Text(
                disease.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Description
              Expanded(
                child: Text(
                  disease.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Specialists info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${disease.specializations.length} specialist${disease.specializations.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              // Selection indicator
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _findRecommendedDoctors() async {
    if (_selectedDiseases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one health concern'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Get all specializations needed for selected diseases
      final Set<String> requiredSpecializations = {};
      for (final disease in _selectedDiseases) {
        requiredSpecializations.addAll(disease.specializations);
      }
      
      // Find doctors with matching specializations
      final recommendedDoctors = await DoctorRecommendationService.findDoctorsForDiseases(
        _selectedDiseases,
        requiredSpecializations.toList(),
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorListScreen(
              selectedDiseases: _selectedDiseases,
              recommendedDoctors: recommendedDoctors,
              requiredSpecializations: requiredSpecializations.toList(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding doctors: Please try again'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}