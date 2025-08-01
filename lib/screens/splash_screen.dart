import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  
  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _progressController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;
  
  String _loadingText = 'Initializing...';
  final List<String> _loadingSteps = [
    'Initializing...',
    'Loading AI Models...',
    'Connecting to Services...',
    'Setting Up Security...',
    'Almost Ready...',
  ];
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF7E57C2),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    _initializeAnimations();
    _startAnimationSequence();
    _startLoadingSteps();
    _navigateToHome();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimationSequence() {
    // Start logo animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _fadeController.forward();
        _scaleController.forward();
      }
    });
    
    // Start text animation
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _slideController.forward();
      }
    });
    
    // Start progress animation
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _progressController.forward();
      }
    });
  }

  void _startLoadingSteps() {
    Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_currentStepIndex < _loadingSteps.length - 1) {
        setState(() {
          _currentStepIndex++;
          _loadingText = _loadingSteps[_currentStepIndex];
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _navigateToHome() {
    Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7E57C2),
              Color(0xFFC5CAE9),
              Color(0xFFEDE7F6),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top decorative elements
              Expanded(
                flex: 2,
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Floating medical icons
                      _buildFloatingIcon(
                        Icons.medical_services_outlined,
                        top: 60,
                        right: 40,
                        delay: 1000,
                      ),
                      _buildFloatingIcon(
                        Icons.favorite_outline,
                        top: 120,
                        left: 30,
                        delay: 1500,
                      ),
                      _buildFloatingIcon(
                        Icons.psychology_outlined,
                        top: 80,
                        left: MediaQuery.of(context).size.width * 0.7,
                        delay: 2000,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Main logo and branding section
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo container with animation
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.medical_services,
                                size: 60,
                                color: Color(0xFF7E57C2),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // App name with slide animation
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            const Text(
                              'MediCare+',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AI-Powered Healthcare',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w300,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Loading section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Progress bar
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Container(
                            width: double.infinity,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _progressAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Loading text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _loadingText,
                          key: ValueKey(_loadingText),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Loading dots animation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              double delay = index * 0.3;
                              double animationValue = (_progressController.value - delay).clamp(0.0, 1.0);
                              double opacity = (animationValue * 2).clamp(0.0, 1.0);
                              if (animationValue > 0.5) {
                                opacity = (2 - animationValue * 2).clamp(0.0, 1.0);
                              }
                              
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                child: Opacity(
                                  opacity: opacity,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom section with version or tagline
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Your Health, Our Priority',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, {
    required double top,
    double? left,
    double? right,
    required int delay,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: delay + 1000),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -10 * value),
            child: Opacity(
              opacity: value * 0.6,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}