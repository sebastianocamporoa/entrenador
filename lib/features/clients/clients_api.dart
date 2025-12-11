import 'package:supabase_flutter/supabase_flutter.dart';

class ClientsApi {
  final supa = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> list() async {
    final authUser = supa.auth.currentUser;
    if (authUser == null) return [];

    final coachProfile = await supa
        .from('app_user')
        .select('id')
        .eq('auth_user_id', authUser.id)
        .maybeSingle();

    if (coachProfile == null) return [];

    final coachId = coachProfile['id'];

    return await supa
        .from('clients')
        .select('id, name, email, is_active')
        .eq('trainer_id', coachId)
        .order('name');
  }

  Future<void> addClient(String email) async {
    final authUser = supa.auth.currentUser;
    if (authUser == null) throw 'No autenticado';

    final coachProfile = await supa
        .from('app_user')
        .select('id')
        .eq('auth_user_id', authUser.id)
        .single();

    final coachId = coachProfile['id'] as String;

    final cleanEmail = email.trim().toLowerCase();

    final appUser = await supa
        .from('app_user')
        .select('id, full_name, email')
        .eq('email', cleanEmail)
        .maybeSingle();

    if (appUser == null) {
      throw 'El usuario no existe. Debe registrarse primero.';
    }

    final appUserId = appUser['id'] as String;

    final existingClient = await supa
        .from('clients')
        .select('id')
        .eq('app_user_id', appUserId)
        .maybeSingle();

    late String clientId;

    if (existingClient == null) {
      final inserted = await supa
          .from('clients')
          .insert({
            'trainer_id': coachId,
            'app_user_id': appUserId,
            'name': appUser['full_name'],
            'email': appUser['email'],
            'is_active': true,
          })
          .select()
          .single();

      clientId = inserted['id'] as String;
    } else {
      clientId = existingClient['id'] as String;

      await supa
          .from('clients')
          .update({'trainer_id': coachId})
          .eq('id', clientId);
    }

    final linkExists = await supa
        .from('client_trainer')
        .select()
        .eq('client_id', clientId)
        .eq('trainer_id', coachId)
        .maybeSingle();

    if (linkExists != null) return;

    await supa.from('client_trainer').insert({
      'client_id': clientId,
      'trainer_id': coachId,
    });
  }
}
