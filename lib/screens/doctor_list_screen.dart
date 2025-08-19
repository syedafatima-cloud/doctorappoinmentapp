// screens/doctor_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:doctorappoinmentapp/models/doctor_model.dart';
import 'package:doctorappoinmentapp/models/doctor_recommendation_model.dart';
import 'package:doctorappoinmentapp/screens/appointment_booking_screen.dart';
import 'package:doctorappoinmentapp/screens/doctor_profile_screen.dart';
import 'package:flutter/material.dart';
import '../models/disease_model.dart';

class DoctorListScreen extends StatefulWidget {
  final List<Disease> selectedDiseases;
  final List<DoctorRecommendation> recommendedDoctors;
  final List<String> requiredSpecializations;

  const DoctorListScreen({
    super.key,
    required this.selectedDiseases,
    required this.recommendedDoctors,
    required this.requiredSpecializations,
  });

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  String _sortBy = 'recommended'; // recommended, rating, fee, availability
  String _filterSpecialization = 'all';
  final Map<String, List<Map<String, dynamic>>> _doctorReviews = {};
  final Map<String, bool> _reviewsLoading = {};

  List<DoctorRecommendation> get _filteredAndSortedDoctors {
    List<DoctorRecommendation> doctors = List.from(widget.recommendedDoctors);
    
    // Filter by specialization
    if (_filterSpecialization != 'all') {
      doctors = doctors
          .where((doctor) => doctor.specialization == _filterSpecialization)
          .toList();
    }

    // Sort doctors
    switch (_sortBy) {
      case 'recommended':
        doctors.sort((a, b) => b.matchScore.compareTo(a.matchScore));
        break;
      case 'rating':
        doctors.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'fee':
        doctors.sort((a, b) => a.consultationFee.compareTo(b.consultationFee));
        break;
      case 'availability':
        doctors.sort((a, b) => b.isAvailable ? 1 : -1);
        break;
    }

    return doctors;
  }

  @override
  void initState() {
    super.initState();
    // Auto-load reviews for first few doctors
    Future.delayed(const Duration(milliseconds: 500), () {
      for (int i = 0; i < widget.recommendedDoctors.length && i < 3; i++) {
        _loadDoctorReviews(widget.recommendedDoctors[i].doctorId);
      }
    });
  }

  Future<void> _loadDoctorReviews(String doctorId) async {
  if (_reviewsLoading[doctorId] == true) return;
  
  print('🔍 Loading reviews for doctor: $doctorId');
  
  setState(() {
    _reviewsLoading[doctorId] = true;
  });

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('doctorId', isEqualTo: doctorId)
        .get();
    
    print('📝 Found ${snapshot.docs.length} reviews for doctor $doctorId');
    
    if (snapshot.docs.isNotEmpty) {
      final docs = snapshot.docs;
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return bTime.compareTo(aTime);
      });
      
      setState(() {
        _doctorReviews[doctorId] = docs.take(3).map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        _reviewsLoading[doctorId] = false;
      });
    } else {
      setState(() {
        _doctorReviews[doctorId] = [];
        _reviewsLoading[doctorId] = false;
      });
    }
  } catch (e) {
    print('❌ Error loading reviews for doctor $doctorId: $e');
    setState(() {
      _reviewsLoading[doctorId] = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended Doctors'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Selected Conditions Summary
          _buildConditionsSummary(),
          
          // Sort and Filter Bar
          _buildSortFilterBar(),
          
          // Doctors List
          Expanded(
            child: _filteredAndSortedDoctors.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredAndSortedDoctors.length,
                    itemBuilder: (context, index) {
                      final doctor = _filteredAndSortedDoctors[index];
                      return _buildDoctorCard(doctor, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsSummary() {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Selected Conditions:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.selectedDiseases.map((disease) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Text(
                  disease.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Found ${widget.recommendedDoctors.length} recommended doctors',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('Recommended', 'recommended'),
                  const SizedBox(width: 8),
                  _buildSortChip('Highest Rated', 'rating'),
                  const SizedBox(width: 8),
                  _buildSortChip('Lowest Fee', 'fee'),
                  const SizedBox(width: 8),
                  _buildSortChip('Available Now', 'availability'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<String>(
              value: _filterSpecialization,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, size: 16),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Specializations')),
                ...widget.requiredSpecializations.map((spec) =>
                    DropdownMenuItem(value: spec, child: Text(spec))),
              ],
              onChanged: (value) {
                setState(() {
                  _filterSpecialization = value ?? 'all';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(DoctorRecommendation doctor, int index) {
    print('🔍 Doctor data: name="${doctor.doctorName}", id="${doctor.doctorId}", specialization="${doctor.specialization}"');
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with ranking badge
            Row(
              children: [
                if (index < 3 && _sortBy == 'recommended')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRankingColor(index),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getRankingIcon(index),
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getRankingText(index),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: doctor.isAvailable ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: doctor.isAvailable ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        doctor.isAvailable ? 'Available' : 'Busy',
                        style: TextStyle(
                          color: doctor.isAvailable ? Colors.green : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Doctor Info
            Row(
              children: [
                // Profile Image
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  backgroundImage: doctor.profileImageUrl.isNotEmpty
                      ? NetworkImage(doctor.profileImageUrl)
                      : null,
                  child: doctor.profileImageUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          color: Theme.of(context).primaryColor,
                          size: 30,
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Doctor Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          doctor.doctorName.isNotEmpty 
                            ? (doctor.doctorName.startsWith('Dr.') 
                                ? doctor.doctorName 
                                : 'Dr. ${doctor.doctorName}')
                            : 'Doctor Name Not Available',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.specialization,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            doctor.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'PKR',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7E57C2),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            ' ${doctor.consultationFee}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Match Score and Conditions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_hospital,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Match Score: ${doctor.matchScore.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 60,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: doctor.matchScore / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getMatchScoreColor(doctor.matchScore),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Can treat: ${doctor.matchingConditions.join(", ")}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            
            // Reviews Section
            _buildReviewsPreview(doctor),
            
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _viewDoctorProfile(doctor);
                    },
                    icon: const Icon(Icons.person, size: 16),
                    label: const Text('View Profile'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _bookAppointment(doctor);
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Book Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsPreview(DoctorRecommendation doctor) {
  final reviews = _doctorReviews[doctor.doctorId] ?? [];
  final isLoading = _reviewsLoading[doctor.doctorId] ?? false;

  // Only show the reviews section if there are reviews or if currently loading
  if (reviews.isEmpty && !isLoading) {
    return const SizedBox.shrink(); // Don't show anything if no reviews
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rate_review, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            const Text(
              'Recent Reviews',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _loadDoctorReviews(doctor.doctorId),
              child: Icon(
                Icons.refresh,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Column(
            children: reviews.take(2).map((review) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        review['patientName'] ?? 'Anonymous',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: List.generate(5, (index) => Icon(
                          index < (review['rating'] ?? 0)
                              ? Icons.star
                              : Icons.star_outline,
                          size: 12,
                          color: Colors.amber,
                        )),
                      ),
                    ],
                  ),
                  if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${review['comment']}"',
                      style: const TextStyle(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            )).toList(),
          ),
      ],
    ),
  );
}
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No doctors found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or selecting different conditions',
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getRankingColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber; // Gold
      case 1:
        return Colors.grey; // Silver
      case 2:
        return Colors.brown; // Bronze
      default:
        return Colors.grey;
    }
  }

  IconData _getRankingIcon(int index) {
    switch (index) {
      case 0:
        return Icons.emoji_events;
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.emoji_events;
      default:
        return Icons.star;
    }
  }

  String _getRankingText(int index) {
    switch (index) {
      case 0:
        return 'Best Match';
      case 1:
        return '2nd Best';
      case 2:
        return '3rd Best';
      default:
        return 'Recommended';
    }
  }

  Color _getMatchScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter & Sort'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sort by:'),
              // Add sort options here
              const SizedBox(height: 16),
              const Text('Filter by specialization:'),
              // Add filter options here
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _viewDoctorProfile(DoctorRecommendation doctor) {
    // Navigate to doctor profile screen
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => DoctorProfileScreen(doctorId: doctor.doctorId)
      )
    );
  }

  Doctor _convertToDoctor(DoctorRecommendation recommendation) {
    return Doctor(
      id: recommendation.doctorId,
      name: recommendation.doctorName,
      email: null,  // Not available in DoctorRecommendation
      phone: null,  // Not available in DoctorRecommendation
      specialization: recommendation.specialization,
      experience: null,  // Not available in DoctorRecommendation
      rating: recommendation.rating,
      consultationFee: recommendation.consultationFee.toDouble(),
      profileImage: null,
      profileImageUrl: recommendation.profileImageUrl,
      licenseNumber: null,  // Not available in DoctorRecommendation
      hospital: recommendation.hospital,
      address: null,  // Not available in DoctorRecommendation
      experienceYears: null,  // Not available in DoctorRecommendation
      qualifications: null,  // Not available in DoctorRecommendation
      isVerified: true,  // Assume verified since it's recommended
      registrationDate: null,  // Not available in DoctorRecommendation
      availableDays: recommendation.availableDays,
      startTime: recommendation.startTime,
      endTime: recommendation.endTime,
    );
  }

  void _bookAppointment(DoctorRecommendation doctor) {
    print('🔄 Booking appointment for: ${doctor.doctorName} (ID: ${doctor.doctorId})');
    
    final selectedDoctor = _convertToDoctor(doctor);
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => AppointmentBookingScreen(
          preSelectedDoctor: selectedDoctor,
          selectedDiseases: widget.selectedDiseases,
          referenceSource: 'doctor_list_recommendation',
        )
      )
    );
  }

  Future<void> _bookAppointmentWithFullData(DoctorRecommendation doctor) async {
    print('🔄 Fetching complete doctor data for: ${doctor.doctorName}');
    
    try {
      // Fetch complete doctor data from Firestore
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctor.doctorId)
          .get();
      
      if (doctorDoc.exists) {
        final completeDoctor = Doctor.fromMap(doctorDoc.data()!);
        
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => AppointmentBookingScreen(
              preSelectedDoctor: completeDoctor,
              selectedDiseases: widget.selectedDiseases,
              referenceSource: 'doctor_list_recommendation',
            )
          )
        );
      } else {
        // Fallback to conversion method
        _bookAppointment(doctor);
      }
    } catch (e) {
      print('Error fetching complete doctor data: $e');
      // Fallback to conversion method
      _bookAppointment(doctor);
    }
  }

  void _bookAppointmentSimple(DoctorRecommendation doctor) {
    // Create a minimal Doctor object with just the essential fields
    final selectedDoctor = Doctor(
      id: doctor.doctorId,
      name: doctor.doctorName,
      email: '',  // Empty string instead of null
      phone: '',  // Empty string instead of null
      specialization: doctor.specialization,
      rating: doctor.rating,
      consultationFee: doctor.consultationFee.toDouble(),
      profileImageUrl: doctor.profileImageUrl,
      hospital: doctor.hospital,
      availableDays: doctor.availableDays,
      startTime: doctor.startTime,
      endTime: doctor.endTime,
    );
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => AppointmentBookingScreen(
          preSelectedDoctor: selectedDoctor,
          selectedDiseases: widget.selectedDiseases,
          referenceSource: 'doctor_list_recommendation',
        )
      )
    );
  }
}