class ClientTrainingPlan {
  final String id;
  final String planId;
  final String clientId;
  final DateTime? startDate;
  final DateTime? endDate;

  ClientTrainingPlan({
    required this.id,
    required this.planId,
    required this.clientId,
    this.startDate,
    this.endDate,
  });

  factory ClientTrainingPlan.fromMap(Map<String, dynamic> m) =>
      ClientTrainingPlan(
        id: m['id'],
        planId: m['plan_id'],
        clientId: m['client_id'],
        startDate: m['start_date'] != null
            ? DateTime.parse(m['start_date'])
            : null,
        endDate: m['end_date'] != null ? DateTime.parse(m['end_date']) : null,
      );

  Map<String, dynamic> toInsert() => {
    'plan_id': planId,
    'client_id': clientId,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
  };
}
