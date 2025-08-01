import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  final List<FAQ> faqs = const [
    FAQ(
      question: "How do I book an appointment?",
      answer: "You can book an appointment through the main app screen by selecting 'Book Appointment' and choosing your preferred doctor, date, and time."
    ),
    FAQ(
      question: "What should I do in a medical emergency?",
      answer: "For life-threatening emergencies, call 1122 immediately. For urgent but non-emergency situations, use our emergency booking feature or call our medical helpline."
    ),
    FAQ(
      question: "How can I cancel or reschedule my appointment?",
      answer: "Go to 'My Appointments' section, select the appointment you want to modify, and choose 'Cancel' or 'Reschedule'. Please do this at least 2 hours before your appointment time."
    ),
    FAQ(
      question: "Are telemedicine consultations available?",
      answer: "Yes, we offer video consultations with qualified doctors. Select 'Video Consultation' when booking your appointment."
    ),
    FAQ(
      question: "How do I access my medical records?",
      answer: "Your medical records are available in the 'Health Records' section of the app. You can view test results, prescriptions, and consultation notes."
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          return FAQTile(faq: faqs[index]);
        },
      ),
    );
  }
}

class FAQ {
  final String question;
  final String answer;

  const FAQ({required this.question, required this.answer});
}

class FAQTile extends StatefulWidget {
  final FAQ faq;

  const FAQTile({super.key, required this.faq});

  @override
  State<FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<FAQTile> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF7E57C2).withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(widget.faq.question, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.faq.answer),
          ),
        ],
      ),
    );
  }
}