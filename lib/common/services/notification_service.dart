import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final _supa = Supabase.instance.client;
  final _fcm = FirebaseMessaging.instance;

  /// 1. Inicializar y pedir permisos
  Future<void> init() async {
    // Pedir permiso al usuario (crítico para iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permiso de notificaciones concedido');

      // Obtener el token único del dispositivo
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // Escuchar cambios de token (ej. si el usuario reinstala la app)
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
    } else {
      debugPrint('Permiso de notificaciones denegado');
    }

    // Configurar cómo se comportan las notificaciones en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        'Notificación recibida en primer plano: ${message.notification?.title}',
      );
      // Aquí podrías mostrar un SnackBar o una alerta local
    });
  }

  /// 2. Guardar el token en Supabase vinculado al usuario actual
  Future<void> _saveTokenToDatabase(String token) async {
    final user = _supa.auth.currentUser;
    if (user == null) return;

    try {
      // Guardamos el token en la tabla app_user
      // Asegúrate de que tu tabla app_user tenga la columna 'fcm_token'
      await _supa
          .from('app_user')
          .update({'fcm_token': token})
          .eq('auth_user_id', user.id);

      debugPrint('FCM Token guardado en Supabase: $token');
    } catch (e) {
      debugPrint('Error guardando token FCM: $e');
    }
  }
}
