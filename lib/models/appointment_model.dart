class Appointment {
  final String id;
  final String doctorId;
  final String doctorName;
  final String userName;
  final String userPhone;
  final String? userEmail;
  final String date;
  final String time;
  final String appointmentType;
  final String? symptoms;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final DateTime? rescheduledAt;

  Appointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.userName,
    required this.userPhone,
    this.userEmail,
    required this.date,
    required this.time,
    required this.appointmentType,
    this.symptoms,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.cancellationReason,
    this.cancelledAt,
    this.rescheduledAt,
  });

  factory Appointment.fromFirestore(String id, Map<String, dynamic> data) {
    return Appointment(
      id: id,
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      userEmail: data['userEmail'],
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      appointmentType: data['appointmentType'] ?? 'chat',
      symptoms: data['symptoms'],
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      cancellationReason: data['cancellationReason'],
      cancelledAt: data['cancelledAt']?.toDate(),
      rescheduledAt: data['rescheduledAt']?.toDate(),
    );
  }

  get notes => null;

  Map<String, dynamic> toFirestore() {
    return {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'userName': userName,
      'userPhone': userPhone,
      'userEmail': userEmail,
      'date': date,
      'time': time,
      'appointmentType': appointmentType,
      'symptoms': symptoms,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'cancellationReason': cancellationReason,
      'cancelledAt': cancelledAt,
      'rescheduledAt': rescheduledAt,
    };
  }
}
