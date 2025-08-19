// screens/doctor_screens/doctor_appointments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  final String doctorId;
  
  const DoctorAppointmentsScreen({super.key, required this.doctorId});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> with TickerProviderStateMixin {
  final AppointmentService _appointmentService = AppointmentService();
  
  late TabController _tabController;
  List<Appointment> _allAppointments = [];
  List<Appointment> _filteredAppointments = [];
  String _selectedFilter = 'all'; // all, today, upcoming, past
  String _selectedStatus = 'all'; // all, confirmed, pending, completed, cancelled
  bool _loading = true;
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() => _loading = true);
    
    try {
      // Load all appointments for this doctor
      final appointments = await _appointmentService.getAppointmentsForAdmin();
      
      // Filter appointments for this doctor and convert to Appointment objects
      final doctorAppointments = appointments
          .where((apt) => apt['doctorId'] == widget.doctorId)
          .map((apt) => Appointment.fromFirestore(apt['id'], apt))
          .toList();

      // Sort by date and time (newest first)
      doctorAppointments.sort((a, b) {
        final dateA = DateTime.parse(a.date);
        final dateB = DateTime.parse(b.date);
        if (dateA.isAtSameMomentAs(dateB)) {
          return _parseTime(a.time).compareTo(_parseTime(b.time));
        }
        return dateB.compareTo(dateA);
      });

      setState(() {
        _allAppointments = doctorAppointments;
        _loading = false;
      });
      
      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading appointments: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DateTime _parseTime(String time) {
    try {
      return DateFormat('h:mm a').parse(time);
    } catch (e) {
      return DateTime.now();
    }
  }

  void _applyFilters() {
    List<Appointment> filtered = List.from(_allAppointments);

    // Apply date filter
    switch (_selectedFilter) {
      case 'today':
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        filtered = filtered.where((apt) => apt.date == today).toList();
        break;
      case 'upcoming':
        final today = DateTime.now();
        filtered = filtered.where((apt) {
          final aptDate = DateTime.parse(apt.date);
          return aptDate.isAfter(today) || aptDate.isAtSameMomentAs(DateTime(today.year, today.month, today.day));
        }).toList();
        break;
      case 'past':
        final today = DateTime.now();
        filtered = filtered.where((apt) {
          final aptDate = DateTime.parse(apt.date);
          return aptDate.isBefore(DateTime(today.year, today.month, today.day));
        }).toList();
        break;
    }

    // Apply status filter
    if (_selectedStatus != 'all') {
      filtered = filtered.where((apt) => apt.status == _selectedStatus).toList();
    }

    setState(() {
      _filteredAppointments = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          onTap: (index) {
            switch (index) {
              case 0:
                _selectedFilter = 'all';
                break;
              case 1:
                _selectedFilter = 'today';
                break;
              case 2:
                _selectedFilter = 'upcoming';
                break;
              case 3:
                _selectedFilter = 'past';
                break;
            }
            _applyFilters();
          },
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats Section
          _buildStatsSection(),
          
          // Appointments List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAppointments,
                    child: _filteredAppointments.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredAppointments.length,
                            itemBuilder: (context, index) {
                              final appointment = _filteredAppointments[index];
                              return _buildAppointmentCard(appointment, index);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final todayCount = _allAppointments.where((apt) => 
      apt.date == DateFormat('yyyy-MM-dd').format(DateTime.now())
    ).length;
    
    final confirmedCount = _allAppointments.where((apt) => apt.status == 'confirmed').length;
    final completedCount = _allAppointments.where((apt) => apt.status == 'completed').length;
    final pendingCount = _allAppointments.where((apt) => apt.status == 'pending').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointments Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Today', todayCount, Colors.blue),
              ),
              Expanded(
                child: _buildStatItem('Confirmed', confirmedCount, Colors.green),
              ),
              Expanded(
                child: _buildStatItem('Completed', completedCount, Colors.purple),
              ),
              Expanded(
                child: _buildStatItem('Pending', pendingCount, Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(Appointment appointment, int index) {
    final appointmentDate = DateTime.parse(appointment.date);
    final isToday = DateFormat('yyyy-MM-dd').format(appointmentDate) == 
                   DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isPast = appointmentDate.isBefore(DateTime.now());

    Color statusColor = _getStatusColor(appointment.status);
    Color borderColor = isToday ? Colors.blue : (isPast ? Colors.grey : Colors.green);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor.withOpacity(0.3),
          width: isToday ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isToday ? Icons.today : (isPast ? Icons.history : Icons.schedule),
                      color: borderColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(appointmentDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: borderColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
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

            const SizedBox(height: 12),

            // Patient Info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            appointment.time,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            _getAppointmentTypeIcon(appointment.appointmentType),
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            appointment.appointmentType.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Contact Info
            if (appointment.userPhone.isNotEmpty || appointment.userEmail?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (appointment.userPhone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            appointment.userPhone,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    if (appointment.userEmail?.isNotEmpty == true) ...[
                      if (appointment.userPhone.isNotEmpty) const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            appointment.userEmail!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Symptoms/Notes
            if (appointment.symptoms?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medical_information,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Symptoms/Notes:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.symptoms!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                if (appointment.status == 'pending') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateAppointmentStatus(appointment.id, 'cancelled'),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateAppointmentStatus(appointment.id, 'confirmed'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else if (appointment.status == 'confirmed' && !isPast) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rescheduleAppointment(appointment),
                      icon: const Icon(Icons.schedule, size: 16),
                      label: const Text('Reschedule'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.secondary,
                        side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateAppointmentStatus(appointment.id, 'completed'),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewAppointmentDetails(appointment),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.secondary,
                        side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
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
            Icons.event_busy,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No appointments found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appointments will appear here when patients book with you',
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getAppointmentTypeIcon(String type) {
    switch (type) {
      case 'video_call':
        return Icons.videocam;
      case 'in_person':
        return Icons.local_hospital;
      case 'chat':
      default:
        return Icons.chat;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Filter Appointments'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['all', 'confirmed', 'pending', 'completed', 'cancelled']
                    .map((status) => ChoiceChip(
                          label: Text(status == 'all' ? 'All' : status.toUpperCase()),
                          selected: _selectedStatus == status,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedStatus = status);
                              _applyFilters();
                              Navigator.pop(context);
                            }
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      // TODO: Implement appointment status update in your service
      // await _appointmentService.updateAppointmentStatus(appointmentId, newStatus);
      
      setState(() {
        final index = _allAppointments.indexWhere((apt) => apt.id == appointmentId);
        if (index != -1) {
          _allAppointments[index] = Appointment.fromFirestore(
            _allAppointments[index].id,
            {
              ..._allAppointments[index].toFirestore(),
              'status': newStatus,
            },
          );
        }
      });
      
      _applyFilters();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment $newStatus successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating appointment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _rescheduleAppointment(Appointment appointment) {
    // TODO: Implement reschedule dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reschedule feature coming soon!'),
      ),
    );
  }

  void _viewAppointmentDetails(Appointment appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Appointment Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Patient', appointment.userName),
              _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(DateTime.parse(appointment.date))),
              _buildDetailRow('Time', appointment.time),
              _buildDetailRow('Type', appointment.appointmentType.replaceAll('_', ' ').toUpperCase()),
              _buildDetailRow('Status', appointment.status.toUpperCase()),
              if (appointment.userPhone.isNotEmpty)
                _buildDetailRow('Phone', appointment.userPhone),
              if (appointment.userEmail?.isNotEmpty == true)
                _buildDetailRow('Email', appointment.userEmail!),
              if (appointment.symptoms?.isNotEmpty == true)
                _buildDetailRow('Symptoms', appointment.symptoms!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}