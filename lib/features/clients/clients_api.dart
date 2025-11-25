import 'package:supabase_flutter/supabase_flutter.dart';

class ClientsApi {
  final supa = Supabase.instance.client;

  /// Lista todos los clientes asignados al coach actual
  Future<List<Map<String, dynamic>>> list() async {
    final coach = supa.auth.currentUser;
    if (coach == null) return [];

    return await supa
        .from('clients')
        .select('id, name, email, is_active')
        .eq('trainer_id', coach.id)
        .order('name');
  }

  /// Agrega un cliente usando su correo electrónico
  Future<void> addClient(String email) async {
    final coach = supa.auth.currentUser;
    if (coach == null) throw 'No autenticado';

    // 1) Buscar usuario en app_user
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

    // 2) Revisar si ya existe en clients
    final existingClient = await supa
        .from('clients')
        .select('id')
        .eq('app_user_id', appUserId)
        .maybeSingle();

    late String clientId;

    if (existingClient == null) {
      // 3) Crear en clients
      final inserted = await supa
          .from('clients')
          .insert({
            'trainer_id': coach.id,
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

      // Si existía pero no estaba asignado al coach → actualizar trainer_id
      await supa
          .from('clients')
          .update({'trainer_id': coach.id})
          .eq('id', clientId);
    }

    // 4) Crear vínculo en client_trainer si no existe
    final linkExists = await supa
        .from('client_trainer')
        .select()
        .eq('client_id', clientId)
        .eq('trainer_id', coach.id)
        .maybeSingle();

    if (linkExists != null) return;

    await supa.from('client_trainer').insert({
      'client_id': clientId,
      'trainer_id': coach.id,
    });
  }
}
