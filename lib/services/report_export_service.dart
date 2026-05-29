import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportExportService {
  /// Exports raw table data as a CSV file and triggers the native OS Share dialog.
  static Future<void> exportAsCsv({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> rows,
  }) async {
    try {
      final csvData = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final cleanTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final path = '${dir.path}/${cleanTitle}_report.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(path)], text: 'Here is your $title report from Mbeck Business.');
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  /// Exports raw table data as a styled PDF document and triggers the native OS Share dialog.
  static Future<void> exportAsPdf({
    required BuildContext context,
    required String title,
    required List<String> headers,
    required List<List<dynamic>> data,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Mbeck Business', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                    pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
                cellStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
                cellHeight: 25,
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                cellAlignments: {
                  for (var i = 0; i < headers.length; i++)
                    i: (i == 0) ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 30),
            ];
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Generated on ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
              ),
            );
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final cleanTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final path = '${dir.path}/${cleanTitle}_report.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(path)], text: 'Here is your $title report from Mbeck Business.');
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }
}
