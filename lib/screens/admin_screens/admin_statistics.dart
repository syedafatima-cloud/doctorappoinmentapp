// screens/admin_statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:doctorappoinmentapp/services/admin_services.dart';

class AdminStatisticsScreen extends StatefulWidget {
  final String adminId;
  
  const AdminStatisticsScreen({super.key, required this.adminId});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  final AdminService _adminService = AdminService();
  
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  String _selectedPeriod = 'thisMonth';

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    try {
      final stats = await _adminService.getDetailedStatistics(_selectedPeriod);
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics & Analytics'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadStatistics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'today',
                child: Text('Today'),
              ),
              const PopupMenuItem(
                value: 'thisWeek',
                child: Text('This Week'),
              ),
              const PopupMenuItem(
                value: 'thisMonth',
                child: Text('This Month'),
              ),
              const PopupMenuItem(
                value: 'thisYear',
                child: Text('This Year'),
              ),
              const PopupMenuItem(
                value: 'allTime',
                child: Text('All Time'),
              ),
            ],
            child: const Icon(Icons.date_range),
          ),
          IconButton(
            onPressed: _loadStatistics,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Selection Card
                    _buildPeriodCard(),
                    const SizedBox(height: 16),
                    
                    // Overview Statistics
                    _buildOverviewSection(),
                    const SizedBox(height: 24),
                    
                    // Appointments Statistics
                    _buildAppointmentsSection(),
                    const SizedBox(height: 24),
                    
                    // Doctors Statistics
                    _buildDoctorsSection(),
                    const SizedBox(height: 24),
                    
                    // Users Statistics
                    _buildUsersSection(),
                    const SizedBox(height: 24),
                    
                    // Performance Metrics
                    _buildPerformanceSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodCard() {
    String periodText = '';
    switch (_selectedPeriod) {
      case 'today':
        periodText = 'Today\'s Statistics';
        break;
      case 'thisWeek':
        periodText = 'This Week\'s Statistics';
        break;
      case 'thisMonth':
        periodText = 'This Month\'s Statistics';
        break;
      case 'thisYear':
        periodText = 'This Year\'s Statistics';
        break;
      case 'allTime':
        periodText = 'All Time Statistics';
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.analytics, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    periodText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Last updated: ${DateTime.now().toString().substring(0, 16)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Revenue',
              '\$${_statistics['totalRevenue'] ?? 0}',
              Icons.attach_money,
              Colors.green,
            ),
            _buildStatCard(
              'Active Users',
              '${_statistics['activeUsers'] ?? 0}',
              Icons.people,
              Colors.blue,
            ),
            _buildStatCard(
              'Completed Appointments',
              '${_statistics['completedAppointments'] ?? 0}',
              Icons.check_circle,
              Colors.purple,
            ),
            _buildStatCard(
              'System Uptime',
              '${_statistics['systemUptime'] ?? '99.9'}%',
              Icons.trending_up,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppointmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Appointments',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricItem(
                      'Total',
                      '${_statistics['totalAppointments'] ?? 0}',
                      Colors.blue,
                    ),
                    _buildMetricItem(
                      'Pending',
                      '${_statistics['pendingAppointments'] ?? 0}',
                      Colors.orange,
                    ),
                    _buildMetricItem(
                      'Confirmed',
                      '${_statistics['confirmedAppointments'] ?? 0}',
                      Colors.green,
                    ),
                    _buildMetricItem(
                      'Cancelled',
                      '${_statistics['cancelledAppointments'] ?? 0}',
                      Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProgressBar(
                  'Completion Rate',
                  (_statistics['appointmentCompletionRate'] ?? 0.0) / 100,
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _buildProgressBar(
                  'Cancellation Rate',
                  (_statistics['appointmentCancellationRate'] ?? 0.0) / 100,
                  Colors.red,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Doctors',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricItem(
                      'Active',
                      '${_statistics['activeDoctors'] ?? 0}',
                      Colors.green,
                    ),
                    _buildMetricItem(
                      'Pending',
                      '${_statistics['pendingDoctors'] ?? 0}',
                      Colors.orange,
                    ),
                    _buildMetricItem(
                      'Rejected',
                      '${_statistics['rejectedDoctors'] ?? 0}',
                      Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Top Specializations',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._buildTopSpecializations(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Users',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricItem(
                      'Total Users',
                      '${_statistics['totalUsers'] ?? 0}',
                      Colors.blue,
                    ),
                    _buildMetricItem(
                      'New Users',
                      '${_statistics['newUsers'] ?? 0}',
                      Colors.green,
                    ),
                    _buildMetricItem(
                      'Active Today',
                      '${_statistics['activeToday'] ?? 0}',
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProgressBar(
                  'User Retention Rate',
                  (_statistics['userRetentionRate'] ?? 0.0) / 100,
                  Colors.blue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPerformanceItem(
                  'Average Response Time',
                  '${_statistics['avgResponseTime'] ?? 0}ms',
                  Icons.speed,
                ),
                const Divider(),
                _buildPerformanceItem(
                  'System Errors',
                  '${_statistics['systemErrors'] ?? 0}',
                  Icons.error_outline,
                ),
                const Divider(),
                _buildPerformanceItem(
                  'Database Queries/sec',
                  '${_statistics['dbQueriesPerSec'] ?? 0}',
                  Icons.storage,
                ),
                const Divider(),
                _buildPerformanceItem(
                  'Active Sessions',
                  '${_statistics['activeSessions'] ?? 0}',
                  Icons.group,
                ),
              ],
            ),
          ),
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
                  fontSize: 20,
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

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
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

  Widget _buildProgressBar(String label, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${(progress * 100).toInt()}%'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  List<Widget> _buildTopSpecializations() {
    final specializations = _statistics['topSpecializations'] as List<dynamic>? ?? [];
    
    return specializations.take(3).map<Widget>((spec) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(spec['name'] ?? 'Unknown'),
            Text('${spec['count'] ?? 0} doctors'),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPerformanceItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

  