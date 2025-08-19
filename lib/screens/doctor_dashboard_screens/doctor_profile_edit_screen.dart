// screens/doctor_screens/doctor_profile_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:doctorappoinmentapp/models/doctor_model.dart';
import 'doctor_update_screen.dart';

class DoctorProfileEditScreen extends StatefulWidget {
  final String doctorId;
  
  const DoctorProfileEditScreen({
    super.key,
    required this.doctorId,
  });

  @override
  State<DoctorProfileEditScreen> createState() => _DoctorProfileEditScreenState();
}

class _DoctorProfileEditScreenState extends State<DoctorProfileEditScreen> {
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

  Future<void> _loadReviews() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('doctorId', isEqualTo: widget.doctorId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      
      setState(() {
        reviews = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        isLoadingReviews = false;
      });
    } catch (e) {
      setState(() => isLoadingReviews = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorUpdateScreen(doctorId: widget.doctorId),
      ),
    );
    
    if (result == true) {
      _showSuccess('Profile updated successfully!');
      _loadDoctorProfile(); // Refresh the profile data
    }
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
        appBar: AppBar(
          title: const Text('My Profile'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (doctor == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Profile not found', style: TextStyle(fontSize: 18)),
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
            actions: [
              IconButton(
                onPressed: _navigateToEditProfile,
                icon: const Icon(Icons.edit, color: Colors.white),
                tooltip: 'Edit Profile',
              ),
            ],
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

                  // About Section with verification badge
                  _buildSectionCard(
                    'About',
                    Icons.person_outline,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Verification Status
                        if (doctor!.isVerified == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.green, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'Verified Doctor',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        _buildAboutContent(),
                      ],
                    ),
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
          onPressed: _navigateToEditProfile,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Colors.white,
          elevation: 8,
          label: const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          icon: const Icon(Icons.edit),
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
            doctor!.consultationFee != null 
                ? '\${doctor!.consultationFee.toString()}'
                : 'Not set',
            Icons.attach_money,
          ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              // Edit button for each section
              IconButton(
                onPressed: _navigateToEditProfile,
                icon: Icon(
                  Icons.edit,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                tooltip: 'Edit',
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
    final List<Widget> contentWidgets = [];
    
    if (doctor!.qualifications != null && doctor!.qualifications!.isNotEmpty) {
      contentWidgets.add(_buildInfoRow('Qualifications', doctor!.qualifications!));
      contentWidgets.add(const SizedBox(height: 12));
    }
    
    if (doctor!.hospital != null && doctor!.hospital!.isNotEmpty) {
      contentWidgets.add(_buildInfoRow('Hospital/Clinic', doctor!.hospital!));
      contentWidgets.add(const SizedBox(height: 12));
    }
    
    if (doctor!.licenseNumber != null && doctor!.licenseNumber!.isNotEmpty) {
      contentWidgets.add(_buildInfoRow('License Number', doctor!.licenseNumber!));
      contentWidgets.add(const SizedBox(height: 12));
    }
    
    if (doctor!.address != null && doctor!.address!.isNotEmpty) {
      contentWidgets.add(_buildInfoRow('Address', doctor!.address!));
    }
    
    if (contentWidgets.isEmpty) {
      return _buildEmptyState('No information available', 'Tap edit to add your details');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  Widget _buildScheduleContent() {
    final List<Widget> scheduleWidgets = [];
    
    if (doctor!.availableDays != null && doctor!.availableDays!.isNotEmpty) {
      scheduleWidgets.add(
        const Text(
          'Available Days:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
      scheduleWidgets.add(const SizedBox(height: 8));
      scheduleWidgets.add(
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
      );
      scheduleWidgets.add(const SizedBox(height: 16));
    }
    
    if (doctor!.startTime != null && doctor!.endTime != null) {
      scheduleWidgets.add(
        _buildInfoRow(
          'Working Hours',
          '${_formatTime(doctor!.startTime)} - ${_formatTime(doctor!.endTime)}',
        ),
      );
    }
    
    if (scheduleWidgets.isEmpty) {
      return _buildEmptyState('No schedule set', 'Set your working hours and available days');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: scheduleWidgets,
    );
  }

  Widget _buildContactContent() {
    final List<Widget> contactWidgets = [];
    
    if (doctor!.email != null && doctor!.email!.isNotEmpty) {
      contactWidgets.add(_buildContactRow(Icons.email, 'Email', doctor!.email!));
    }
    
    if (doctor!.phone != null && doctor!.phone!.isNotEmpty) {
      if (contactWidgets.isNotEmpty) {
        contactWidgets.add(const SizedBox(height: 12));
      }
      contactWidgets.add(_buildContactRow(Icons.phone, 'Phone', doctor!.phone!));
    }
    
    if (contactWidgets.isEmpty) {
      return _buildEmptyState('No contact information', 'Add your email and phone number');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contactWidgets,
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
    if (isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reviews.isEmpty) {
      return _buildEmptyState('No reviews yet', 'Patient reviews will appear here');
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Reviews (${reviews.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (reviews.length > 3)
              TextButton(
                onPressed: () {
                  // TODO: Navigate to all reviews screen
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...reviews.take(3).map((review) => Container(
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
              const SizedBox(height: 8),
              Text(
                review['comment'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ))
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
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