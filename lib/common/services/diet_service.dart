import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';

class DietService {
  final _supa = Supabase.instance.client;

  // Ya no necesitamos la API Key aquí. ¡Seguridad total! 🔒

  Future<void> generateAndSaveDiet({
    required String clientId,
    required double currentWeight,
    required double height,
    required String goal, // Agregamos el objetivo
    List<String>? photoUrls, // Agregamos las fotos
  }) async {
    // 1. LLAMADA A TU EDGE FUNCTION
    // Le enviamos los datos y ella se encarga de todo
    final FunctionResponse response = await _supa.functions.invoke(
      'generate-diet',
      body: {
        'weight': currentWeight,
        'height': height,
        'goal': goal,
        'photoUrls': photoUrls ?? [],
      },
    );

    // Validamos respuesta
    if (response.status != 200) {
      throw Exception(
        'Error del servidor: ${response.data['error'] ?? 'Desconocido'}',
      );
    }

    final String dietContent = response.data['diet'];

    // 2. Crear PDF (Igual que antes)
    final pdfBytes = await _createPdfDocument(dietContent);

    // 3. Guardar temporal y subir
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/dieta_ia.pdf");
    await file.writeAsBytes(pdfBytes);

    final fileName = '${clientId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await _supa.storage.from('diets').upload(fileName, file);

    // 4. Abrir
    await OpenFilex.open(file.path);
  }

  // --- GENERADOR PDF CORREGIDO ---
  Future<Uint8List> _createPdfDocument(String content) async {
    final pdf = pw.Document();

    // Usamos MultiPage para que soporte textos largos y cree varias hojas
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // MARGENES: Importante para que no se corte al imprimir
        margin: const pw.EdgeInsets.all(32),

        // 1. EL ENCABEZADO (Se repite en cada página si quieres, o solo en la primera)
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "ENTRENADOR APP",
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Plan Nutricional",
                    style: pw.TextStyle(fontSize: 18, color: PdfColors.purple),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),
            ],
          );
        },

        // 2. EL PIE DE PÁGINA
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              "Página ${context.pageNumber} de ${context.pagesCount} - Generado por IA",
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          );
        },

        // 3. EL CONTENIDO (La Dieta)
        build: (pw.Context context) {
          return [
            pw.Paragraph(
              text: _removeEmojis(content), // Limpiamos emojis por si acaso
              style: const pw.TextStyle(
                fontSize: 12,
                lineSpacing:
                    1.5, // <--- CAMBIO IMPORTANTE: 1.5 es legible, 5 era excesivo
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // --- FUNCIÓN EXTRA: LIMPIAR EMOJIS ---
  // El PDF base de Flutter a veces falla si la IA manda manzanas 🍎 o huevos 🍳
  // Esta función simple quita caracteres que no sean texto básico.
  String _removeEmojis(String text) {
    // Esta expresión regular deja solo texto, números, puntuación y saltos de línea
    return text.replaceAll(RegExp(r'[^\x00-\x7F\u00C0-\u00FF\n\r\t]'), '');
  }
}
