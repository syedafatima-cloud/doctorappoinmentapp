// screens/doctor_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
            '\$${doctor!.consultationFee?.toString() ?? 'N/A'}',
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
    if (isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reviews.isEmpty) {
      return Text(
        'No reviews yet',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      children: reviews.take(3).map((review) => Container(
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
      )).toList(),
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