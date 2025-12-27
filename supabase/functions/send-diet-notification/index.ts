// supabase/functions/send-diet-notification/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { JWT } from "npm:google-auth-library@9"
// Importamos las credenciales (asegúrate de tener este archivo credentials.ts)
import { serviceAccount } from './credentials.ts'

console.log("🚀 Iniciando función (Método 2 Pasos - Sin Ambigüedad)")

serve(async (req) => {
  try {
    const payload = await req.json()

    // 1. Verificación básica
    if (!payload.record) {
      return new Response("No record found", { status: 200 })
    }
    const { client_id } = payload.record

    // 2. Setup Supabase
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // --- PASO 1: OBTENER EL ID DE USUARIO DEL CLIENTE ---
    // En lugar de hacer JOIN, solo pedimos el app_user_id exacto.
    const { data: clientRecord, error: clientError } = await supabaseAdmin
      .from('clients')
      .select('app_user_id')
      .eq('id', client_id)
      .single()

    if (clientError || !clientRecord) {
      console.error("❌ Error buscando cliente:", clientError)
      return new Response("Client not found", { status: 400 })
    }

    const targetUserId = clientRecord.app_user_id
    console.log("🎯 ID del Usuario Cliente objetivo:", targetUserId)

    if (!targetUserId) {
        console.log("⚠️ Este cliente no tiene un usuario de App asociado.")
        return new Response("No app_user_id for client", { status: 200 })
    }

    // --- PASO 2: OBTENER EL TOKEN DE ESE USUARIO ESPECÍFICO ---
    const { data: userRecord, error: userError } = await supabaseAdmin
      .from('app_user')
      .select('fcm_token')
      .eq('id', targetUserId) // Usamos 'id' si tu PK es el UUID, o 'auth_user_id' si usas ese.
      // Basado en tu JSON, la PK de app_user es 'id' (el UUID que empieza con 60a4d...)
      .single()

    if (userError) {
        console.error("❌ Error buscando usuario:", userError)
        return new Response("User fetch error", { status: 400 })
    }

    const fcmToken = userRecord?.fcm_token
    console.log("📱 Token encontrado:", fcmToken ? fcmToken.substring(0, 10) + "..." : "NULL")

    if (!fcmToken) {
      console.log("⚠️ El cliente existe pero no tiene token FCM (no se ha logueado en la app).")
      return new Response("No token found", { status: 200 })
    }

    // 4. PREPARAR CREDENCIALES
    if (!serviceAccount.client_email || !serviceAccount.private_key) {
        throw new Error("El archivo credentials.ts está incompleto");
    }

    const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n')

    // 5. Autenticación con Google
    const client = new JWT({
      email: serviceAccount.client_email,
      key: privateKey,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    const accessToken = await client.getAccessToken()

    // 6. Enviar Notificación
    const notification = {
      message: {
        token: fcmToken,
        notification: {
          title: "¡Nueva dieta asignada! 🥗",
          body: "Tu entrenador ha cargado un nuevo plan de nutrición para ti.",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          screen: "nutrition",
        },
      },
    }

    console.log("📤 Enviando a Firebase...")
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken.token}`,
        },
        body: JSON.stringify(notification),
      }
    )

    const responseData = await res.json()
    console.log("✅ Respuesta:", responseData)

    return new Response(JSON.stringify(responseData), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })

  } catch (err) {
    console.error("🔥 FATAL ERROR:", err.message)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})