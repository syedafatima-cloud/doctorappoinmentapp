// screens/admin_doctor_requests_screen.dart
import 'package:doctorappoinmentapp/services/doctor_register_service.dart';
import 'package:flutter/material.dart';

class AdminDoctorRequestsScreen extends StatefulWidget {
  final String adminId; // Pass admin ID when navigating to this screen
  
  const AdminDoctorRequestsScreen({super.key, required this.adminId});

  @override
  State<AdminDoctorRequestsScreen> createState() => _AdminDoctorRequestsScreenState();
}

class _AdminDoctorRequestsScreenState extends State<AdminDoctorRequestsScreen> with SingleTickerProviderStateMixin {
  final DoctorRegistrationService _doctorService = DoctorRegistrationService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _approvedRequests = [];
  List<Map<String, dynamic>> _rejectedRequests = [];
  Map<String, int> _statistics = {};
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final futures = await Future.wait([
        _doctorService.getRegistrationRequestsByStatus('pending'),
        _doctorService.getRegistrationRequestsByStatus('approved'),
        _doctorService.getRegistrationRequestsByStatus('rejected'),
        _doctorService.getRegistrationStatistics(),
      ]);
      
      setState(() {
        _pendingRequests = futures[0] as List<Map<String, dynamic>>;
        _approvedRequests = futures[1] as List<Map<String, dynamic>>;
        _rejectedRequests = futures[2] as List<Map<String, dynamic>>;
        _statistics = futures[3] as Map<String, int>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveRequest(String requestId, Map<String, dynamic> requestData) async {
    try {
      final success = await _doctorService.approveDoctorRegistration(requestId, widget.adminId);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Doctor ${requestData['fullName']} approved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData(); // Refresh data
        }
      } else {
        throw Exception('Failed to approve doctor registration');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving doctor: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId, Map<String, dynamic> requestData) async {
    final rejectionReason = await _showRejectionDialog();
    
    if (rejectionReason != null && rejectionReason.isNotEmpty) {
      try {
        final success = await _doctorService.rejectDoctorRegistration(requestId, widget.adminId, rejectionReason);
        
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Doctor ${requestData['fullName']} registration rejected'),
                backgroundColor: Colors.orange,
              ),
            );
            _loadData(); // Refresh data
          }
        } else {
          throw Exception('Failed to reject doctor registration');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting doctor: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<String?> _showRejectionDialog() async {
    final TextEditingController reasonController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: 8),
              Text('Reject Registration'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for rejecting this doctor registration:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(reasonController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDoctorDetails(Map<String, dynamic> requestData) {
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
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          requestData['fullName'] ?? 'Doctor Details',
                          style: const TextStyle(
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
                        // Profile Image
                        if (requestData['profileImageUrl'] != null && requestData['profileImageUrl'].isNotEmpty)
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(requestData['profileImageUrl']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        
                        _buildDetailRow('Full Name', requestData['fullName'] ?? 'N/A'),
                        _buildDetailRow('Email', requestData['email'] ?? 'N/A'),
                        _buildDetailRow('Phone', requestData['phoneNumber'] ?? 'N/A'),
                        _buildDetailRow('Specialization', requestData['specialization'] ?? 'N/A'),
                        _buildDetailRow('License Number', requestData['licenseNumber'] ?? 'N/A'),
                        _buildDetailRow('Hospital/Clinic', requestData['hospital'] ?? 'N/A'),
                        _buildDetailRow('Experience', '${requestData['experienceYears'] ?? 0} years'),
                        _buildDetailRow('Consultation Fee', '\$${requestData['consultationFee'] ?? 0}'),
                        _buildDetailRow('Available Days', (requestData['availableDays'] as List?)?.join(', ') ?? 'N/A'),
                        _buildDetailRow('Working Hours', '${requestData['startTime'] ?? 'N/A'} - ${requestData['endTime'] ?? 'N/A'}'),
                        _buildDetailRow('Address', requestData['address'] ?? 'N/A'),
                        _buildDetailRow('Qualifications', requestData['qualifications'] ?? 'N/A', isMultiLine: true),
                        _buildDetailRow('Submission Date', _formatDate(requestData['submissionDate'])),
                        
                        // Status-specific information
                        if (requestData['status'] == 'approved') ...[
                          const Divider(),
                          _buildDetailRow('Approved Date', _formatDate(requestData['reviewDate'])),
                          _buildDetailRow('Approved By', requestData['reviewedBy'] ?? 'N/A'),
                        ],
                        if (requestData['status'] == 'rejected') ...[
                          const Divider(),
                          _buildDetailRow('Rejected Date', _formatDate(requestData['reviewDate'])),
                          _buildDetailRow('Rejected By', requestData['reviewedBy'] ?? 'N/A'),
                          _buildDetailRow('Rejection Reason', requestData['rejectionReason'] ?? 'N/A', isMultiLine: true),
                        ],
                      ],
                    ),
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildStatisticsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registration Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Pending', _statistics['pending'] ?? 0, Colors.orange),
                _buildStatItem('Approved', _statistics['approved'] ?? 0, Colors.green),
                _buildStatItem('Rejected', _statistics['rejected'] ?? 0, Colors.red),
                _buildStatItem('Active Doctors', _statistics['totalActiveDoctors'] ?? 0, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRequestsList(List<Map<String, dynamic>> requests, String status) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'pending' ? Icons.hourglass_empty :
              status == 'approved' ? Icons.check_circle :
              Icons.cancel,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No $status requests found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildRequestCard(request, status);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Profile Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    image: request['profileImageUrl'] != null && request['profileImageUrl'].isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(request['profileImageUrl']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: request['profileImageUrl'] == null || request['profileImageUrl'].isEmpty
                      ? const Icon(Icons.person, size: 30, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['fullName'] ?? 'Unknown Doctor',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request['specialization'] ?? 'Unknown Specialization',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request['hospital'] ?? 'Unknown Hospital',
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
                    color: status == 'pending' ? Colors.orange :
                           status == 'approved' ? Colors.green :
                           Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(request['email'] ?? 'N/A'),
                const Spacer(),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(_formatDate(request['submissionDate'])),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDoctorDetails(request),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                  ),
                ),
                if (status == 'pending') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveRequest(request['requestId'], request),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectRequest(request['requestId'], request),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Registration Requests'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
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
                  const Icon(Icons.hourglass_empty),
                  const SizedBox(width: 4),
                  Text('Pending (${_statistics['pending'] ?? 0})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle),
                  const SizedBox(width: 4),
                  Text('Approved (${_statistics['approved'] ?? 0})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel),
                  const SizedBox(width: 4),
                  Text('Rejected (${_statistics['rejected'] ?? 0})'),
                ],
              ),
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatisticsCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequestsList(_pendingRequests, 'pending'),
                      _buildRequestsList(_approvedRequests, 'approved'),
                      _buildRequestsList(_rejectedRequests, 'rejected'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}