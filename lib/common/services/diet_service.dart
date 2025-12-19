import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';

class DietService {
  final _supa = Supabase.instance.client;

  // --- 1. GENERAR NUEVA DIETA (IA + BASE DE DATOS) ---
  Future<void> generateAndSaveDiet({
    required String clientId,
    required double currentWeight,
    required double height,
    required String goal,
    required int age,
    required String activity,
    List<String>? photoUrls,
  }) async {
    try {
      // A. LLAMADA A EDGE FUNCTION (IA)
      final FunctionResponse response = await _supa.functions.invoke(
        'generate-diet',
        body: {
          'weight': currentWeight,
          'height': height,
          'goal': goal,
          'age': age,
          'activity_level': activity,
          'photoUrls': photoUrls ?? [],
        },
      );

      if (response.status != 200) {
        throw Exception(
          'Error del servidor: ${response.data['error'] ?? 'Desconocido'}',
        );
      }

      final String dietContent = response.data['diet'];

      // B. CREAR PDF
      final pdfBytes = await _createPdfDocument(dietContent);

      // C. GUARDAR EN TEMPORAL (Para abrirlo ya)
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/dieta_ia.pdf");
      await file.writeAsBytes(pdfBytes);

      // D. SUBIR AL STORAGE
      // Usamos un nombre único con timestamp
      final fileName =
          '${clientId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await _supa.storage.from('diets').upload(fileName, file);

      // E. GUARDAR REGISTRO EN BASE DE DATOS (NUEVO) 📝
      // Esto nos permite saber cuál es la dieta actual del cliente
      await _supa.from('diet_plans').insert({
        'client_id': clientId,
        'file_path': fileName,
      });

      // F. ABRIR EL ARCHIVO
      await OpenFilex.open(file.path);
    } catch (e) {
      throw Exception('Error generando dieta: $e');
    }
  }

  // --- 2. ABRIR ÚLTIMA DIETA EXISTENTE (AHORRO DE DINERO) 💰 ---
  Future<bool> openLastDiet(String clientId) async {
    try {
      // A. Buscar en la base de datos la última dieta de este cliente
      final data = await _supa
          .from('diet_plans')
          .select('file_path')
          .eq('client_id', clientId)
          .order('created_at', ascending: false) // La más reciente
          .limit(1)
          .maybeSingle();

      // Si no hay registro, devolvemos false para que la UI sepa
      if (data == null) return false;

      final String filePath = data['file_path'];

      // B. Descargar el archivo desde el Storage
      final Uint8List fileBytes = await _supa.storage
          .from('diets')
          .download(filePath);

      // C. Guardar en temporal y abrir
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/ultima_dieta.pdf");
      await file.writeAsBytes(fileBytes);

      await OpenFilex.open(file.path);
      return true; // Éxito
    } catch (e) {
      // Si falla (ej: borraron el archivo del storage manualmente), lanzamos error
      print('Error recuperando dieta: $e');
      throw Exception('No se pudo recuperar la dieta anterior');
    }
  }

  // --- 3. GENERADOR DE PDF (CORREGIDO MULTIPAGE) ---
  Future<Uint8List> _createPdfDocument(String content) async {
    final pdf = pw.Document();

    // Usamos MultiPage para soportar textos largos automáticamente
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),

        // Encabezado
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

        // Pie de página
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

        // Contenido
        build: (pw.Context context) {
          return [
            pw.Paragraph(
              text: _removeEmojis(content),
              style: const pw.TextStyle(
                fontSize: 12,
                lineSpacing: 1.5, // Espaciado legible
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // --- 4. UTILIDADES ---
  String _removeEmojis(String text) {
    // Elimina caracteres que no sean texto básico para evitar errores de renderizado
    return text.replaceAll(RegExp(r'[^\x00-\x7F\u00C0-\u00FF\n\r\t]'), '');
  }
}
