// screens/doctor_profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/doctor_model.dart';
import 'appointment_booking_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;
  
  const DoctorProfileScreen({
    super.key,
    required this.doctorId,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Doctor? doctor;
  bool isLoading = true;
  bool isLoadingReviews = true;
  
  List<Map<String, dynamic>> reviews = [];
  
  @override
  void initState() {
    super.initState();
    _loadDoctorProfile();
    _loadReviews();
  }

  Future<void> _loadDoctorProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        setState(() {
          doctor = Doctor.fromMap(data);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error loading doctor profile: ${e.toString()}');
    }
  }

  void _showReviewDialog() {
    final TextEditingController commentController = TextEditingController();
    int selectedRating = 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Write a Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rate your experience:'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedRating = index + 1;
                          });
                        },
                        child: Icon(
                          index < selectedRating ? Icons.star : Icons.star_outline,
                          color: Colors.amber,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Your comment:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedRating > 0 ? () {
                    _submitReview(selectedRating, commentController.text);
                    Navigator.pop(context);
                  } : null,
                  child: const Text('Submit Review'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAllReviews() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Reviews',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: reviews.length,
                  itemBuilder: (context, index) => _buildReviewCard(reviews[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatReviewDate(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else {
        return '';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _submitReview(int rating, String comment) async {
    try {
      // Get current user from Firebase Auth
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        _showError('You must be logged in to submit a review');
        return;
      }

      String userId = currentUser.uid;
      String userName = 'Anonymous User'; // Default fallback
      
      // Try to get user name from multiple sources
      if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
        userName = currentUser.displayName!;
      } else {
        // Try to fetch user name from Firestore users collection
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data();
            userName = userData?['name'] ?? userData?['fullName'] ?? userName;
          }
        } catch (e) {
          print('Could not fetch user name from Firestore: $e');
          // Use email as fallback if available
          if (currentUser.email != null) {
            userName = currentUser.email!.split('@')[0]; // Use email prefix
          }
        }
      }

      // Check if user has already reviewed this doctor
      final existingReview = await FirebaseFirestore.instance
          .collection('reviews')
          .where('doctorId', isEqualTo: widget.doctorId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingReview.docs.isNotEmpty) {
        // Update existing review instead of creating new one
        await FirebaseFirestore.instance
            .collection('reviews')
            .doc(existingReview.docs.first.id)
            .update({
          'rating': rating,
          'comment': comment,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new review
        await FirebaseFirestore.instance.collection('reviews').add({
          'doctorId': widget.doctorId,
          'userId': userId,
          'patientName': userName,
          'rating': rating,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Update doctor's overall rating
      await _updateDoctorRating();

      // Refresh reviews
      await _loadReviews();

    } catch (e) {
      _showError('Error submitting review: ${e.toString()}');
    }
  }

  Future<void> _updateDoctorRating() async {
    try {
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('doctorId', isEqualTo: widget.doctorId)
          .get();

      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0;
        int reviewCount = reviewsSnapshot.docs.length;

        for (var doc in reviewsSnapshot.docs) {
          totalRating += (doc.data()['rating'] ?? 0).toDouble();
        }

        double averageRating = totalRating / reviewCount;

        await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .update({
        'rating': averageRating,
        'reviewCount': reviewCount,
      });
        await _loadDoctorProfile();
      }
    } catch (e) {
      print('Error updating doctor rating: $e');
    }
  }

  Future<void> _loadReviews() async {
    print('🔍 Loading reviews for doctor: ${widget.doctorId}');
    
    setState(() {
      isLoadingReviews = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('doctorId', isEqualTo: widget.doctorId)
          .get(); // Remove orderBy to avoid index issues
      
      print('📝 Found ${snapshot.docs.length} reviews for doctor ${widget.doctorId}');
      
      if (snapshot.docs.isNotEmpty) {
        final docs = snapshot.docs;
        docs.sort((a, b) {
          final aTime = a.data()['createdAt'] as Timestamp?;
          final bTime = b.data()['createdAt'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime); // Descending order (newest first)
        });
        
        setState(() {
          reviews = docs.take(10).map((doc) => {
            'id': doc.id,
            ...doc.data(),
          }).toList();
          isLoadingReviews = false;
        });
      } else {
        setState(() {
          reviews = [];
          isLoadingReviews = false;
        });
      }
    } catch (e) {
      print('❌ Error loading reviews for doctor ${widget.doctorId}: $e');
      setState(() {
        isLoadingReviews = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _bookAppointment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentBookingScreen(
          preSelectedDoctor: doctor,
        ),
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    try {
      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:$minute $period';
      }
    } catch (e) {
      return time;
    }
    return time;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (doctor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Profile')),
        body: const Center(
          child: Text('Doctor not found', style: TextStyle(fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Doctor Image
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      // Profile Image
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: doctor!.profileImageUrl != null && 
                                 doctor!.profileImageUrl!.isNotEmpty
                              ? Image.network(
                                  doctor!.profileImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildDefaultAvatar(),
                                )
                              : _buildDefaultAvatar(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Doctor Name
                      Text(
                        'Dr. ${doctor!.name}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Specialization
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          doctor!.specialization,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Profile Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Stats Row
                  _buildQuickStats(),
                  const SizedBox(height: 24),

                  // About Section
                  _buildSectionCard(
                    'About',
                    Icons.person_outline,
                    _buildAboutContent(),
                  ),
                  const SizedBox(height: 16),

                  // Schedule Section
                  _buildSectionCard(
                    'Schedule & Availability',
                    Icons.access_time,
                    _buildScheduleContent(),
                  ),
                  const SizedBox(height: 16),

                  // Contact Section
                  _buildSectionCard(
                    'Contact Information',
                    Icons.contact_phone,
                    _buildContactContent(),
                  ),
                  const SizedBox(height: 16),

                  // Reviews Section
                  _buildSectionCard(
                    'Patient Reviews',
                    Icons.star_outline,
                    _buildReviewsContent(),
                  ),
                  const SizedBox(height: 100), // Space for floating button
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: FloatingActionButton.extended(
          onPressed: _bookAppointment,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Colors.white,
          elevation: 8,
          label: const Text(
            'Book Appointment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          icon: const Icon(Icons.calendar_today),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: 60,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Experience',
            '${doctor!.experienceYears ?? doctor!.experience ?? 0} years',
            Icons.work_outline,
          ),
          _buildStatItem(
            'Rating',
            '${doctor!.rating.toStringAsFixed(1)} ⭐',
            Icons.star_outline,
          ),
          _buildStatItem(
            'Fee',
            'PKR ${doctor!.consultationFee?.toString() ?? 'N/A'}',
            Icons.payment,
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.secondary,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildAboutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (doctor!.qualifications != null && doctor!.qualifications!.isNotEmpty) ...[
          _buildInfoRow('Qualifications', doctor!.qualifications!),
          const SizedBox(height: 12),
        ],
        if (doctor!.hospital != null && doctor!.hospital!.isNotEmpty) ...[
          _buildInfoRow('Hospital/Clinic', doctor!.hospital!),
          const SizedBox(height: 12),
        ],
        if (doctor!.licenseNumber != null && doctor!.licenseNumber!.isNotEmpty) ...[
          _buildInfoRow('License Number', doctor!.licenseNumber!),
          const SizedBox(height: 12),
        ],
        if (doctor!.address != null && doctor!.address!.isNotEmpty)
          _buildInfoRow('Address', doctor!.address!),
      ],
    );
  }

  Widget _buildScheduleContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (doctor!.availableDays != null && doctor!.availableDays!.isNotEmpty) ...[
          const Text(
            'Available Days:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: doctor!.availableDays!.map((day) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (doctor!.startTime != null && doctor!.endTime != null) ...[
          _buildInfoRow(
            'Working Hours',
            '${_formatTime(doctor!.startTime)} - ${_formatTime(doctor!.endTime)}',
          ),
        ],
      ],
    );
  }

  Widget _buildContactContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (doctor!.email != null && doctor!.email!.isNotEmpty) ...[
          _buildContactRow(Icons.email, 'Email', doctor!.email!),
          const SizedBox(height: 12),
        ],
        if (doctor!.phone != null && doctor!.phone!.isNotEmpty)
          _buildContactRow(Icons.phone, 'Phone', doctor!.phone!),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add Review Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showReviewDialog,
            icon: const Icon(Icons.rate_review),
            label: const Text('Write a Review'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              foregroundColor: Theme.of(context).colorScheme.secondary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Reviews List
        if (isLoadingReviews)
          const Center(child: CircularProgressIndicator())
        else if (reviews.isEmpty)
          Text(
            'No reviews yet. Be the first to review!',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${reviews.length} Review${reviews.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (reviews.length > 3)
                TextButton(
                  onPressed: () => _showAllReviews(),
                  child: const Text('View All'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...reviews.take(3).map((review) => _buildReviewCard(review)),
        ],
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review['patientName'] ?? 'Anonymous',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Row(
                children: List.generate(5, (index) => Icon(
                  index < (review['rating'] ?? 0)
                      ? Icons.star
                      : Icons.star_outline,
                  size: 16,
                  color: Colors.amber,
                )),
              ),
            ],
          ),
          if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review['comment'],
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _formatReviewDate(review['createdAt']),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}