import 'package:doctorappoinmentapp/screens/appointment_booking_screen.dart';
import 'package:doctorappoinmentapp/screens/disease_selection_screen.dart';
import 'package:doctorappoinmentapp/screens/doctor_profile_screen.dart';
import 'package:doctorappoinmentapp/screens/registeration_screens/login_screen.dart';
import 'package:doctorappoinmentapp/screens/splash_screen.dart';
import 'package:doctorappoinmentapp/screens/talk_to_doc_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:doctorappoinmentapp/screens/groq_medicalbot.dart';
import 'package:doctorappoinmentapp/screens/registeration_screens/doctor_register_screen.dart';
import 'package:doctorappoinmentapp/models/doctor_model.dart';
import 'package:doctorappoinmentapp/services/appointment_service.dart';
import 'package:doctorappoinmentapp/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeInController;
  late final AnimationController _slideController;
  late final AnimationController _fabController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fabScaleAnimation;
  
  // Doctor cards controller
  late final PageController _doctorPageController;
  int _currentDoctorIndex = 0;
  
  List<Doctor> doctors = [];
  bool isLoadingDoctors = true;
  final AppointmentService _appointmentService = AppointmentService();

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Initialize animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

    // Initialize doctor page controller - Changed to full width
    _doctorPageController = PageController(
      viewportFraction: 1.0, // Changed from 0.8 to 1.0 for full width
      initialPage: 0,
    );
    
    // Start animations
    _startAnimations();
    _loadDoctors();
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeInController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _fabController.forward();
    });
  }

  Future<void> _loadDoctors() async {
    setState(() {
      isLoadingDoctors = true;
    });
    try {
      final doctorsList = await _appointmentService.getAllDoctors();
      setState(() {
        if (doctorsList is List<Doctor>) {
          doctors = doctorsList.cast<Doctor>();
        } else {
          doctors = (doctorsList as List)
              .map((doc) => Doctor.fromMap(doc as Map<String, dynamic>))
              .toList();
        }
        isLoadingDoctors = false;
      });
      if (doctors.isNotEmpty) {
        _startAutoSwipe();
      }
    } catch (e) {
      setState(() {
        isLoadingDoctors = false;
      });
      debugPrint('Error loading doctors: $e');
    }
  }

  void _startAutoSwipe() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && doctors.isNotEmpty) {
        _currentDoctorIndex = (_currentDoctorIndex + 1) % doctors.length;
        _doctorPageController.animateToPage(
          _currentDoctorIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
        _startAutoSwipe();
      }
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _slideController.dispose();
    _fabController.dispose();
    _doctorPageController.dispose();
    super.dispose();
  }

  void _navigateToMedicalBot() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const GroqMedicalBot(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: child,
          );
        },
      ),
    );
  }
  void _navigateToTalkToDoctor() {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const TalkToDoctorScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    ),
  );
}
  void _navigateToDoctorRegister() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DoctorRegistrationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: child,
          );
        },
      ),
    );
  }
  void _navigateToAppointments() {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const DiseaseSelectionScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    ),
  );
}
 

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF7E57C2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Smaller App Bar
          SliverAppBar(
            expandedHeight: 60, // Reduced from 120
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).primaryColor,
            leading: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                onPressed: () async {
                  // Clear user sessison
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', false);
                  await prefs.setBool('isAdmin', false);
                  
                  // Sign out from Firebase
                  await FirebaseAuth.instance.signOut();
                  
                  // Navigate to login screen (using the SplashScreen -> LoginPage flow)
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SplashScreen(
                        nextScreen: LoginPage(),
                      ),
                    ),
                    (route) => false, // Remove all previous routes
                  );
                },
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'MediCare+',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18, // Reduced from 22
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                  onPressed: () => _showSnackBar('No new notifications'),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                  onPressed: () => _navigateToSettings(),
                ),
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      
                      // Featured Doctors Section (Moved to Top) - Now full width
                      _buildSectionHeader(
                        'Featured Doctors',
                        'Find the best healthcare professionals',
                        Icons.local_hospital,
                        const Color(0xFF7E57C2),
                      ),
                      const SizedBox(height: 16), // Reduced from 20
                      _buildDoctorCardsSection(),
                      
                      const SizedBox(height: 24), // Reduced from 40
                      
                      
                      
                      // AI Assistant and Doctor Registration Cards - Side by Side
                      _buildSideBySideCards(),
                      
                      const SizedBox(height: 24), // Reduced from 30
                      
                      // Quick Actions
                      _buildSectionHeader(
                        'Quick Actions',
                        'Access healthcare services instantly',
                        Icons.flash_on,
                        const Color(0xFFC5CAE9),
                      ),
                      const SizedBox(height: 16), // Reduced from 20
                      _buildQuickActionsGrid(),
                      
                      const SizedBox(height: 24), // Reduced from 30
                      
                      // Features Section
                      _buildSectionHeader(
                        'AI Features',
                        'Powered by advanced medical intelligence',
                        Icons.psychology,
                        const Color(0xFF7E57C2),
                      ),
                      const SizedBox(height: 16), // Reduced from 20
                      _buildFeaturesList(),
                      
                      const SizedBox(height: 80), // Reduced from 100
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: Container(
              width: 60, // Reduced from 68
              height: 60, // Reduced from 68
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC5CAE9), Color(0xFF7E57C2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30), // Adjusted
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7E57C2).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _navigateToMedicalBot,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 24, // Reduced from 28
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10), // Reduced from 12
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14), // Reduced from 16
          ),
          child: Icon(icon, color: color, size: 20), // Reduced from 24
        ),
        const SizedBox(width: 12), // Reduced from 16
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18, // Reduced from 22
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12, // Reduced from 14
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCardsSection() {
    if (isLoadingDoctors) {
      return Container(
        height: 260, // Reduced from 240
        decoration: BoxDecoration(
          color: const Color(0xFFEDE7F6),
          borderRadius: BorderRadius.circular(20), // Reduced from 24
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF7E57C2),
          ),
        ),
      );
    }

    if (doctors.isEmpty) {
      return Container(
        height: 260, // Reduced from 240
        decoration: BoxDecoration(
          color: const Color(0xFFEDE7F6),
          borderRadius: BorderRadius.circular(20), // Reduced from 24
          border: Border.all(color: const Color(0xFFC5CAE9).withOpacity(0.3)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 40, // Reduced from 48
                color: Color(0xFF7E57C2),
              ),
              SizedBox(height: 12), // Reduced from 16
              Text(
                'No doctors available at the moment',
                style: TextStyle(
                  fontSize: 14, // Reduced from 16
                  color: Color(0xFF424242),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6), // Reduced from 8
              Text(
                'Please check back later',
                style: TextStyle(
                  fontSize: 12, // Reduced from 14
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 300, // Decreased height for compact card
      child: PageView.builder(
        controller: _doctorPageController,
        onPageChanged: (index) {
          setState(() {
            _currentDoctorIndex = index;
          });
        },
        itemCount: doctors.length,
        itemBuilder: (context, index) {
          final doctor = doctors[index];
          return _buildDoctorCard(doctor);
        },
      ),
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
  final name = doctor.name;
  final specialty = doctor.specialization;
  final rating = doctor.rating;
  final experience = doctor.experienceYears ?? doctor.experience ?? 0;
  final image = doctor.profileImageUrl ?? doctor.profileImage ?? '';
  final fee = doctor.consultationFee != null ? doctor.consultationFee.toString() : '';

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorProfileScreen(doctorId: doctor.id),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E57C2).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Doctor Header
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFC5CAE9).withOpacity(0.2),
                  const Color(0xFFEDE7F6).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7E57C2).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: image.isNotEmpty
                          ? Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                            )
                          : _buildDefaultAvatar(),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Doctor Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    specialty,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7E57C2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  // Experience and Fee Row
                  if (experience != 0 || fee.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (experience != 0) ...[
                          const Icon(Icons.work, size: 13, color: Color(0xFF7E57C2)),
                          const SizedBox(width: 4),
                          Text('$experience yrs', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface)),
                        ],
                        if (fee.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Text(
                            'PKR',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7E57C2),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(fee, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      ],
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AppointmentBookingScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD1C4E9),
                        foregroundColor: const Color(0xFF424242),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Book Appointment',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        size: 28, // Reduced from 32
        color: Color(0xFF7E57C2),
      ),
    );
  }

  // New method for side-by-side cards
  Widget _buildSideBySideCards() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildAIWelcomeCard(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDoctorRegistrationCard(),
        ),
      ],
    );
  }

  Widget _buildAIWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20), // Reduced from 28
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC5CAE9), Color(0xFF7E57C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20), // Reduced from 28
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E57C2).withOpacity(0.3),
            blurRadius: 16, // Reduced from 24
            offset: const Offset(0, 8), // Reduced from 12
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12), // Reduced from 16
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16), // Reduced from 20
            ),
            child: const Icon(
              Icons.psychology,
              color: Colors.white,
              size: 24, // Reduced from 32
            ),
          ),
          const SizedBox(height: 10), // Reduced from 20
          const Text(
            'AI Medical Assistant',
            style: TextStyle(
              fontSize: 15, // Reduced from 24
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Available 24/7',
            style: TextStyle(
              fontSize: 12, // Reduced from 16
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10), // Reduced from 20
          const Text(
            'Get instant medical guidance and appointment scheduling.',
            style: TextStyle(
              fontSize: 13, // Reduced from 16
              color: Colors.white,
              height: 1.4, // Reduced from 1.5
            ),
          ),
          const SizedBox(height: 12), // Reduced from 24
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToMedicalBot,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF7E57C2),
                padding: const EdgeInsets.symmetric(vertical: 10), // Reduced from 16
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100), // Reduced from 16
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 16), // Reduced from 20
                  SizedBox(width: 6), // Reduced from 8
                  Text(
                    'Start Chat',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12, // Reduced from 16
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
  final actions = [
    {
      'icon': Icons.chat_outlined,
      'title': 'Talk to Doctor',
      'subtitle': 'Free consultation',
      'color': const Color(0xFF4CAF50), // Green color for free feature
      'onTap': _navigateToTalkToDoctor,
    },
    {
      'icon': Icons.calendar_today_outlined,
      'title': 'Appointments',
      'subtitle': 'Book & manage',
      'color': const Color(0xFF7E57C2),
      'onTap': _navigateToAppointments, // Changed this line
    },
    {
      'icon': Icons.medical_information_outlined,
      'title': 'Health Records',
      'subtitle': 'View history',
      'color': const Color(0xFFC5CAE9),
      'onTap': () => _showSnackBar('Health Records coming soon'),
    },
    {
      'icon': Icons.emergency_outlined,
      'title': 'Emergency',
      'subtitle': 'Urgent care',
      'color': Colors.red.shade400,
      'onTap': () => _showSnackBar('Emergency services'),
    },
  ];

  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12, // Reduced from 16
      mainAxisSpacing: 12, // Reduced from 16
      childAspectRatio: 1.4, // Increased from 1.2 to make cards wider
    ),
    itemCount: actions.length,
    itemBuilder: (context, index) {
      final action = actions[index];
      return _buildQuickActionCard(
        icon: action['icon'] as IconData,
        title: action['title'] as String,
        subtitle: action['subtitle'] as String,
        color: action['color'] as Color,
        onTap: action['onTap'] as VoidCallback,
      );
    },
  );
}

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16), // Reduced from 20
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12, // Reduced from 16
              offset: const Offset(0, 3), // Reduced from 4
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16), // Reduced from 20
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, // Reduced from 48
                height: 40, // Reduced from 48
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12), // Reduced from 16
                ),
                child: Icon(icon, color: color, size: 20), // Reduced from 24
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13, // Reduced from 16
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2), // Reduced from 4
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11, // Reduced from 12
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorRegistrationCard() {
    return Container(
      padding: const EdgeInsets.all(20), // Reduced from 24
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEDE7F6),
            const Color(0xFFC5CAE9).withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20), // Reduced from 24
        border: Border.all(
          color: const Color(0xFFC5CAE9).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10), // Reduced from 12
            decoration: BoxDecoration(
              color: const Color(0xFF7E57C2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12), // Reduced from 16
            ),
            child: const Icon(
              Icons.medical_services,
              color: Color(0xFF7E57C2),
              size: 20, // Reduced from 24
            ),
          ),
          const SizedBox(height: 12), // Reduced from 16
          Text(
            'Join as Healthcare Provider',
            style: TextStyle(
              fontSize: 14, // Reduced from 20
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8), // Reduced from 16
          Text(
            'Expand your practice and reach more patients through our platform.',
            style: TextStyle(
              fontSize: 12, // Reduced from 15
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              height: 1.3, // Reduced from 1.4
            ),
          ),
          const SizedBox(height: 14), // Reduced from 20
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToDoctorRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E57C2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 1), // Reduced from 16
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100), // Reduced from 16
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_outlined, size: 16), // Reduced from 20
                  SizedBox(width: 6), // Reduced from 8
                  Text(
                    'Register Now',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12, // Reduced from 16
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {
        'icon': Icons.psychology_outlined,
        'title': 'AI-Powered Consultations',
        'description': 'Advanced medical AI for instant health guidance and symptom analysis',
        'color': const Color(0xFF7E57C2),
      },
      {
        'icon': Icons.schedule_outlined,
        'title': 'Smart Scheduling',
        'description': 'Intelligent appointment booking with real-time availability',
        'color': const Color(0xFFC5CAE9),
      },
      {
        'icon': Icons.video_call_outlined,
        'title': 'Telemedicine',
        'description': 'High-quality video consultations with certified doctors',
        'color': const Color(0xFFD1C4E9),
      },
      {
        'icon': Icons.security_outlined,
        'title': 'Secure & Private',
        'description': 'Enterprise-grade security with complete data privacy protection',
        'color': const Color(0xFF7E57C2),
      },
    ];

    return Column(
      children: features.map((feature) => _buildFeatureItem(
        icon: feature['icon'] as IconData,
        title: feature['title'] as String,
        description: feature['description'] as String,
        color: feature['color'] as Color,
      )).toList(),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Reduced from 16
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16), // Reduced from 20
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10, // Reduced from 12
            offset: const Offset(0, 3), // Reduced from 4
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48, // Reduced from 56
            height: 48, // Reduced from 56
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12), // Reduced from 16
            ),
            child: Icon(icon, color: color, size: 24), // Reduced from 28
          ),
          const SizedBox(width: 12), // Reduced from 16
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14, // Reduced from 16
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4), // Reduced from 6
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12, // Reduced from 14
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    height: 1.3, // Reduced from 1.4
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6), // Reduced from 8
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10), // Reduced from 12
            ),
            child: Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 14, // Reduced from 16
            ),
          ),
        ],
      ),
    );
  }

  
  void _navigateToSettings() {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    ),
  );
}
}
