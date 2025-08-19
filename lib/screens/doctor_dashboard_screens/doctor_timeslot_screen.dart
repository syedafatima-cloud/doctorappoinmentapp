// screens/doctor_screens/doctor_time_slots_management.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:doctorappoinmentapp/services/appointment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorTimeSlotsManagement extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  
  const DoctorTimeSlotsManagement({
    super.key, 
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorTimeSlotsManagement> createState() => _DoctorTimeSlotsManagementState();
}

class _DoctorTimeSlotsManagementState extends State<DoctorTimeSlotsManagement> {
  final AppointmentService _appointmentService = AppointmentService();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<Map<String, dynamic>> _timeSlots = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  
  // Available time options for creating new slots
  final List<String> _availableTimes = [
    '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
    '12:00 PM', '12:30 PM', '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
    '3:00 PM', '3:30 PM', '4:00 PM', '4:30 PM', '5:00 PM', '5:30 PM',
    '6:00 PM', '6:30 PM', '7:00 PM', '7:30 PM', '8:00 PM', '8:30 PM'
  ];

  @override
  void initState() {
    super.initState();
    _loadTimeSlots();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTimeSlots() async {
    setState(() => _isLoading = true);
    
    try {
      final dateString = _formatDate(_selectedDate);
      print('🔍 Loading time slots for doctor: ${widget.doctorId}, date: $dateString');
      
      // Get time slots from Firestore
      final slotsQuery = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('time_slots')
          .doc(dateString)
          .get();

      List<Map<String, dynamic>> slots = [];
      
      if (slotsQuery.exists && slotsQuery.data() != null) {
        final data = slotsQuery.data()!;
        
        // Convert the slots map to a list
        if (data['slots'] != null) {
          final slotsMap = data['slots'] as Map<String, dynamic>;
          slots = slotsMap.entries.map((entry) {
            final slotData = entry.value as Map<String, dynamic>;
            return {
              'time': entry.key,
              'isAvailable': slotData['isAvailable'] ?? true,
              'isBooked': slotData['isBooked'] ?? false,
              'bookedBy': slotData['bookedBy'],
              'bookingId': slotData['bookingId'],
              'appointmentType': slotData['appointmentType'],
            };
          }).toList();
        }
      }
      
      // Sort slots by time
      slots.sort((a, b) => _compareTime(a['time'], b['time']));
      
      setState(() {
        _timeSlots = slots;
        _isLoading = false;
      });
      
      print('✅ Loaded ${_timeSlots.length} time slots');
    } catch (e) {
      print('❌ Error loading time slots: $e');
      setState(() => _isLoading = false);
      _showError('Failed to load time slots: $e');
    }
  }

  int _compareTime(String time1, String time2) {
    try {
      final time1DateTime = _parseTimeString(time1);
      final time2DateTime = _parseTimeString(time2);
      return time1DateTime.compareTo(time2DateTime);
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadTimeSlots();
    }
  }

  Future<void> _addTimeSlot(String time) async {
    setState(() => _isUpdating = true);
    
    try {
      final dateString = _formatDate(_selectedDate);
      
      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('time_slots')
          .doc(dateString)
          .set({
        'slots.$time': {
          'isAvailable': true,
          'isBooked': false,
          'createdAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
      
      _showSuccess('Time slot added successfully');
      _loadTimeSlots();
    } catch (e) {
      print('❌ Error adding time slot: $e');
      _showError('Failed to add time slot: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateTimeSlot(String time, {bool? isAvailable}) async {
    setState(() => _isUpdating = true);
    
    try {
      final dateString = _formatDate(_selectedDate);
      
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('time_slots')
          .doc(dateString)
          .update({
        'slots.$time.isAvailable': isAvailable,
        'slots.$time.updatedAt': FieldValue.serverTimestamp(),
      });
      
      _showSuccess('Time slot updated successfully');
      _loadTimeSlots();
    } catch (e) {
      print('❌ Error updating time slot: $e');
      _showError('Failed to update time slot: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _deleteTimeSlot(String time) async {
    setState(() => _isUpdating = true);
    
    try {
      final dateString = _formatDate(_selectedDate);
      
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('time_slots')
          .doc(dateString)
          .update({
        'slots.$time': FieldValue.delete(),
      });
      
      _showSuccess('Time slot deleted successfully');
      _loadTimeSlots();
    } catch (e) {
      print('❌ Error deleting time slot: $e');
      _showError('Failed to delete time slot: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showAddSlotsDialog() {
    final selectedTimes = <String>[];
    final existingTimes = _timeSlots.map((slot) => slot['time']).toSet();
    final availableTimes = _availableTimes.where((time) => !existingTimes.contains(time)).toList();
    
    if (availableTimes.isEmpty) {
      _showError('All time slots already exist for this date');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Time Slots for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: availableTimes.length,
              itemBuilder: (context, index) {
                final time = availableTimes[index];
                final isSelected = selectedTimes.contains(time);
                
                return GestureDetector(
                  onTap: () {
                    setDialogState(() {
                      if (isSelected) {
                        selectedTimes.remove(time);
                      } else {
                        selectedTimes.add(time);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.grey,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedTimes.isEmpty ? null : () async {
                Navigator.pop(context);
                for (final time in selectedTimes) {
                  await _addTimeSlot(time);
                }
              },
              child: Text('Add ${selectedTimes.length} Slots'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSlotOptionsDialog(Map<String, dynamic> slot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Slot: ${slot['time']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSlotDetailRow('Status', slot['isBooked'] == true ? 'Booked' : 
                                         slot['isAvailable'] == true ? 'Available' : 'Unavailable'),
            if (slot['isBooked'] == true) ...[
              _buildSlotDetailRow('Patient', slot['bookedBy'] ?? 'Unknown'),
              _buildSlotDetailRow('Type', slot['appointmentType'] ?? 'Not specified'),
            ],
            _buildSlotDetailRow('Date', DateFormat('MMM dd, yyyy').format(_selectedDate)),
          ],
        ),
        actions: [
          if (slot['isBooked'] != true) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateTimeSlot(slot['time'], isAvailable: !(slot['isAvailable'] == true));
              },
              child: Text(slot['isAvailable'] == true ? 'Make Unavailable' : 'Make Available'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteSlot(slot['time']);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
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

  Widget _buildSlotDetailRow(String label, String value) {
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmDeleteSlot(String time) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Time Slot'),
        content: Text('Are you sure you want to delete the $time slot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTimeSlot(time);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
      appBar: AppBar(
        title: Text('Time Slots - Dr. ${widget.doctorName}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadTimeSlots,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).primaryColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Selected Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Total', _timeSlots.length.toString(), Colors.blue),
                _buildStatColumn('Available', 
                    _timeSlots.where((s) => s['isAvailable'] == true && s['isBooked'] != true).length.toString(), 
                    Colors.green),
                _buildStatColumn('Booked', 
                    _timeSlots.where((s) => s['isBooked'] == true).length.toString(), 
                    Colors.orange),
                _buildStatColumn('Unavailable', 
                    _timeSlots.where((s) => s['isAvailable'] == false).length.toString(), 
                    Colors.red),
              ],
            ),
          ),

          // Time Slots List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _timeSlots.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadTimeSlots,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2.5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _timeSlots.length,
                            itemBuilder: (context, index) {
                              final slot = _timeSlots[index];
                              return _buildTimeSlotCard(slot);
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUpdating ? null : _showAddSlotsDialog,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        icon: _isUpdating 
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
            : const Icon(Icons.add),
        label: Text(_isUpdating ? 'Updating...' : 'Add Slots'),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
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

  Widget _buildTimeSlotCard(Map<String, dynamic> slot) {
    final isAvailable = slot['isAvailable'] == true;
    final isBooked = slot['isBooked'] == true;
    
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String status;

    if (isBooked) {
      backgroundColor = Colors.orange.withOpacity(0.1);
      borderColor = Colors.orange;
      textColor = Colors.orange;
      icon = Icons.event_busy;
      status = 'Booked';
    } else if (isAvailable) {
      backgroundColor = Colors.green.withOpacity(0.1);
      borderColor = Colors.green;
      textColor = Colors.green;
      icon = Icons.event_available;
      status = 'Available';
    } else {
      backgroundColor = Colors.red.withOpacity(0.1);
      borderColor = Colors.red;
      textColor = Colors.red;
      icon = Icons.event_busy;
      status = 'Unavailable';
    }

    return GestureDetector(
      onTap: () => _showSlotOptionsDialog(slot),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 16),
            const SizedBox(height: 4),
            Text(
              slot['time'] ?? '',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 9,
                color: textColor,
              ),
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
            Icons.schedule,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No time slots for this date',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some time slots to start accepting appointments',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddSlotsDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Time Slots'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}