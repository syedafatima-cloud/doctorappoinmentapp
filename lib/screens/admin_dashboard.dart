// Simple Admin Dashboard
import 'package:doctorappoinmentapp/services/admin_services.dart';
import 'package:flutter/material.dart';
import 'package:doctorappoinmentapp/models/appointment_model.dart';
// Simplified Admin Dashboard
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  List<Appointment> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final appointmentsData = await _adminService.getAllAppointments();
      setState(() {
        _appointments = appointmentsData.map((data) => 
          Appointment.fromFirestore(data['id'], data)
        ).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      print('Error fetching appointments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAppointments,
              child: ListView.builder(
                itemCount: _appointments.length,
                itemBuilder: (context, index) {
                  final appointment = _appointments[index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(appointment.userName.substring(0, 1).toUpperCase()),
                      ),
                      title: Text('Patient: ${appointment.userName}'),
                      subtitle: Text(
                        'Date: ${appointment.date}\n'
                        'Time: ${appointment.time}\n'
                        'Phone: ${appointment.userPhone}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: appointment.status == 'confirmed' 
                            ? Colors.green 
                            : appointment.status == 'pending'
                              ? Colors.orange
                              : Colors.red,
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
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAppointments,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}