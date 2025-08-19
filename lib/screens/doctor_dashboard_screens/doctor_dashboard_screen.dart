// screens/doctor_dashboard_screen.dart
import 'package:doctorappoinmentapp/models/appointment_model.dart';
import 'package:doctorappoinmentapp/screens/admin_screens/doctor_update_screen.dart';
import 'package:doctorappoinmentapp/screens/doctor_dashboard_screens/docor_appointments_screen.dart';
import 'package:doctorappoinmentapp/screens/doctor_dashboard_screens/doctor_earning_screen.dart';
import 'package:doctorappoinmentapp/screens/doctor_dashboard_screens/doctor_patient_screen.dart';
import 'package:doctorappoinmentapp/screens/doctor_dashboard_screens/doctor_profile_edit_screen.dart';
import 'package:doctorappoinmentapp/screens/doctor_dashboard_screens/doctor_timeslot_screen.dart';
import 'package:flutter/material.dart';
import 'package:doctorappoinmentapp/models/doctor_model.dart';
import 'package:doctorappoinmentapp/services/appointment_service.dart';
import 'package:doctorappoinmentapp/services/doctor_register_service.dart';


class DoctorDashboard extends StatefulWidget {
  final String doctorId;
  
  const DoctorDashboard({super.key, required this.doctorId});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final AppointmentService _appointmentService = AppointmentService();
  final DoctorRegistrationService _doctorService = DoctorRegistrationService();
  
  Doctor? _doctor;
  Map<String, int> _dashboardStats = {};
  List<Appointment> _todayAppointments = [];
  bool _loading = true;
  bool _isOnline = true;
  int _currentPatientNo = 1;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);
    
    try {
      // Load doctor data
      final doctor = await _doctorService.getDoctorById(widget.doctorId);
      
      // Load today's appointments
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final appointments = await _appointmentService.getAppointmentsForAdmin(
        date: todayString,
        status: 'confirmed',
      );
      
      // Filter appointments for this doctor
      final doctorAppointments = appointments
          .where((apt) => apt['doctorId'] == widget.doctorId)
          .map((apt) => Appointment.fromFirestore(apt['id'], apt))
          .toList();

      // Calculate stats
      final totalAppointments = await _getTotalAppointments();
      final completedToday = doctorAppointments.where((apt) => apt.status == 'completed').length;
      final pendingToday = doctorAppointments.where((apt) => apt.status == 'confirmed').length;
      
      setState(() {
        _doctor = doctor as Doctor?;
        _todayAppointments = doctorAppointments;
        _dashboardStats = {
          'todayAppointments': doctorAppointments.length,
          'completedToday': completedToday,
          'pendingToday': pendingToday,
          'totalAppointments': totalAppointments,
        };
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<int> _getTotalAppointments() async {
    try {
      final appointments = await _appointmentService.getAppointmentsForAdmin();
      return appointments.where((apt) => apt['doctorId'] == widget.doctorId).length;
    } catch (e) {
      return 0;
    }
  }

  void _toggleOnlineStatus() {
    setState(() {
      _isOnline = !_isOnline;
    });
    // TODO: Update online status in Firestore
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Online/Offline Toggle
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(fontSize: 12),
                ),
                Switch(
                  value: _isOnline,
                  onChanged: (value) => _toggleOnlineStatus(),
                  activeColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _navigateToProfile();
                  break;
                case 'settings':
                  // Navigate to settings
                  break;
                case 'logout':
                  _showLogoutDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    _buildWelcomeSection(),
                    const SizedBox(height: 24),
                    
                    // Quick Stats Section
                    _buildQuickStatsSection(),
                    const SizedBox(height: 24),
                    
                    // Current Patient Section
                    _buildCurrentPatientSection(),
                    const SizedBox(height: 24),
                    
                    // Main Features Section
                    _buildMainFeaturesSection(),
                    const SizedBox(height: 24),
                    
                    // Today's Appointments Section
                    _buildTodayAppointmentsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).colorScheme.secondary.withOpacity(0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: (_doctor?.profileImageUrl?.isNotEmpty == true)
                    ? NetworkImage(_doctor!.profileImageUrl!)
                    : null,
                child: (_doctor?.profileImageUrl?.isEmpty != false)
                    ? const Icon(Icons.person, color: Colors.white, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, Dr. ${_doctor?.name ?? 'Doctor'}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _doctor?.specialization ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _doctor?.hospital ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.white.withOpacity(0.8), size: 16),
              const SizedBox(width: 4),
              Text(
                'Last updated: ${DateTime.now().toString().substring(0, 16)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Today\'s Appointments',
                _dashboardStats['todayAppointments']?.toString() ?? '0',
                Icons.event,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Completed',
                _dashboardStats['completedToday']?.toString() ?? '0',
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Pending',
                _dashboardStats['pendingToday']?.toString() ?? '0',
                Icons.hourglass_empty,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Patients',
                _dashboardStats['totalAppointments']?.toString() ?? '0',
                Icons.people,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPatientSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.people,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Patient',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Patient #$_currentPatientNo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_currentPatientNo > 1) {
                    setState(() => _currentPatientNo--);
                  }
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                tooltip: 'Previous Patient',
              ),
              IconButton(
                onPressed: () {
                  setState(() => _currentPatientNo++);
                },
                icon: const Icon(Icons.add_circle_outline),
                color: Theme.of(context).colorScheme.secondary,
                tooltip: 'Next Patient',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildFeatureCard(
              'Appointments',
              'View and manage appointments',
              Icons.event,
              Colors.blue,
              () => _navigateToAppointments(),
            ),
            _buildFeatureCard(
              'Time Slots',
              'Manage available time slots',
              Icons.schedule,
              Colors.green,
              () => _navigateToTimeSlots(),
            ),
            _buildFeatureCard(
              'Patients',
              'View patient records',
              Icons.people,
              Colors.orange,
              () => _navigateToPatients(),
            ),
            _buildFeatureCard(
              'Earnings',
              'View earnings and reports',
              Icons.attach_money,
              Colors.purple,
              () => _navigateToEarnings(),
            ),
            _buildFeatureCard(
              'Profile',
              'Update your profile',
              Icons.person,
              Colors.teal,
              () => _navigateToProfile(),
            ),
            _buildFeatureCard(
              'Update Profile',
              'Edit profile details',
              Icons.edit,
              Theme.of(context).colorScheme.secondary,
              () => _navigateToUpdateProfile(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayAppointmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Today\'s Appointments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToAppointments(),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _todayAppointments.isEmpty
                ? [
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_busy, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No appointments today',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ]
                : _todayAppointments.take(3).map((appointment) {
                    return Column(
                      children: [
                        _buildAppointmentItem(appointment),
                        if (_todayAppointments.indexOf(appointment) < 2 &&
                            _todayAppointments.indexOf(appointment) < _todayAppointments.length - 1)
                          const Divider(),
                      ],
                    );
                  }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentItem(Appointment appointment) {
    Color statusColor;
    switch (appointment.status) {
      case 'confirmed':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'completed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${appointment.time} • ${appointment.appointmentType}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              appointment.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAppointments() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DoctorAppointmentsScreen(
        doctorId: widget.doctorId,
      ),
    ),
  ).then((result) {
    // Refresh dashboard when returning from appointments screen
    if (result == true) {
      _loadDashboardData();
    }
  });
}

  void _navigateToTimeSlots() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorTimeSlotsManagement(
          doctorId: widget.doctorId,
          doctorName: _doctor?.name ?? 'Doctor',
        ),
      ),
    );
  }

  void _navigateToPatients() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorPatientsScreen(
          doctorId: widget.doctorId,
          doctorName: _doctor?.name ?? 'Doctor',
        ),
      ),
    );
  }

  void _navigateToEarnings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorEarningsScreen(
          doctorId: widget.doctorId,
          doctorName: _doctor?.name ?? 'Doctor',
        ),
      ),
    );
  }

  void _navigateToProfile() {
    if (_doctor != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorProfileEditScreen(
            doctorId: widget.doctorId,
          ),
        ),
      );
    }
  }

  void _navigateToUpdateProfile() {
  if (_doctor != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorUpdateScreen(
          doctor: _doctor!,
          appointments: _todayAppointments,
          initialCurrentPatientNo: _currentPatientNo,
          initialSlots: [], // You can populate this with current available slots if needed
        ),
      ),
    ).then((result) {
      // Refresh dashboard if profile was updated
      if (result == true) {
        _loadDashboardData();
      }
    });
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Doctor information not loaded yet. Please try again.'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Implement logout logic here
                Navigator.of(context).pushReplacementNamed('/login');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}