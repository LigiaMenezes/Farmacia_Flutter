import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        'descricao': '',
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
        e['vencimento'] != null ? TextCellValue(_formatarData(e['vencimento'])) : TextCellValue(''),
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