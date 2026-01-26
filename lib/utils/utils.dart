import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// ---- FUNÇÃO DE NAVEGAÇÃO  ----
void redirect(BuildContext context, Widget tela) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => tela),
  );
}
/// ---- FUNÇÃO DE NAVEGAÇÃO COM REPLACEMENT (substitui tela atual) ----
void redirectReplace(BuildContext context, Widget tela) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => tela),
  );
}

class RelatorioExcelService {
  static Future<void> gerarRelatorioCliente({
    required String cpf,
    required String nomeCliente,
  }) async {
    final supabase = Supabase.instance.client;

    final dividas = await supabase
        .from('shadow_debts')
        .select('id, init_value, init_date, end_date')
        .eq('cpf', cpf);

    final pagamentos = await supabase
        .from('shadow_payments')
        .select('value, date, method')
        .eq('cpf', cpf);

    final List<Map<String, dynamic>> eventos = [];

    for (var d in dividas) {
      eventos.add({
        'data': _parseDate(d['init_date']),
        'vencimento': d['end_date'] != null
            ? _parseDate(d['end_date'])
            : null,
        'tipo': 'Dívida',
        'valor': (d['init_value'] as num).toDouble(),
        'descricao': '-',
      });
    }

    for (var p in pagamentos) {
      eventos.add({
        'data': DateTime.parse(p['date']),
        'tipo': 'Pagamento',
        'valor': p['value'],
        'descricao': 'Pagamento em ${p['method']}',
      });
    }

    eventos.sort((a, b) => a['data'].compareTo(b['data']));

    final excel = Excel.createExcel();
    final sheet = excel['Relatório'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Data'),
      TextCellValue('Vencimento'),
      TextCellValue('Tipo'),
      TextCellValue('Valor'),
      TextCellValue('Descrição'),
    ]);

    for (var e in eventos) {
      sheet.appendRow([
        TextCellValue(_formatarData(e['data'])),
        e['vencimento'] != null ? TextCellValue(_formatarData(e['vencimento'])) : TextCellValue('-'),
        TextCellValue(e['tipo']),
        DoubleCellValue((e['valor'] as num).toDouble()),
        TextCellValue(e['descricao']),
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/Relatorio_${nomeCliente.replaceAll(' ', '_')}.xlsx';

    final fileBytes = excel.encode();
    final file = File(path);
    await file.writeAsBytes(fileBytes!);

    await OpenFilex.open(path);
  }

  static String _formatarData(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
           '${d.month.toString().padLeft(2, '0')}/'
           '${d.year}';
  }
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.parse(v.toString());
  }
}

class RelatorioPDFService {
  static Future<void> gerarRelatorioCliente({
    required String cpf,
    required String nomeCliente,
  }) async {
    final supabase = Supabase.instance.client;

    final dividas = await supabase
        .from('shadow_debts')
        .select('id, init_value, init_date, end_date')
        .eq('cpf', cpf);

    final pagamentos = await supabase
        .from('shadow_payments')
        .select('value, date, method')
        .eq('cpf', cpf);

    final List<Map<String, dynamic>> eventos = [];

    // ---- DÍVIDAS ----
    for (var d in dividas) {
      eventos.add({
        'data': _parseDate(d['init_date'])!,
        'vencimento': _parseDate(d['end_date']),
        'tipo': 'Dívida',
        'valor': (d['init_value'] as num).toDouble(),
        'descricao': '-',
      });
    }

    // ---- PAGAMENTOS ----
    for (var p in pagamentos) {
      eventos.add({
        'data': _parseDate(p['date'])!,
        'vencimento': null,
        'tipo': 'Pagamento',
        'valor': (p['value'] as num).toDouble(),
        'descricao': 'Pagamento em ${p['method']}',
      });
    }

    // ---- ORDENAR CRONOLOGICAMENTE ----
    eventos.sort((a, b) => a['data'].compareTo(b['data']));

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _cabecalho(nomeCliente),
          pw.SizedBox(height: 20),
          _tabela(eventos),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/Relatorio_${nomeCliente.replaceAll(' ', '_')}.pdf';

    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    await OpenFilex.open(path);
  }

  // ==================== COMPONENTES ====================

  static pw.Widget _cabecalho(String nomeCliente) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Relatório Financeiro do Cliente',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Cliente: $nomeCliente',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _tabela(List<Map<String, dynamic>> eventos) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FixedColumnWidth(70),
        1: const pw.FixedColumnWidth(70),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FlexColumnWidth(),
      },
      children: [
        _linhaCabecalho(),
        ...eventos.map(_linhaEvento),
      ],
    );
  }

  static pw.TableRow _linhaCabecalho() {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        _cell('Data', bold: true),
        _cell('Venc.', bold: true),
        _cell('Tipo', bold: true),
        _cell('Valor', bold: true),
        _cell('Descrição', bold: true),
      ],
    );
  }

  static pw.TableRow _linhaEvento(Map<String, dynamic> e) {
    final bool vencida = e['vencimento'] != null &&
        (e['vencimento'] as DateTime).isBefore(DateTime.now()) &&
        e['tipo'] == 'Dívida';

    return pw.TableRow(
      decoration: vencida
          ? const pw.BoxDecoration(color: PdfColors.red50)
          : null,
      children: [
        _cell(_formatarData(e['data'])),
        _cell(
          e['vencimento'] != null
              ? _formatarData(e['vencimento'])
              : '-',
        ),
        _cell(e['tipo']),
        _cell(
          'R\$ ${e['valor'].toStringAsFixed(2)}',
          align: pw.TextAlign.right,
        ),
        _cell(e['descricao']),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ==================== UTIL ====================

  static String _formatarData(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.parse(v.toString());
  }
}