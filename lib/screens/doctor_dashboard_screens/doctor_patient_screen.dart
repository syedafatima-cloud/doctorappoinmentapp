// screens/doctor_screens/doctor_patients_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorPatientsScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  
  const DoctorPatientsScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Map<String, dynamic>> _allAppointments = [];
  List<Map<String, dynamic>> _todayAppointments = [];
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _pastAppointments = [];
  List<Map<String, dynamic>> _uniquePatients = [];
  
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔍 Loading appointments for doctor: ${widget.doctorId}');
      
      // Get all appointments for this doctor
      final appointmentsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .orderBy('date', descending: true)
          .get();

      final allAppointments = <Map<String, dynamic>>[];
      final today = DateTime.now();
      final todayString = _formatDate(today);

      for (final doc in appointmentsQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Parse appointment date
        final appointmentDate = _parseDate(data['date'] ?? '');
        data['parsedDate'] = appointmentDate;
        
        allAppointments.add(data);
      }

      // Categorize appointments
      final todayAppts = <Map<String, dynamic>>[];
      final upcomingAppts = <Map<String, dynamic>>[];
      final pastAppts = <Map<String, dynamic>>[];

      for (final appointment in allAppointments) {
        final apptDate = appointment['parsedDate'] as DateTime?;
        if (apptDate != null) {
          final apptDateString = _formatDate(apptDate);
          
          if (apptDateString == todayString) {
            todayAppts.add(appointment);
          } else if (apptDate.isAfter(today)) {
            upcomingAppts.add(appointment);
          } else {
            pastAppts.add(appointment);
          }
        }
      }

      // Sort appointments by time within each category
      todayAppts.sort((a, b) => _compareAppointmentTime(a, b));
      upcomingAppts.sort((a, b) => _compareAppointmentTime(a, b));
      pastAppts.sort((a, b) => -_compareAppointmentTime(a, b)); // Recent first

      // Extract unique patients
      final patientsMap = <String, Map<String, dynamic>>{};
      for (final appointment in allAppointments) {
        final patientKey = '${appointment['userName']}_${appointment['userPhone']}';
        if (!patientsMap.containsKey(patientKey)) {
          patientsMap[patientKey] = {
            'name': appointment['userName'] ?? 'Unknown',
            'phone': appointment['userPhone'] ?? '',
            'email': appointment['userEmail'] ?? '',
            'lastAppointment': appointment['parsedDate'],
            'totalAppointments': 1,
            'lastSymptoms': appointment['symptoms'] ?? '',
            'appointmentTypes': [appointment['appointmentType'] ?? 'chat'],
          };
        } else {
          final patient = patientsMap[patientKey]!;
          patient['totalAppointments'] = (patient['totalAppointments'] as int) + 1;
          
          // Update last appointment if this one is more recent
          final lastDate = patient['lastAppointment'] as DateTime?;
          final currentDate = appointment['parsedDate'] as DateTime?;
          if (currentDate != null && (lastDate == null || currentDate.isAfter(lastDate))) {
            patient['lastAppointment'] = currentDate;
            patient['lastSymptoms'] = appointment['symptoms'] ?? '';
          }
          
          // Add appointment type if not already present
          final types = patient['appointmentTypes'] as List<dynamic>;
          final currentType = appointment['appointmentType'] ?? 'chat';
          if (!types.contains(currentType)) {
            types.add(currentType);
          }
        }
      }

      final uniquePatients = patientsMap.values.toList();
      uniquePatients.sort((a, b) {
        final dateA = a['lastAppointment'] as DateTime?;
        final dateB = b['lastAppointment'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _allAppointments = allAppointments;
        _todayAppointments = todayAppts;
        _upcomingAppointments = upcomingAppts;
        _pastAppointments = pastAppts;
        _uniquePatients = uniquePatients;
        _isLoading = false;
      });
      
      print('✅ Loaded ${allAppointments.length} appointments');
      print('📊 Today: ${todayAppts.length}, Upcoming: ${upcomingAppts.length}, Past: ${pastAppts.length}');
      print('👥 Unique patients: ${uniquePatients.length}');
      
    } catch (e) {
      print('❌ Error loading appointments: $e');
      setState(() => _isLoading = false);
      _showError('Failed to load appointments: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseDate(String dateString) {
    try {
      final parts = dateString.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (e) {
      print('Error parsing date: $dateString');
    }
    return DateTime.now();
  }

  int _compareAppointmentTime(Map<String, dynamic> a, Map<String, dynamic> b) {
    try {
      final timeA = _parseTimeString(a['time'] ?? '9:00 AM');
      final timeB = _parseTimeString(b['time'] ?? '9:00 AM');
      return timeA.compareTo(timeB);
    } catch (e) {
      return 0;
    }
  }

  DateTime _parseTimeString(String timeStr) {
    final parts = timeStr.split(' ');
    final timePart = parts[0];
    final amPm = parts[1].toUpperCase();
    
    final timeSplit = timePart.split(':');
    int hour = int.parse(timeSplit[0]);
    int minute = int.parse(timeSplit[1]);
    
    if (amPm == 'PM' && hour != 12) {
      hour += 12;
    } else if (amPm == 'AM' && hour == 12) {
      hour = 0;
    }
    
    return DateTime(2024, 1, 1, hour, minute);
  }

  List<Map<String, dynamic>> _getFilteredData() {
    List<Map<String, dynamic>> data;
    
    switch (_tabController.index) {
      case 0:
        data = _todayAppointments;
        break;
      case 1:
        data = _upcomingAppointments;
        break;
      case 2:
        data = _pastAppointments;
        break;
      case 3:
        data = _uniquePatients;
        break;
      default:
        data = [];
    }

    if (_searchQuery.isEmpty) return data;

    return data.where((item) {
      final name = (item['userName'] ?? item['name'] ?? '').toString().toLowerCase();
      final phone = (item['userPhone'] ?? item['phone'] ?? '').toString().toLowerCase();
      final symptoms = (item['symptoms'] ?? item['lastSymptoms'] ?? '').toString().toLowerCase();
      
      return name.contains(_searchQuery.toLowerCase()) ||
             phone.contains(_searchQuery.toLowerCase()) ||
             symptoms.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _showSuccess('Appointment status updated');
      _loadAppointments();
    } catch (e) {
      _showError('Failed to update appointment: $e');
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.person, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                appointment['userName'] ?? 'Unknown Patient',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('📅 Date', 
                  DateFormat('EEEE, MMM dd, yyyy').format(appointment['parsedDate'])),
              _buildDetailRow('🕒 Time', appointment['time'] ?? 'Not specified'),
              _buildDetailRow('📱 Phone', appointment['userPhone'] ?? 'Not provided'),
              if (appointment['userEmail']?.isNotEmpty == true)
                _buildDetailRow('📧 Email', appointment['userEmail']),
              _buildDetailRow('💬 Type', _getAppointmentTypeDisplay(appointment['appointmentType'])),
              _buildDetailRow('📋 Status', appointment['status'] ?? 'scheduled'),
              if (appointment['symptoms']?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                const Text(
                  'Symptoms & Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    appointment['symptoms'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (appointment['status'] != 'completed' && appointment['status'] != 'cancelled') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateAppointmentStatus(appointment['id'], 'completed');
              },
              child: const Text('Mark Complete'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateAppointmentStatus(appointment['id'], 'cancelled');
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                (patient['name'] as String).isNotEmpty 
                    ? (patient['name'] as String)[0].toUpperCase()
                    : 'P',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient['name'] ?? 'Unknown Patient',
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    '${patient['totalAppointments']} appointments',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('📱 Phone', patient['phone'] ?? 'Not provided'),
              if (patient['email']?.isNotEmpty == true)
                _buildDetailRow('📧 Email', patient['email']),
              _buildDetailRow('📊 Total Visits', '${patient['totalAppointments']}'),
              if (patient['lastAppointment'] != null)
                _buildDetailRow('🗓️ Last Visit', 
                    DateFormat('MMM dd, yyyy').format(patient['lastAppointment'])),
              _buildDetailRow('💬 Consultation Types', 
                  (patient['appointmentTypes'] as List).map((type) => 
                      _getAppointmentTypeDisplay(type)).join(', ')),
              if (patient['lastSymptoms']?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                const Text(
                  'Last Symptoms/Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    patient['lastSymptoms'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _getAppointmentTypeDisplay(String? type) {
    switch (type) {
      case 'chat':
        return 'Chat';
      case 'video_call':
        return 'Video Call';
      case 'in_person':
        return 'In-Person';
      default:
        return 'Chat';
    }
  }

  IconData _getAppointmentTypeIcon(String? type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'video_call':
        return Icons.videocam_outlined;
      case 'in_person':
        return Icons.local_hospital_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'scheduled':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Patients - Dr. ${widget.doctorName}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search patients, phone, or symptoms...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.clear, color: Colors.white),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              
              // Tab Bar
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.today, size: 20),
                    text: 'Today (${_todayAppointments.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.schedule, size: 20),
                    text: 'Upcoming (${_upcomingAppointments.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.history, size: 20),
                    text: 'Past (${_pastAppointments.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.people, size: 20),
                    text: 'Patients (${_uniquePatients.length})',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentsList(_getFilteredData(), 'today'),
                _buildAppointmentsList(_getFilteredData(), 'upcoming'),
                _buildAppointmentsList(_getFilteredData(), 'past'),
                _buildPatientsList(_getFilteredData()),
              ],
            ),
    );
  }

  Widget _buildAppointmentsList(List<Map<String, dynamic>> appointments, String type) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'today' ? Icons.today : 
              type == 'upcoming' ? Icons.schedule : Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              type == 'today' ? 'No appointments today' :
              type == 'upcoming' ? 'No upcoming appointments' : 'No past appointments',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type == 'today' ? 'Your schedule is clear for today!' :
              type == 'upcoming' ? 'No future appointments scheduled' : 'No appointment history found',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          return _buildAppointmentCard(appointment, type);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, String type) {
    final status = appointment['status'] ?? 'scheduled';
    final statusColor = _getStatusColor(status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAppointmentDetails(appointment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      (appointment['userName'] ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment['userName'] ?? 'Unknown Patient',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          appointment['userPhone'] ?? 'No phone',
                          style: TextStyle(
                            fontSize: 14,
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
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    appointment['time'] ?? 'Time not set',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    _getAppointmentTypeIcon(appointment['appointmentType']),
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getAppointmentTypeDisplay(appointment['appointmentType']),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (type != 'today') ...[
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd').format(appointment['parsedDate']),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
              if (appointment['symptoms']?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    appointment['symptoms'],
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientsList(List<Map<String, dynamic>> patients) {
    if (patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No patients found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Patients will appear here after appointments',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: patients.length,
        itemBuilder: (context, index) {
          final patient = patients[index];
          return _buildPatientCard(patient);
        },
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final lastAppointment = patient['lastAppointment'] as DateTime?;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showPatientDetails(patient),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  (patient['name'] as String).isNotEmpty 
                      ? (patient['name'] as String)[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient['name'] ?? 'Unknown Patient',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient['phone'] ?? 'No phone',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${patient['totalAppointments']} appointments',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (lastAppointment != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            'Last: ${DateFormat('MMM dd').format(lastAppointment)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${patient['totalAppointments']}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: (patient['appointmentTypes'] as List)
                        .take(3)
                        .map((type) => Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                _getAppointmentTypeIcon(type),
                                size: 12,
                                color: Colors.grey[500],
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}