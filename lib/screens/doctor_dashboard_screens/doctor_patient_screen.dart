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

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  List<Map<String, dynamic>> _uniquePatients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    
    try {
      // Load all appointments for this doctor
      final appointmentsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .get();

      // Extract unique patients with their history
      final patientsMap = <String, Map<String, dynamic>>{};
      
      for (final doc in appointmentsQuery.docs) {
        final appointment = doc.data();
        final patientKey = '${appointment['userName']}_${appointment['userPhone']}';
        
        final appointmentDate = _parseDate(appointment['date'] ?? '');
        
        if (!patientsMap.containsKey(patientKey)) {
          patientsMap[patientKey] = {
            'name': appointment['userName'] ?? 'Unknown',
            'phone': appointment['userPhone'] ?? '',
            'email': appointment['userEmail'] ?? '',
            'firstVisit': appointmentDate,
            'lastVisit': appointmentDate,
            'totalAppointments': 1,
            'completedAppointments': appointment['status'] == 'completed' ? 1 : 0,
            'lastSymptoms': appointment['symptoms'] ?? '',
            'appointmentTypes': [appointment['appointmentType'] ?? 'chat'],
            'lastStatus': appointment['status'] ?? 'pending',
            'appointmentHistory': [appointment],
          };
        } else {
          final patient = patientsMap[patientKey]!;
          patient['totalAppointments'] = (patient['totalAppointments'] as int) + 1;
          
          if (appointment['status'] == 'completed') {
            patient['completedAppointments'] = (patient['completedAppointments'] as int) + 1;
          }
          
          // Update first visit if this is earlier
          final firstVisit = patient['firstVisit'] as DateTime;
          if (appointmentDate.isBefore(firstVisit)) {
            patient['firstVisit'] = appointmentDate;
          }
          
          // Update last visit if this is more recent
          final lastVisit = patient['lastVisit'] as DateTime;
          if (appointmentDate.isAfter(lastVisit)) {
            patient['lastVisit'] = appointmentDate;
            patient['lastSymptoms'] = appointment['symptoms'] ?? '';
            patient['lastStatus'] = appointment['status'] ?? 'pending';
          }
          
          // Add appointment type if not already present
          final types = patient['appointmentTypes'] as List<dynamic>;
          final currentType = appointment['appointmentType'] ?? 'chat';
          if (!types.contains(currentType)) {
            types.add(currentType);
          }
          
          // Add to history
          (patient['appointmentHistory'] as List).add(appointment);
        }
      }

      final uniquePatients = patientsMap.values.toList();
      
      // Sort by last visit (most recent first)
      uniquePatients.sort((a, b) {
        final dateA = a['lastVisit'] as DateTime;
        final dateB = b['lastVisit'] as DateTime;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _uniquePatients = uniquePatients;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading patients: $e');
      setState(() => _isLoading = false);
      _showError('Failed to load patients: $e');
    }
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

  List<Map<String, dynamic>> _getFilteredPatients() {
    if (_searchQuery.isEmpty) return _uniquePatients;

    return _uniquePatients.where((patient) {
      final name = (patient['name'] ?? '').toString().toLowerCase();
      final phone = (patient['phone'] ?? '').toString().toLowerCase();
      final symptoms = (patient['lastSymptoms'] ?? '').toString().toLowerCase();
      
      return name.contains(_searchQuery.toLowerCase()) ||
             phone.contains(_searchQuery.toLowerCase()) ||
             symptoms.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showPatientHistory(Map<String, dynamic> patient) {
    final history = patient['appointmentHistory'] as List;
    
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
                    '${patient['totalAppointments']} total visits',
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
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('📱 Phone', patient['phone'] ?? 'Not provided'),
                    if (patient['email']?.isNotEmpty == true)
                      _buildDetailRow('📧 Email', patient['email']),
                    _buildDetailRow('🗓️ First Visit', 
                        DateFormat('MMM dd, yyyy').format(patient['firstVisit'])),
                    _buildDetailRow('🗓️ Last Visit', 
                        DateFormat('MMM dd, yyyy').format(patient['lastVisit'])),
                    _buildDetailRow('✅ Completed', 
                        '${patient['completedAppointments']}/${patient['totalAppointments']}'),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Appointment History:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              
              // Appointment History List
              Expanded(
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final appointment = history[index];
                    final date = _parseDate(appointment['date'] ?? '');
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(appointment['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            appointment['status']?.toUpperCase() ?? 'PENDING',
                            style: TextStyle(
                              fontSize: 10,
                              color: _getStatusColor(appointment['status']),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          DateFormat('MMM dd, yyyy').format(date),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${appointment['time']} • ${_getAppointmentTypeDisplay(appointment['appointmentType'])}'),
                            if (appointment['symptoms']?.isNotEmpty == true)
                              Text(
                                appointment['symptoms'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Icon(
                          _getAppointmentTypeIcon(appointment['appointmentType']),
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  },
                ),
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
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
      case 'confirmed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPatients = _getFilteredPatients();
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('My Patients - Dr. ${widget.doctorName}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadPatients,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar and Stats
          Container(
            color: Theme.of(context).primaryColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search patients by name, phone, or symptoms...',
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
                
                const SizedBox(height: 16),
                
                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Patients',
                        _uniquePatients.length.toString(),
                        Icons.people,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Active This Month',
                        _uniquePatients.where((p) {
                          final lastVisit = p['lastVisit'] as DateTime;
                          return DateTime.now().difference(lastVisit).inDays <= 30;
                        }).length.toString(),
                        Icons.trending_up,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Patients List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPatients.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPatients,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredPatients.length,
                          itemBuilder: (context, index) {
                            final patient = filteredPatients[index];
                            return _buildPatientCard(patient);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final lastVisit = patient['lastVisit'] as DateTime;
    final daysSinceLastVisit = DateTime.now().difference(lastVisit).inDays;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showPatientHistory(patient),
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
                          '${patient['totalAppointments']} visits',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          daysSinceLastVisit == 0 
                              ? 'Today'
                              : daysSinceLastVisit == 1
                                  ? 'Yesterday'
                                  : '$daysSinceLastVisit days ago',
                          style: TextStyle(
                            fontSize: 12,
                            color: daysSinceLastVisit <= 7 ? Colors.green[600] : Colors.grey[500],
                          ),
                        ),
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
                      '${patient['completedAppointments']}/${patient['totalAppointments']}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
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

  Widget _buildEmptyState() {
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
}