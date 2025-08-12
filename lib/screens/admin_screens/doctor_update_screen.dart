import 'package:flutter/material.dart';
import '../../models/doctor_model.dart';
import '../../models/appointment_model.dart';

class DoctorUpdateScreen extends StatefulWidget {
  final Doctor doctor;
  final List<Appointment> appointments;
  final int initialCurrentPatientNo;
  final List<String> initialSlots;

  const DoctorUpdateScreen({
    super.key,
    required this.doctor,
    required this.appointments,
    this.initialCurrentPatientNo = 1,
    this.initialSlots = const [],
  });

  @override
  State<DoctorUpdateScreen> createState() => _DoctorUpdateScreenState();
}

class _DoctorUpdateScreenState extends State<DoctorUpdateScreen> {
  late int currentPatientNo;
  late List<String> availableSlots;
  final TextEditingController _slotController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentPatientNo = widget.initialCurrentPatientNo;
    availableSlots = List<String>.from(widget.initialSlots);
  }

  @override
  void dispose() {
    _slotController.dispose();
    super.dispose();
  }

  void _addSlot() {
    final slot = _slotController.text.trim();
    if (slot.isNotEmpty && !availableSlots.contains(slot)) {
      setState(() {
        availableSlots.add(slot);
        _slotController.clear();
      });
    }
  }

  void _removeSlot(String slot) {
    setState(() {
      availableSlots.remove(slot);
    });
  }

  void _incrementPatientNo() {
    setState(() {
      currentPatientNo++;
    });
  }

  void _decrementPatientNo() {
    setState(() {
      if (currentPatientNo > 1) currentPatientNo--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        backgroundColor: const Color(0xFF7E57C2),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDoctorInfo(),
            const SizedBox(height: 16),
            _buildCurrentPatientSection(),
            const SizedBox(height: 20),
            _buildSlotsSection(),
            const SizedBox(height: 20),
            _buildAppointmentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorInfo() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFEDE7F6),
              backgroundImage: (widget.doctor.profileImageUrl?.isNotEmpty ?? false)
                  ? NetworkImage(widget.doctor.profileImageUrl!)
                  : null,
              child: (widget.doctor.profileImageUrl?.isEmpty ?? true)
                  ? const Icon(Icons.person, color: Color(0xFF7E57C2), size: 32)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doctor.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    widget.doctor.specialization,
                    style: const TextStyle(
                      color: Color(0xFF7E57C2),
                      fontSize: 14,
                    ),
                  ),
                  if (widget.doctor.hospital != null && widget.doctor.hospital!.isNotEmpty)
                    Text(
                      widget.doctor.hospital!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPatientSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.people, color: Color(0xFF7E57C2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Currently seeing patient #$currentPatientNo',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: _decrementPatientNo,
              tooltip: 'Previous Patient',
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF7E57C2)),
              onPressed: _incrementPatientNo,
              tooltip: 'Next Patient',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotsSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Time Slots',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSlots.map((slot) => Chip(
                label: Text(slot),
                backgroundColor: const Color(0xFF7E57C2).withOpacity(0.1),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeSlot(slot),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _slotController,
                    decoration: const InputDecoration(
                      hintText: 'Add new slot (e.g. 10:00 AM)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addSlot,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Appointments',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (widget.appointments.isEmpty)
              const Text('No appointments for today.'),
            ...widget.appointments.map((appt) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person, color: Color(0xFF7E57C2)),
              title: Text(appt.userName),
              subtitle: Text('${appt.date} at ${appt.time}'),
              trailing: Text(
                appt.status,
                style: TextStyle(
                  color: appt.status == 'confirmed'
                      ? Colors.green
                      : appt.status == 'pending'
                          ? Colors.orange
                          : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}