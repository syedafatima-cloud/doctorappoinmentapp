// screens/admin_appointments_screen.dart
import 'package:flutter/material.dart';
import 'package:doctorappoinmentapp/services/admin_services.dart';
import 'package:doctorappoinmentapp/models/appointment_model.dart';

class AdminAppointmentsScreen extends StatefulWidget {
  final String adminId;
  
  const AdminAppointmentsScreen({super.key, required this.adminId});

  @override
  State<AdminAppointmentsScreen> createState() => _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState extends State<AdminAppointmentsScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;
  
  List<Appointment> _allAppointments = [];
  List<Appointment> _todayAppointments = [];
  List<Appointment> _upcomingAppointments = [];
  List<Appointment> _completedAppointments = [];
  
  bool _isLoading = true;
  final String _selectedDateFilter = 'all';

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
    setState(() => _isLoading = true);
    
    try {
      final appointmentsData = await _adminService.getAllAppointments();
      final appointments = appointmentsData.map((data) => 
        Appointment.fromFirestore(data['id'], data)
      ).toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      setState(() {
        _allAppointments = appointments;
        _todayAppointments = appointments.where((apt) {
          final aptDate = DateTime.tryParse(apt.date);
          return aptDate != null && 
                 DateTime(aptDate.year, aptDate.month, aptDate.day) == today;
        }).toList();
        
        _upcomingAppointments = appointments.where((apt) {
          final aptDate = DateTime.tryParse(apt.date);
          return aptDate != null && aptDate.isAfter(now) && apt.status != 'completed';
        }).toList();
        
        _completedAppointments = appointments.where((apt) => 
          apt.status == 'completed'
        ).toList();
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  Future<void> _updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      await _adminService.updateAppointmentStatus(appointmentId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating appointment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAppointmentDetails(Appointment appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment.status),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Appointment Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Patient Name', appointment.userName),
                        _buildDetailRow('Phone', appointment.userPhone),
                        _buildDetailRow('Doctor', appointment.doctorName),
                        _buildDetailRow('Date', appointment.date),
                        _buildDetailRow('Time', appointment.time),
                        _buildDetailRow('Type', appointment.appointmentType),
                        _buildDetailRow('Status', appointment.status.toUpperCase()),
                      ],
                    ),
                  ),
                ),
                // Status Update Actions
                if (appointment.status != 'completed' && appointment.status != 'cancelled')
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (appointment.status != 'confirmed')
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _updateAppointmentStatus(appointment.id, 'confirmed');
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                          ),
                        if (appointment.status == 'confirmed')
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _updateAppointmentStatus(appointment.id, 'completed');
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            child: const Text('Complete', style: TextStyle(color: Colors.white)),
                          ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _updateAppointmentStatus(appointment.id, 'cancelled');
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
            maxLines: isMultiLine ? null : 1,
            overflow: isMultiLine ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.all_inbox),
                  const SizedBox(width: 4),
                  Text('All (${_allAppointments.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.today),
                  const SizedBox(width: 4),
                  Text('Today (${_todayAppointments.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule),
                  const SizedBox(width: 4),
                  Text('Upcoming (${_upcomingAppointments.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle),
                  const SizedBox(width: 4),
                  Text('Completed (${_completedAppointments.length})'),
                ],
              ),
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentsList(_allAppointments),
                _buildAppointmentsList(_todayAppointments),
                _buildAppointmentsList(_upcomingAppointments),
                _buildAppointmentsList(_completedAppointments),
              ],
            ),
    );
  }

  Widget _buildAppointmentsList(List<Appointment> appointments) {
    if (appointments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No appointments found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
          return _buildAppointmentCard(appointment);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(appointment.status),
          child: Icon(
            _getStatusIcon(appointment.status),
            color: Colors.white,
          ),
        ),
        title: Text(
          'Patient: ${appointment.userName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doctor: ${appointment.doctorName}'),
            Text('Date: ${appointment.date} at ${appointment.time}'),
            Text('Type: ${appointment.appointmentType}'),
            Text('Phone: ${appointment.userPhone}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(appointment.status),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            appointment.status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _showAppointmentDetails(appointment),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check;
      case 'pending':
        return Icons.hourglass_empty;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.event;
    }
  }
}