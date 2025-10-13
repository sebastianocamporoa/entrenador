import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/plan.dart';

class PlansRepo {
  final _supa = Supabase.instance.client;

  Future<List<Plan>> listMyPlans() async {
    final uid = _supa.auth.currentUser!.id;
    final res = await _supa
        .from('plan')
        .select()
        .eq('trainer_id', uid)
        .order('created_at', ascending: false);
    return (res as List).map((m) => Plan.fromMap(m)).toList();
  }

  Future<String> add(Plan p) async {
    final uid = _supa.auth.currentUser!.id;
    final inserted = await _supa
        .from('plan')
        .insert({
          'trainer_id': uid,
          'name': p.name,
          'goal': p.goal,
          'scope': 'weekly',
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  Future<void> remove(String id) async {
    await _supa.from('plan').delete().eq('id', id);
  }
}
