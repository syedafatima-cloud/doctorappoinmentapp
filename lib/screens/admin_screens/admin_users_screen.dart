// screens/admin_users_screen.dart
import 'package:flutter/material.dart';
import 'package:doctorappoinmentapp/services/admin_services.dart';

class AdminUsersScreen extends StatefulWidget {
  final String adminId;
  
  const AdminUsersScreen({super.key, required this.adminId});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final users = await _adminService.getAllUsers();
      final doctors = await _adminService.getAllDoctors();
      
      setState(() {
        _patients = users;
        _doctors = doctors;
        _allUsers = [...users, ...doctors];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    if (_searchQuery.isEmpty) return users;
    
    return users.where((user) {
      final name = (user['fullName'] ?? user['name'] ?? '').toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      final phone = (user['phoneNumber'] ?? user['phone'] ?? '').toLowerCase();
      
      return name.contains(_searchQuery.toLowerCase()) ||
             email.contains(_searchQuery.toLowerCase()) ||
             phone.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showUserDetails(Map<String, dynamic> user, bool isDoctor) {
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
                    color: isDoctor ? Colors.blue : Colors.green,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDoctor ? Icons.medical_services : Icons.person,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${isDoctor ? 'Doctor' : 'Patient'} Details',
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
                        if (user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty)
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(user['profileImageUrl']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        
                        _buildDetailRow('Full Name', user['fullName'] ?? user['name'] ?? 'N/A'),
                        _buildDetailRow('Email', user['email'] ?? 'N/A'),
                        _buildDetailRow('Phone', user['phoneNumber'] ?? user['phone'] ?? 'N/A'),
                        
                        if (isDoctor) ...[
                          _buildDetailRow('Specialization', user['specialization'] ?? 'N/A'),
                          _buildDetailRow('License Number', user['licenseNumber'] ?? 'N/A'),
                          _buildDetailRow('Hospital/Clinic', user['hospital'] ?? 'N/A'),
                          _buildDetailRow('Experience', '${user['experienceYears'] ?? 0} years'),
                          _buildDetailRow('Consultation Fee', '\$${user['consultationFee'] ?? 0}'),
                          _buildDetailRow('Available Days', (user['availableDays'] as List?)?.join(', ') ?? 'N/A'),
                          _buildDetailRow('Working Hours', '${user['startTime'] ?? 'N/A'} - ${user['endTime'] ?? 'N/A'}'),
                          _buildDetailRow('Qualifications', user['qualifications'] ?? 'N/A', isMultiLine: true),
                        ] else ...[
                          _buildDetailRow('Date of Birth', user['dateOfBirth'] ?? 'N/A'),
                          _buildDetailRow('Gender', user['gender'] ?? 'N/A'),
                          _buildDetailRow('Address', user['address'] ?? 'N/A', isMultiLine: true),
                        ],
                        
                        _buildDetailRow('Registration Date', _formatDate(user['createdAt'] ?? user['registrationDate'])),
                        _buildDetailRow('Status', user['isActive'] == true ? 'Active' : 'Inactive'),
                      ],
                    ),
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _toggleUserStatus(user['uid'] ?? user['id'], user['isActive'] == true);
                        },
                        icon: Icon(user['isActive'] == true ? Icons.block : Icons.check),
                        label: Text(user['isActive'] == true ? 'Deactivate' : 'Activate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: user['isActive'] == true ? Colors.red : Colors.green,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _sendNotificationToUser(user);
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Send Message'),
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await _adminService.updateUserStatus(userId, !currentStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendNotificationToUser(Map<String, dynamic> user) async {
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.message, color: Colors.blue),
              SizedBox(width: 8),
              Text('Send Message'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send a message to ${user['fullName'] ?? user['name']}:'),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your message...',
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
              onPressed: () async {
                if (messageController.text.trim().isNotEmpty) {
                  try {
                    await _adminService.sendMessageToUser(
                      user['uid'] ?? user['id'],
                      messageController.text.trim(),
                    );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message sent successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error sending message: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people),
                        const SizedBox(width: 4),
                        Text('All (${_allUsers.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 4),
                        Text('Patients (${_patients.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.medical_services),
                        const SizedBox(width: 4),
                        Text('Doctors (${_doctors.length})'),
                      ],
                    ),
                  ),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
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
                _buildUsersList(_filterUsers(_allUsers), true),
                _buildUsersList(_filterUsers(_patients), false),
                _buildUsersList(_filterUsers(_doctors), true),
              ],
            ),
    );
  }

  Widget _buildUsersList(List<Map<String, dynamic>> users, bool mixed) {
    if (users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final isDoctor = user['specialization'] != null || user['licenseNumber'] != null;
          return _buildUserCard(user, isDoctor);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isDoctor) {
    final isActive = user['isActive'] == true;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDoctor ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                image: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(user['profileImageUrl']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty
                  ? Icon(
                      isDoctor ? Icons.medical_services : Icons.person,
                      color: isDoctor ? Colors.blue : Colors.green,
                    )
                  : null,
            ),
            if (!isActive)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
        title: Text(
          user['fullName'] ?? user['name'] ?? 'Unknown User',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? 'No email'),
            if (isDoctor && user['specialization'] != null)
              Text('Specialization: ${user['specialization']}'),
            Text('Phone: ${user['phoneNumber'] ?? user['phone'] ?? 'N/A'}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDoctor ? Colors.blue : Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isDoctor ? 'DOCTOR' : 'PATIENT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'ACTIVE' : 'INACTIVE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showUserDetails(user, isDoctor),
      ),
    );
  }
}