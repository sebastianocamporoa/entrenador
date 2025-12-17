// supabase/functions/generate-diet/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Manejo de CORS (para que Flutter pueda conectarse)
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Recibir datos desde Flutter
        const { weight, height, goal, photoUrls } = await req.json()

        // 2. Obtener la API Key de los secretos de Supabase
        const openAiKey = Deno.env.get('OPENAI_API_KEY')
        if (!openAiKey) {
            throw new Error('Falta la configuración de OPENAI_API_KEY en Supabase')
        }

        // 3. Preparar el mensaje para GPT-4o
        const contentMessage = [
            {
                type: "text",
                text: `Eres un nutricionista experto. Crea un plan de 1 día:
               - Peso: ${weight}kg, Altura: ${height}cm, Meta: ${goal}.
               Si hay fotos, úsalas para estimar composición corporal.
               
               Formato de respuesta (Texto plano para PDF):
               1. Análisis breve.
               2. Calorías/Macros.
               3. Menú: Desayuno, Almuerzo, Cena, Snacks.
               4. Consejos.`
            }
        ];

        // Adjuntar fotos si existen
        if (photoUrls && Array.isArray(photoUrls)) {
            photoUrls.forEach((url: string) => {
                if (url) contentMessage.push({ type: "image_url", image_url: { url } });
            });
        }

        // 4. Llamar a OpenAI
        const response = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${openAiKey}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                model: 'gpt-4o',
                messages: [{ role: 'user', content: contentMessage }],
                max_tokens: 1500,
            }),
        })

        const data = await response.json()
        if (data.error) throw new Error(data.error.message)

        // 5. Devolver la dieta a Flutter
        return new Response(
            JSON.stringify({ diet: data.choices[0].message.content }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )
    }
})