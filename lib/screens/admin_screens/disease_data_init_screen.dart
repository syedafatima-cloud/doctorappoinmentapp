// screens/admin/admin_disease_init_screen.dart
import 'package:flutter/material.dart';
import '../../services/disease_firestore_service.dart';

class AdminDiseaseInitScreen extends StatefulWidget {
  const AdminDiseaseInitScreen({super.key});

  @override
  State<AdminDiseaseInitScreen> createState() => _AdminDiseaseInitScreenState();
}

class _AdminDiseaseInitScreenState extends State<AdminDiseaseInitScreen> {
  bool _isLoading = false;
  bool _isInitialized = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkInitializationStatus();
  }

  Future<void> _checkInitializationStatus() async {
    try {
      final bool initialized = await DiseaseFirestoreService.isDiseaseDataInitialized();
      setState(() {
        _isInitialized = initialized;
        _statusMessage = initialized 
            ? 'Disease data is already initialized in Firestore'
            : 'Disease data not found in Firestore';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking initialization status: $e';
      });
    }
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing disease data...';
    });

    try {
      await DiseaseFirestoreService.initializeDiseaseData();
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Successfully initialized disease data in Firestore!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reinitializeData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Re-initializing disease data...';
    });

    try {
      // You might want to add a method to clear existing data first
      await DiseaseFirestoreService.initializeDiseaseData();
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Successfully re-initialized disease data!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error re-initializing data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Disease Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.warning,
                          color: _isInitialized ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Initialization Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disease Data Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('This will initialize the following health concerns:'),
                    SizedBox(height: 8),
                    Text('• Heart Problems (Cardiology)\n'
                         '• Stomach Issues (Gastroenterology)\n'
                         '• Breathing Problems (Pulmonology)\n'
                         '• Brain & Nerves (Neurology)\n'
                         '• Bones & Joints (Orthopedics)\n'
                         '• Skin Problems (Dermatology)\n'
                         '• Mental Health (Psychiatry)\n'
                         '• Eye Problems (Ophthalmology)\n'
                         '• Ear, Nose & Throat (ENT)\n'
                         '• Women\'s Health (Gynecology)\n'
                         '• Children\'s Health (Pediatrics)\n'
                         '• Kidney & Urinary (Urology)\n'
                         '• Hormone Issues (Endocrinology)\n'
                         '• Cancer & Tumors (Oncology)\n'
                         '• Emergency Issues (Emergency Medicine)\n'
                         '• General Health (General Practice)',
                         style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (!_isInitialized)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _initializeData,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isLoading ? 'Initializing...' : 'Initialize Disease Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            
            if (_isInitialized) ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _reinitializeData,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isLoading ? 'Re-initializing...' : 'Re-initialize Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              const SizedBox(height: 12),
              
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('Data Ready - Continue'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.green),
                  foregroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Click "Initialize Disease Data" to populate Firestore\n'
                      '2. This creates a "health_concerns" collection\n'
                      '3. Each disease includes name, description, specializations, icon, and color\n'
                      '4. The app will automatically load this data when patients select health concerns\n'
                      '5. You only need to do this once per project',
                      style: TextStyle(fontSize: 12),
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
}