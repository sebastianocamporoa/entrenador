import 'package:flutter/foundation.dart';

class TrainingSession {
  final String id;
  final String trainerId;
  final String? clientId;
  final DateTime startTime;
  final DateTime endTime;
  final String? notes;
  final String? clientName;

  TrainingSession({
    required this.id,
    required this.trainerId,
    this.clientId,
    required this.startTime,
    required this.endTime,
    this.notes,
    this.clientName,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'] as String,
      trainerId: json['trainer_id'] as String,
      clientId: json['client_id'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      notes: json['notes'] as String?,
      clientName: json['client_name'] as String?, // opcional
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trainer_id': trainerId,
    'client_id': clientId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'notes': notes,
  };

  @override
  String toString() =>
      'TrainingSession($startTime - ${clientName ?? clientId ?? "Sin cliente"})';
}
