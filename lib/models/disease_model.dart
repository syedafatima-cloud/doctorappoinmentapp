// models/disease_model.dart
import 'package:flutter/material.dart';

class Disease {
  final String name;
  final String description;
  final List<String> specializations;
  final IconData icon;
  final Color color;

  Disease({
    required this.name,
    required this.description,
    required this.specializations,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'specializations': specializations,
      'icon': icon.codePoint,
      'color': color.value,
    };
  }

  factory Disease.fromMap(Map<String, dynamic> map) {
    return Disease(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      specializations: List<String>.from(map['specializations'] ?? []),
      icon: IconData(map['icon'] ?? Icons.health_and_safety.codePoint, fontFamily: 'MaterialIcons'),
      color: Color(map['color'] ?? Colors.grey.value),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Disease && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

