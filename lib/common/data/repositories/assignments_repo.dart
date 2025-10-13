import 'package:supabase_flutter/supabase_flutter.dart';

class AssignmentsRepo {
  final _supa = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> todayWorkoutForClient() async {
    final res = await _supa.rpc('rpc_today_workout');
    return List<Map<String, dynamic>>.from(res as List);
  }
}
