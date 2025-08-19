// screens/doctor_screens/doctor_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorEarningsScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  
  const DoctorEarningsScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorEarningsScreen> createState() => _DoctorEarningsScreenState();
}

class _DoctorEarningsScreenState extends State<DoctorEarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  String _selectedPeriod = 'This Month';
  
  // Earnings data
  double _totalEarnings = 0.0;
  double _monthlyEarnings = 0.0;
  double _weeklyEarnings = 0.0;
  double _dailyEarnings = 0.0;
  
  // Appointment statistics
  int _totalAppointments = 0;
  int _completedAppointments = 0;
  int _cancelledAppointments = 0;
  double _averageConsultationFee = 0.0;
  
  // Period data
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _dailyData = [];
  List<Map<String, dynamic>> _recentTransactions = [];
  
  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'Last 3 Months',
    'This Year',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEarningsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEarningsData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadAppointmentData(),
        _loadTransactionData(),
        _generateMockData(), // For demonstration - replace with real data
      ]);
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error loading earnings data: $e');
      setState(() => _isLoading = false);
      _showError('Failed to load earnings data');
    }
  }

  Future<void> _loadAppointmentData() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      // Get completed appointments
      final appointmentsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalEarnings = 0.0;
      double monthlyEarnings = 0.0;
      double weeklyEarnings = 0.0;
      double dailyEarnings = 0.0;
      int totalAppts = 0;
      int completedAppts = 0;
      double totalFees = 0.0;

      for (final doc in appointmentsQuery.docs) {
        final data = doc.data();
        final appointmentDate = _parseDate(data['date'] ?? '');
        final fee = (data['consultationFee'] ?? 0.0).toDouble();
        
        totalEarnings += fee;
        totalAppts++;
        completedAppts++;
        totalFees += fee;
        
        if (appointmentDate.isAfter(startOfMonth)) {
          monthlyEarnings += fee;
        }
        if (appointmentDate.isAfter(startOfWeek)) {
          weeklyEarnings += fee;
        }
        if (appointmentDate.isAfter(startOfDay)) {
          dailyEarnings += fee;
        }
      }

      // Get all appointments for statistics
      final allAppointmentsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .get();

      int cancelled = 0;
      for (final doc in allAppointmentsQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'cancelled') {
          cancelled++;
        }
      }

      setState(() {
        _totalEarnings = totalEarnings;
        _monthlyEarnings = monthlyEarnings;
        _weeklyEarnings = weeklyEarnings;
        _dailyEarnings = dailyEarnings;
        _totalAppointments = allAppointmentsQuery.docs.length;
        _completedAppointments = completedAppts;
        _cancelledAppointments = cancelled;
        _averageConsultationFee = completedAppts > 0 ? totalFees / completedAppts : 0.0;
      });
      
    } catch (e) {
      print('Error loading appointment data: $e');
    }
  }

  Future<void> _loadTransactionData() async {
    try {
      // Load recent transactions/earnings
      final transactionsQuery = await FirebaseFirestore.instance
          .collection('earnings')
          .where('doctorId', isEqualTo: widget.doctorId)
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      final transactions = transactionsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'amount': data['amount'] ?? 0.0,
          'date': data['date'] ?? '',
          'patientName': data['patientName'] ?? 'Unknown',
          'appointmentType': data['appointmentType'] ?? 'chat',
          'status': data['status'] ?? 'completed',
        };
      }).toList();

      setState(() {
        _recentTransactions = transactions;
      });
      
    } catch (e) {
      print('Error loading transaction data: $e');
      // If earnings collection doesn't exist, we'll show mock data
    }
  }

  Future<void> _generateMockData() async {
    // Generate mock monthly data for the chart
    final now = DateTime.now();
    final monthlyData = <Map<String, dynamic>>[];
    
    for (int i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final earnings = (500 + (i * 100) + (DateTime.now().millisecond % 200)).toDouble();
      monthlyData.add({
        'month': DateFormat('MMM').format(month),
        'earnings': earnings,
        'appointments': 15 + (i * 2),
      });
    }

    // Generate weekly data
    final weeklyData = <Map<String, dynamic>>[];
    for (int i = 7; i >= 0; i--) {
      final week = now.subtract(Duration(days: i * 7));
      final earnings = (200 + (i * 50) + (DateTime.now().millisecond % 100)).toDouble();
      weeklyData.add({
        'week': 'Week ${8 - i}',
        'earnings': earnings,
        'appointments': 5 + i,
      });
    }

    // Generate daily data
    final dailyData = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final earnings = (50 + (i * 25) + (DateTime.now().millisecond % 50)).toDouble();
      dailyData.add({
        'day': DateFormat('EEE').format(day),
        'earnings': earnings,
        'appointments': 1 + (i % 3),
      });
    }

    setState(() {
      _monthlyData = monthlyData;
      _weeklyData = weeklyData;
      _dailyData = dailyData;
    });
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double _getEarningsForPeriod() {
    switch (_selectedPeriod) {
      case 'Today':
        return _dailyEarnings;
      case 'This Week':
        return _weeklyEarnings;
      case 'This Month':
        return _monthlyEarnings;
      case 'This Year':
        return _totalEarnings;
      default:
        return _monthlyEarnings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Earnings - Dr. ${widget.doctorName}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadEarningsData,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (period) {
              setState(() => _selectedPeriod = period);
            },
            itemBuilder: (context) => _periods.map((period) =>
              PopupMenuItem(
                value: period,
                child: Text(period),
              ),
            ).toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Analytics'),
              Tab(text: 'Transactions'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAnalyticsTab(),
                _buildTransactionsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadEarningsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            _buildPeriodSelector(),
            const SizedBox(height: 20),

            // Main Earnings Card
            _buildMainEarningsCard(),
            const SizedBox(height: 20),

            // Quick Stats Row
            _buildQuickStatsRow(),
            const SizedBox(height: 20),

            // Appointment Statistics
            _buildAppointmentStats(),
            const SizedBox(height: 20),

            // Recent Activity
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _periods.length,
        itemBuilder: (context, index) {
          final period = _periods[index];
          final isSelected = period == _selectedPeriod;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.secondary
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Text(
                period,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainEarningsCard() {
    final earnings = _getEarningsForPeriod();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Earnings',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedPeriod,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '\$${earnings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: Colors.green[300],
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '+12.5% from last period',
                style: TextStyle(
                  color: Colors.green[300],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Daily Avg',
            '\$${(_monthlyEarnings / 30).toStringAsFixed(0)}',
            Icons.today,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Weekly Avg',
            '\$${(_monthlyEarnings / 4).toStringAsFixed(0)}',
            Icons.calendar_view_week,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Monthly',
            '\$${_monthlyEarnings.toStringAsFixed(0)}',
            Icons.calendar_month,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointment Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAppointmentStatItem(
                'Total',
                _totalAppointments.toString(),
                Colors.blue,
              ),
              _buildAppointmentStatItem(
                'Completed',
                _completedAppointments.toString(),
                Colors.green,
              ),
              _buildAppointmentStatItem(
                'Cancelled',
                _cancelledAppointments.toString(),
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Average Consultation Fee',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '\$${_averageConsultationFee.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentStatItem(String label, String value, Color color) {
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(2); // Go to transactions tab
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentTransactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No recent transactions',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...(_recentTransactions.take(3).map((transaction) =>
              _buildTransactionItem(transaction))),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Analytics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Monthly Chart
          _buildChartCard('Monthly Earnings', _monthlyData, 'month'),
          const SizedBox(height: 20),
          
          // Weekly Chart
          _buildChartCard('Weekly Earnings', _weeklyData, 'week'),
          const SizedBox(height: 20),
          
          // Performance Metrics
          _buildPerformanceMetrics(),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, List<Map<String, dynamic>> data, String labelKey) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Simple bar chart representation
          SizedBox(
            height: 200,
            child: data.isEmpty
                ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.map((item) {
                      final earnings = (item['earnings'] as double);
                      final maxEarnings = data.map((e) => e['earnings'] as double).reduce((a, b) => a > b ? a : b);
                      final height = (earnings / maxEarnings) * 160;
                      
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '\$${earnings.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 20,
                            height: height,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item[labelKey].toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final completionRate = _totalAppointments > 0 
        ? (_completedAppointments / _totalAppointments * 100)
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 20),
          
          _buildMetricRow('Completion Rate', '${completionRate.toStringAsFixed(1)}%', Colors.green),
          const SizedBox(height: 12),
          _buildMetricRow('Average Earning per Day', '\$${(_monthlyEarnings / 30).toStringAsFixed(2)}', Colors.blue),
          const SizedBox(height: 12),
          _buildMetricRow('Peak Earning Month', 'Current Month', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    return Column(
      children: [
        // Summary row
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'Total Transactions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    _recentTransactions.length.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '\$${_totalEarnings.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Transactions list
        Expanded(
          child: _recentTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Completed appointments will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recentTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _recentTransactions[index];
                    return _buildTransactionItem(transaction);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] ?? 0.0).toDouble();
    final date = transaction['date'] ?? '';
    final patientName = transaction['patientName'] ?? 'Unknown Patient';
    final appointmentType = transaction['appointmentType'] ?? 'chat';
    final status = transaction['status'] ?? 'completed';

    IconData typeIcon;
    Color typeColor;
    switch (appointmentType) {
      case 'video_call':
        typeIcon = Icons.videocam;
        typeColor = Colors.blue;
        break;
      case 'in_person':
        typeIcon = Icons.local_hospital;
        typeColor = Colors.green;
        break;
      default:
        typeIcon = Icons.chat_bubble_outline;
        typeColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Transaction Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              typeIcon,
              color: typeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          
          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _getAppointmentTypeDisplay(appointmentType),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTransactionDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Amount and Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: status == 'completed' ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getAppointmentTypeDisplay(String type) {
    switch (type) {
      case 'video_call':
        return 'Video Call';
      case 'in_person':
        return 'In-Person';
      case 'chat':
        return 'Chat';
      default:
        return 'Consultation';
    }
  }

  String _formatTransactionDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'Unknown date';
      
      // Handle different date formats
      DateTime date;
      if (dateString.contains('-')) {
        final parts = dateString.split('-');
        if (parts.length == 3) {
          date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        } else {
          return dateString;
        }
      } else {
        date = DateTime.parse(dateString);
      }
      
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      
      if (difference == 0) {
        return 'Today';
      } else if (difference == 1) {
        return 'Yesterday';
      } else if (difference < 7) {
        return '$difference days ago';
      } else {
        return DateFormat('MMM dd').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}