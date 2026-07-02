import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class PdfService {
  static Future<void> generateAndShareReport({
    required String studentName,
    required String studentEmail,
    String? company,
    String? location,
    String? specialization,
    required List<LogModel> logs,
    required String reportType,
  }) async {
    final pdf = pw.Document();
    double totalHours = logs.fold(0.0, (sum, log) => sum + log.hoursWorked);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INTERNSYNC PRO', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
                    pw.Text('Enterprise Internship Tracking Matrix', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo700,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'OFFICIAL REPORT',
                    style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.indigo100, thickness: 1.5),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey200),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                pw.Text('Verified Digitally via InternSync Pro v1.0', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
        build: (context) => [
          pw.Text(reportType.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 20),
          
          // Student & Organization Info Card
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey200),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoLabel('STUDENT NAME'),
                      pw.Text(studentName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      _infoLabel('ORGANIZATION'),
                      pw.Text(company ?? 'N/A', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      _infoLabel('DOMAIN / SPECIALIZATION'),
                      pw.Text(specialization ?? 'N/A', style: pw.TextStyle(fontSize: 11, color: PdfColors.indigo700, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoLabel('EMAIL ADDRESS'),
                      pw.Text(studentEmail, style: const pw.TextStyle(fontSize: 11)),
                      pw.SizedBox(height: 12),
                      _infoLabel('LOCATION'),
                      pw.Text(location ?? 'N/A', style: const pw.TextStyle(fontSize: 11)),
                      pw.SizedBox(height: 12),
                      _infoLabel('REPORT GENERATED'),
                      pw.Text(DateTime.now().toString().split('.')[0], style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.indigo100),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('TOTAL HOURS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600, letterSpacing: 1)),
                      pw.SizedBox(height: 4),
                      pw.Text(totalHours.toStringAsFixed(1), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 30),
          pw.Text('DETAILED PERFORMANCE LOG', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700, letterSpacing: 1)),
          pw.SizedBox(height: 12),
          
          // Logs Table
          pw.TableHelper.fromTextArray(
            headers: ['DATE', 'TASKS EXECUTED', 'HRS', 'LEARNINGS & OUTCOMES', 'SUPERVISOR NOTES'],
            data: logs.map((log) => [
              DateFormat('dd MMM yyyy').format(log.date),
              log.tasksDone,
              '${log.hoursWorked}',
              log.learnings,
              log.mentorNotes.isEmpty ? 'Pending Review' : log.mentorNotes,
            ]).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            cellStyle: const pw.TextStyle(fontSize: 8),
            columnWidths: {
              0: const pw.FixedColumnWidth(60),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(30),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FlexColumnWidth(2),
            },
            cellPadding: const pw.EdgeInsets.all(8),
            headerAlignments: {
              2: pw.Alignment.center,
            },
            cellAlignments: {
              2: pw.Alignment.center,
            },
          ),
          
          pw.SizedBox(height: 60),
          
          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _signatureBlock('STUDENT SIGNATURE'),
              _signatureBlock('SUPERVISOR SIGN-OFF'),
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: '${studentName}_internship_report.pdf');
  }

  static pw.Widget _infoLabel(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500, letterSpacing: 1)),
    );
  }

  static pw.Widget _signatureBlock(String label) {
    return pw.Column(
      children: [
        pw.Container(
          width: 150,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
}
