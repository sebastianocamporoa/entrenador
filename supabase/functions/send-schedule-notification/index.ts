// supabase/functions/send-schedule-notification/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { JWT } from "npm:google-auth-library@9"
import { serviceAccount } from './credentials.ts'

console.log("🚀 Iniciando sistema de notificaciones de Horario/Planes")

serve(async (req) => {
  try {
    const payload = await req.json()

    // Validamos que haya datos
    if (!payload.record && !payload.old_record) {
      return new Response("No record found", { status: 200 })
    }

    // Obtenemos el registro (si es DELETE, usamos old_record)
    const record = payload.record ?? payload.old_record
    const table = payload.table // 'client_schedule' o 'plan_exercises' (o el nombre real de tu tabla 2)
    const eventType = payload.type // 'INSERT', 'UPDATE', 'DELETE'

    console.log(`🔔 Evento: ${eventType} en Tabla: ${table}`)

    // --- SETUP SUPABASE ---
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Lista de IDs de clientes a notificar
    let clientIdsToNotify: string[] = []
    let notificationTitle = ""
    let notificationBody = ""

    // --- LÓGICA SEGÚN LA TABLA ---

    if (table === 'client_schedule') {
      // ESCENARIO 1: Se modificó el horario de UN cliente
      // Asumimos que esta tabla tiene una columna 'client_id'
      if (record.client_id) {
        clientIdsToNotify.push(record.client_id)
        notificationTitle = "📅 Actualización de Horario"
        notificationBody = "Tu entrenador ha modificado tu calendario de entrenamientos."
      }

    } else {
      // ESCENARIO 2: Se modificaron los ejercicios de un PLAN (plan_exercises)
      // Debemos buscar a TODOS los clientes que tengan este plan asignado
      const planId = record.plan_id
      
      console.log(`🔎 Buscando clientes suscritos al plan ${planId}...`)

      // Buscamos en client_schedule todos los clientes que usan este plan
      const { data: schedules, error: schedError } = await supabaseAdmin
        .from('client_schedule')
        .select('client_id')
        .eq('plan_id', planId)
      
      if (schedError) {
        console.error("Error buscando suscripciones:", schedError)
      } else if (schedules && schedules.length > 0) {
        // Extraemos los IDs únicos (Set elimina duplicados si un cliente tiene el plan 2 veces)
        const uniqueIds = [...new Set(schedules.map(s => s.client_id))]
        clientIdsToNotify.push(...uniqueIds)
        
        notificationTitle = "💪 Plan Actualizado"
        notificationBody = "Se han agregado o modificado ejercicios en tu plan de rutina."
      } else {
        console.log("⚠️ Nadie tiene este plan asignado actualmente.")
        return new Response("No subscribers for this plan", { status: 200 })
      }
    }

    // --- OBTENER TOKENS (Lógica de 2 pasos segura) ---
    
    if (clientIdsToNotify.length === 0) {
      return new Response("No clients to notify", { status: 200 })
    }

    console.log(`🎯 Notificando a ${clientIdsToNotify.length} clientes...`)

    // 1. Buscamos los app_user_id de estos clientes
    const { data: clientsData, error: clientError } = await supabaseAdmin
      .from('clients')
      .select('app_user_id')
      .in('id', clientIdsToNotify)

    if (clientError || !clientsData) {
      console.error("Error buscando app_users:", clientError)
      return new Response("Error fetching clients", { status: 400 })
    }

    const appUserIds = clientsData
        .map(c => c.app_user_id)
        .filter(id => id !== null) // Quitamos nulos

    if (appUserIds.length === 0) return new Response("No app users found", { status: 200 })

    // 2. Buscamos los tokens FCM
    const { data: usersData, error: userError } = await supabaseAdmin
      .from('app_user')
      .select('fcm_token')
      .in('id', appUserIds)
      .not('fcm_token', 'is', null) // Solo los que tienen token

    if (userError || !usersData || usersData.length === 0) {
      console.log("Ningún usuario tiene token FCM activo.")
      return new Response("No tokens found", { status: 200 })
    }

    const tokens = usersData.map(u => u.fcm_token)

    // --- PREPARAR FIREBASE ---
    if (!serviceAccount.client_email || !serviceAccount.private_key) throw new Error("Credentials error")
    const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n')

    const client = new JWT({
      email: serviceAccount.client_email,
      key: privateKey,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })
    const accessToken = await client.getAccessToken()

    // --- ENVÍO MASIVO (Loop) ---
    // Firebase HTTP v1 no soporta "multicast" nativo en una sola petición REST simple,
    // así que iteramos (para <100 usuarios es instantáneo).
    
    const sendPromises = tokens.map(token => {
      const notification = {
        message: {
          token: token,
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            screen: "calendar", // O la pantalla que quieras abrir
            plan_id: record.plan_id || ""
          },
        },
      }

      return fetch(
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
    })

    await Promise.all(sendPromises)
    console.log(`✅ ${tokens.length} notificaciones enviadas exitosamente.`)

    return new Response(JSON.stringify({ success: true, count: tokens.length }), {
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