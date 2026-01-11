import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_farmacia/utils/utils.dart';
import 'package:flutter_farmacia/screens/login.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter_farmacia/screens/Gerente/TelaCliente.dart';
import 'package:flutter_farmacia/screens/Gerente/TelaDivida.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeGerente extends StatefulWidget {
  final String users;

  const HomeGerente({super.key, required this.users});

  @override
  State<HomeGerente> createState() => _HomeGerenteState();
}

class _HomeGerenteState extends State<HomeGerente> {
  final supabase = Supabase.instance.client;

  int clientesQuitados = 0;
  int clientesEndividados = 0;
  int totalClientes = 0;
  double valorDividaTotal = 0.0;
  int _mesOffsetGrafico = 0;
  int _navIndex = 1;
  int? _touchedIndex;

  List<Map<String, dynamic>> funcionarios = [];
  bool loading = true;
  bool refreshingFuncionarios = false;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController positionController = TextEditingController();

  String? editarFuncionarioUsername;

  // Dados para o gráfico de dívidas por mês
  List<Map<String, dynamic>> dadosMensais = [];
  bool loadingMensal = true;

  // ==================== MÉTODOS DE POP-UP MELHORADOS ====================

  Future<void> _mostrarPopUpSucesso({
    required String titulo,
    required String mensagem,
    IconData? icone,
    Color corIcone = Colors.green,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: corIcone.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icone ?? Icons.check_circle,
                  size: 40,
                  color: corIcone,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                mensagem,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: 150,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarPopUpErro({
    required String titulo,
    required String mensagem,
    String? detalhes,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                mensagem,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (detalhes != null && detalhes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    detalhes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Fechar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        carregarTudo(); // Tentar novamente
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tentar Novamente'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarPopUpConfirmacao({
    required String titulo,
    required String mensagem,
    required VoidCallback onConfirmar,
    String textoConfirmar = 'Confirmar',
    String textoCancelar = 'Cancelar',
    Color corConfirmar = Colors.red,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                mensagem,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        textoCancelar,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirmar();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corConfirmar,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        textoConfirmar,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarPopUpLoading({
    required String mensagem,
    bool podeFechar = false,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: podeFechar,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Colors.red,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                mensagem,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (podeFechar) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarPopUpInformacao({
    required String titulo,
    required String mensagem,
    IconData icone = Icons.info_outline,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icone,
                  size: 35,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                mensagem,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Entendi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== MÉTODOS ORIGINAIS MODIFICADOS ====================

  @override
  void initState() {
    super.initState();
    carregarTudo();
  }

  Future<void> carregarTudo() async {
    setState(() => loading = true);
    await Future.wait([
      carregarDados(),
      carregarFuncionarios(),
      carregarDadosMensais(),
    ]);
    setState(() => loading = false);
  }

  Future<void> carregarDados() async {
    if (!mounted) return;
    
    setState(() => loading = true);

    try {
      debugPrint('=== CARREGANDO DADOS ===');
      
      final clientes = await supabase
          .from('clients')
          .select('cpf, name')
          .timeout(const Duration(seconds: 10));

      totalClientes = clientes.length;
      
      final dividas = await supabase
          .from('debts')
          .select('id, cpf, value, init_date, end_date')
          .timeout(const Duration(seconds: 10));

      final pagamentos = await supabase
          .from('payments')
          .select('debts_id, value')
          .timeout(const Duration(seconds: 10));
      
      final Map<int, double> pagamentosPorDivida = {};
      for (var pagamento in pagamentos) {
        final debtsId = pagamento['debts_id'] as int?;
        final value = pagamento['value'];
        final num? v = value is num ? value : num.tryParse('$value');
        
        if (debtsId != null && v != null) {
          pagamentosPorDivida[debtsId] = (pagamentosPorDivida[debtsId] ?? 0) + v.toDouble();
        }
      }

      double somaDividasAtivas = 0.0;
      final Set<String> cpfsComDividaAtiva = {};
      
      for (var divida in dividas) {
        final debtsId = divida['id'] as int?;
        final cpf = divida['cpf'] as String?;
        final value = divida['value'];
        final num? valorDivida = value is num ? value : num.tryParse('$value');
        
        if (debtsId == null || cpf == null || valorDivida == null || valorDivida <= 0) {
          continue;
        }
        
        final totalPago = pagamentosPorDivida[debtsId] ?? 0;
        final saldoDevedor = valorDivida;

        debugPrint('ID:$debtsId | Valor:$valorDivida | Pago:$totalPago | Saldo:$saldoDevedor');
        
        if (saldoDevedor > 0) {
          cpfsComDividaAtiva.add(cpf);
          somaDividasAtivas += saldoDevedor;
        }
      }

      valorDividaTotal = somaDividasAtivas;
      clientesEndividados = cpfsComDividaAtiva.length;
      clientesQuitados = totalClientes - clientesEndividados;

    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      
     
        if (!mounted) return;
        await _mostrarPopUpErro(
          titulo: 'Erro ao Carregar Dados',
          mensagem: 'Não foi possível carregar as informações do sistema.',
          detalhes: e.toString(),
        );
      
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> carregarDadosMensais() async {
    setState(() => loadingMensal = true);
    
    try {
      final DateTime agora = DateTime.now();
      final List<Map<String, dynamic>> mesesDados = [];
      
      // Buscar todas as dívidas
      final todasDividas = await supabase
          .from('debts')
          .select('id, value, init_date')
          .order('init_date');
      
      // Buscar todos os pagamentos
      final todosPagamentos = await supabase
          .from('payments')
          .select('value, date')
          .order('date');
      
      // Agrupar pagamentos por mês
      final Map<String, double> pagamentosPorMes = {};
      for (var pagamento in todosPagamentos) {
        final date = pagamento['date'] as String?;
        if (date != null) {
          final mesKey = date.substring(0, 7); // YYYY-MM
          final valorPagamento = pagamento['value'] is num
              ? pagamento['value'].toDouble()
              : double.tryParse('${pagamento['value']}') ?? 0.0;
          
          pagamentosPorMes[mesKey] = (pagamentosPorMes[mesKey] ?? 0) + valorPagamento;
        }
      }
      
      // Para cada um dos últimos 6 meses
      double saldoMesAnterior = 0.0;
      
      for (int i = 5; i >= 0; i--) {
        final DateTime mes = DateTime(agora.year, agora.month - i, 1);
        final String mesLabel = '${_getNomeMes(mes.month)}/${mes.year.toString().substring(2)}';
        final String mesKey = '${mes.year}-${mes.month.toString().padLeft(2, '0')}';
        
        final inicioMes = '${mes.year}-${mes.month.toString().padLeft(2, '0')}-01';
        final fimMes = mes.month == 12 
            ? '${mes.year + 1}-01-01'
            : '${mes.year}-${(mes.month + 1).toString().padLeft(2, '0')}-01';
        
        // 1. Calcular dívidas criadas NESTE mês
        double dividasCriadasNesteMes = 0.0;
        for (var divida in todasDividas) {
          final initDate = divida['init_date'] as String?;
          if (initDate != null && 
              initDate.compareTo(inicioMes) >= 0 && 
              initDate.compareTo(fimMes) < 0) {
            final valorDivida = divida['value'] is num 
                ? divida['value'].toDouble() 
                : double.tryParse('${divida['value']}') ?? 0.0;
            dividasCriadasNesteMes += valorDivida;
          }
        }
        
        // 2. Pagamentos feitos DURANTE este mês
        final double pagamentosNesteMes = pagamentosPorMes[mesKey] ?? 0.0;
        
        // 3. Calcular divida_total (saldo anterior + dívidas criadas neste mês)
        double dividaTotalParaMes = saldoMesAnterior + dividasCriadasNesteMes + pagamentosNesteMes;
        
        // 4. Calcular saldo devedor no FIM deste mês
        double saldoFimMes = dividaTotalParaMes - pagamentosNesteMes;
        saldoFimMes = saldoFimMes.clamp(0.0, double.infinity);
        
        // DEBUG
        debugPrint('=== MÊS: $mesLabel ===');
        debugPrint('Saldo mês anterior: R\$${saldoMesAnterior.toStringAsFixed(2)}');
        debugPrint('Dívidas criadas neste mês: R\$${dividasCriadasNesteMes.toStringAsFixed(2)}');
        debugPrint('Dívida total para o mês: R\$${dividaTotalParaMes.toStringAsFixed(2)}');
        debugPrint('Pagamentos neste mês: R\$${pagamentosNesteMes.toStringAsFixed(2)}');
        debugPrint('Saldo fim do mês: R\$${saldoFimMes.toStringAsFixed(2)}');
        
        mesesDados.add({
          'mes': mesLabel,
          'mes_key': mesKey,
          'divida_total': dividaTotalParaMes,  // Saldo anterior + dívidas criadas
          'divida_paga': pagamentosNesteMes,   // Pagamentos feitos DURANTE este mês
          'divida_restante': saldoFimMes,      // Saldo devedor no FIM deste mês
        });
        
        // Atualizar para próximo mês
        saldoMesAnterior = saldoFimMes;
      }
      
      setState(() {
        dadosMensais = mesesDados;
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados mensais: $e');
      dadosMensais = [];
    }
    
    setState(() => loadingMensal = false);
  }

  Widget _buildTextoCentro() {
    String valor;
    String titulo;
    Color cor;
    
    if (_touchedIndex == null) {
      valor = totalClientes.toString();
      titulo = 'Total';
      cor = Colors.blue;
    } else if (_touchedIndex == 0) {
      valor = clientesQuitados.toString();
      titulo = 'Quitados';
      cor = const Color(0xFF4CAF50);
    } else {
      valor = clientesEndividados.toString();
      titulo = 'Endividados';
      cor = const Color(0xFFF44336);
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getNomeMes(int mes) {
    final meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return meses[mes - 1];
  }

Widget _buildGraficoClientes() {
    if (totalClientes == 0) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.pie_chart,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            const Text(
              'Nenhum cliente cadastrado',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    List<PieChartSectionData> sections = [
      PieChartSectionData(
        value: clientesQuitados.toDouble(),
        color: const Color(0xFF4CAF50),
        radius: _touchedIndex == 0 ? 40 : 35,
        title: clientesQuitados > 0 
            ? '${((clientesQuitados / totalClientes) * 100).toStringAsFixed(0)}%'
            : '',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        showTitle: clientesQuitados > 0,
      ),
      PieChartSectionData(
        value: clientesEndividados.toDouble(),
        color: const Color(0xFFF44336),
        radius: _touchedIndex == 1 ? 40 : 35,
        title: clientesEndividados > 0
            ? '${((clientesEndividados / totalClientes) * 100).toStringAsFixed(0)}%'
            : '',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        showTitle: clientesEndividados > 0,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Column(
            children: [
              Text(
                'Clientes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Total: $totalClientes cliente${totalClientes != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    centerSpaceRadius: 60,
                    sectionsSpace: 3,
                    sections: sections,
                    pieTouchData: PieTouchData(
                      enabled: true, // Adicione esta linha para habilitar o toque
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          // Primeiro, verifica se o toque foi em uma seção
                        if (pieTouchResponse != null && 
                            pieTouchResponse.touchedSection != null) {
                          // TOQUE EM UMA SEÇÃO/FATIA
                          final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          
                          setState(() {
                            _touchedIndex = touchedIndex;
                          });
                        } else {
                          // TOQUE FORA DAS SEÇÕES (no "branco")
                          // Opção 1: Ignora completamente (não faz nada)
                          // return;
                          
                          // Opção 2: Desseleciona APENAS se já estava selecionado
                          if (_touchedIndex != null) {
                            setState(() {
                              _touchedIndex = null;
                            });
                          }
                        }
                      },
                    ), // <--- FECHA PieTouchData
                  ), // <--- FECHA PieChartData
                ), // <--- FECHA PieChart (ESTE ESTAVA FALTANDO!)
                _buildTextoCentro(),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Column(
            children: [
              Text(
                'Toque em uma fatia para ver detalhes',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Quitados: $clientesQuitados',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 15),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF44336),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Endividados: $clientesEndividados',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  } // FIM DA FUNÇÃO
  Widget _buildGraficoPizzaDividas() {
    final agora = DateTime.now();
    final mesAlvo = DateTime(agora.year, agora.month - _mesOffsetGrafico, 1);
    final String mesKey = '${mesAlvo.year}-${mesAlvo.month.toString().padLeft(2, '0')}';
    final String mesNome = _getNomeMes(mesAlvo.month);
    final String ano = mesAlvo.year.toString().substring(2);
    
    // Encontrar os dados do mês selecionado
    final dadosMesSelecionado = dadosMensais.firstWhere(
      (d) => d['mes_key'] == mesKey,
      orElse: () => {
        'mes': '$mesNome/$ano',
        'mes_key': mesKey,
        'divida_total': 0.0,
        'divida_paga': 0.0,
        'divida_restante': 0.0,
      },
    );

    final double dividaTotal = dadosMesSelecionado['divida_total'].toDouble();
    final double dividaPaga = dadosMesSelecionado['divida_paga'].toDouble();
    final double dividaRestante = dadosMesSelecionado['divida_restante'].toDouble();
    final String mesCompleto = dadosMesSelecionado['mes'].toString();

    // Se não houver dívidas no mês
    if (dividaTotal == 0 && dividaPaga == 0 && dividaRestante == 0) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.pie_chart,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Nenhuma dívida em $mesCompleto',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Use as setas para navegar entre os meses',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final Color corDividaTotal = const Color(0xFF3498DB);
    final Color corDividaPaga = const Color(0xFF2ECC71);
    final Color corDividaRestante = const Color(0xFFE74C3C);

    final total = dividaTotal;
    
    List<PieChartSectionData> sections = [];
    
    if (dividaPaga > 0) {
      final percentualPago = (dividaPaga / total) * 100;
      sections.add(
        PieChartSectionData(
          value: dividaPaga,
          color: corDividaPaga,
          radius: _touchedIndex == 0 ? 40 : 35,
          title: percentualPago >= 5 ? '${percentualPago.toStringAsFixed(1)}%' : '',
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          showTitle: percentualPago >= 5,
        ),
      );
    }

    if (dividaRestante > 0) {
      final percentualRestante = (dividaRestante / total) * 100;
      sections.add(
        PieChartSectionData(
          value: dividaRestante,
          color: corDividaRestante,
          radius: _touchedIndex == 1 ? 40 : 35,
          title: percentualRestante >= 5 ? '${percentualRestante.toStringAsFixed(1)}%' : '',
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          showTitle: percentualRestante >= 5,
        ),
      );
    }

    Widget _buildTextoCentroDividas() {
      String valor;
      String titulo;
      Color cor;
      
      if (_touchedIndex == null) {
        valor = 'R\$${dividaTotal.toStringAsFixed(2)}';
        titulo = 'Dívida Total';
        cor = corDividaTotal;
      } else if (_touchedIndex == 0) {
        valor = 'R\$${dividaPaga.toStringAsFixed(2)}';
        titulo = 'Pago';
        cor = corDividaPaga;
      } else if (_touchedIndex == 1) {
        valor = 'R\$${dividaRestante.toStringAsFixed(2)}';
        titulo = 'Restante';
        cor = corDividaRestante;
      } else {
        valor = 'R\$${dividaTotal.toStringAsFixed(2)}';
        titulo = 'Total';
        cor = corDividaTotal;
      }
      
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            mesCompleto,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabeçalho com navegação entre meses
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: _mesOffsetGrafico < 5 ? Colors.red : Colors.grey[400],
                ),
                onPressed: _mesOffsetGrafico < 5 
                    ? () {
                        setState(() {
                          _mesOffsetGrafico++;
                          _touchedIndex = null;
                        });
                      }
                    : null,
                tooltip: 'Mês anterior',
              ),
              
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Dívidas do Mês',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mesCompleto,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _mesOffsetGrafico == 0 
                          ? '(Mês Atual)'
                          : '(${_mesOffsetGrafico == 1 ? '1 mês atrás' : '$_mesOffsetGrafico meses atrás'})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: _mesOffsetGrafico > 0 ? Colors.red : Colors.grey[400],
                ),
                onPressed: _mesOffsetGrafico > 0
                    ? () {
                        setState(() {
                          _mesOffsetGrafico--;
                          _touchedIndex = null;
                        });
                      }
                    : null,
                tooltip: 'Próximo mês',
              ),
            ],
          ),
          
          const SizedBox(height: 15),
          
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    centerSpaceRadius: 60,
                    sectionsSpace: 2,
                    sections: sections,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          setState(() {
                            _touchedIndex = null;
                          });
                          return;
                        }
                        
                        setState(() {
                          _touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                ),
                _buildTextoCentroDividas(),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          Column(
            children: [
              Text(
                'Toque em uma fatia para ver detalhes',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 15,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: corDividaTotal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total: R\$${dividaTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: corDividaPaga,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pago: R\$${dividaPaga.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: corDividaRestante,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Restante: R\$${dividaRestante.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Use as setas para navegar entre os meses',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> carregarFuncionarios() async {
    try {
      final response = await supabase
          .from('users')
          .select('username, password, position')
          .order('username');

      funcionarios = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      funcionarios = [];
      debugPrint('Erro ao carregar funcionários: $e');
    }
  }

Future<void> atualizarFuncionariosRapido() async {
  setState(() => refreshingFuncionarios = true);
  
  // Mostrar loading (sem await!)
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.red,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Atualizando lista de funcionários...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  
  // Executar tarefa
  await carregarFuncionarios();
  
  // Fechar loading
  if (mounted && Navigator.canPop(context)) {
    Navigator.pop(context);
  }
  
  setState(() => refreshingFuncionarios = false);
  

}
  Future<void> salvarFuncionario() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final position = positionController.text.trim();

    if (username.isEmpty || password.isEmpty || position.isEmpty) {
      if (!mounted) return;
      await _mostrarPopUpErro(
        titulo: 'Campos Obrigatórios',
        mensagem: 'Por favor, preencha todos os campos antes de salvar.',
      );
      return;
    }

    if (position.toLowerCase() != 'gerente' && position.toLowerCase() != 'caixa') {
      if (!mounted) return;
      await _mostrarPopUpErro(
        titulo: 'Cargo Inválido',
        mensagem: 'O cargo deve ser "gerente" ou "caixa".',
      );
      return;
    }

    try {
      final data = {
        'username': username,
        'password': password,
        'position': position,
      };

      // Mostrar loading

      if (editarFuncionarioUsername == null) {
        await supabase.from('users').insert(data);
        
        // Fechar loading
        if (!mounted) return;
        await _mostrarPopUpSucesso(
          titulo: 'Funcionário Criado!',
          mensagem: 'O funcionário "$username" foi cadastrado com sucesso.',
          icone: Icons.person_add_alt_1,
          corIcone: Colors.green,
        );
      } else {
        await supabase
            .from('users')
            .update({
              'password': password,
              'position': position,
            })
            .eq('username', editarFuncionarioUsername!);

        // Fechar loading
        if (!mounted) return;
        await _mostrarPopUpSucesso(
          titulo: 'Funcionário Atualizado!',
          mensagem: 'As informações foram atualizadas com sucesso.',
          icone: Icons.edit,
          corIcone: Colors.blue,
        );
        editarFuncionarioUsername = null;
      }

      limparCamposFuncionario();
      await atualizarFuncionariosRapido();
    } catch (e) {
      // Fechar loading se estiver aberto
      if (!mounted) return;
      await _mostrarPopUpErro(
        titulo: 'Erro ao Salvar',
        mensagem: 'Não foi possível salvar as informações do funcionário.',
        detalhes: e.toString(),
      );
    }
  }

  void limparCamposFuncionario() {
    usernameController.clear();
    passwordController.clear();
    positionController.clear();
  }

  Future<void> deletarFuncionario(String username) async {
    try {
      await _mostrarPopUpConfirmacao(
        titulo: 'Excluir Funcionário',
        mensagem: 'Tem certeza que deseja excluir permanentemente o funcionário "$username"? Esta ação não pode ser desfeita.',
        textoConfirmar: 'Excluir',
        textoCancelar: 'Cancelar',
        corConfirmar: Colors.red,
        onConfirmar: () async {
          // Mostrar loading
          _mostrarPopUpLoading(mensagem: 'Excluindo funcionário...', podeFechar: false);
          
          await supabase.from('users').delete().eq('username', username);
          
          // Fechar loading
          if (mounted) Navigator.pop(context);
          
          await _mostrarPopUpSucesso(
            titulo: 'Funcionário Excluído!',
            mensagem: 'O funcionário "$username" foi removido do sistema.',
            icone: Icons.delete_forever,
            corIcone: Colors.orange,
          );
          
          await atualizarFuncionariosRapido();
        },
      );
    } catch (e) {
      // Fechar loading se estiver aberto
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      
      await _mostrarPopUpErro(
        titulo: 'Erro ao Excluir',
        mensagem: 'Não foi possível excluir o funcionário.',
        detalhes: e.toString(),
      );
    }
  }

  void abrirDialogCadastroFuncionario({Map<String, dynamic>? funcionario}) {
    if (funcionario != null) {
      usernameController.text = funcionario['username'];
      passwordController.text = funcionario['password'];
      positionController.text = funcionario['position'];
      editarFuncionarioUsername = funcionario['username'];
    } else {
      limparCamposFuncionario();
      editarFuncionarioUsername = null;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  funcionario == null ? Icons.person_add : Icons.edit,
                  size: 30,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                funcionario == null ? 'Novo Funcionário' : 'Editar Funcionário',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: usernameController,
                enabled: funcionario == null,
                decoration: InputDecoration(
                  labelText: 'Usuário',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: !(funcionario == null),
                  fillColor: funcionario == null ? null : Colors.grey[100],
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: positionController,
                decoration: InputDecoration(
                  labelText: 'Cargo (gerente / caixa)',
                  prefixIcon: const Icon(Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Digite "gerente" ou "caixa"',
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        salvarFuncionario();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Salvar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSairButton() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () async {
              final confirmar = await _mostrarPopUpConfirmacao(
                titulo: 'Sair do Sistema',
                mensagem: 'Tem certeza que deseja sair da sua conta?',
                textoConfirmar: 'Sair',
                textoCancelar: 'Cancelar',
                corConfirmar: Colors.red,
                onConfirmar: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('username');
                  await prefs.remove('password');
                  await supabase.auth.signOut();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const Login()),
                    );
                  }
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              shadowColor: Colors.red.withOpacity(0.3),
            ),
            child: const Text(
              'SAIR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _itemFuncionario(Map<String, dynamic> f) {
    Color getPositionColor(String position) {
      switch (position.toLowerCase()) {
        case 'gerente':
          return Colors.purple;
        case 'caixa':
          return Colors.teal;
        default:
          return Colors.blueGrey;
      }
    }

    final positionColor = getPositionColor(f['position']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: positionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: positionColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                f['position'].toString().toLowerCase() == 'gerente'
                    ? Icons.manage_accounts
                    : Icons.person,
                color: positionColor,
                size: 22,
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f['username'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 14,
                        color: positionColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        f['position'],
                        style: TextStyle(
                          fontSize: 14,
                          color: positionColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black.withOpacity(0.2)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    color: Colors.black,
                    onPressed: () => abrirDialogCadastroFuncionario(funcionario: f),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    color: Colors.red,
                    onPressed: () => deletarFuncionario(f['username']),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => abrirDialogCadastroFuncionario(),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : RefreshIndicator(
              color: Colors.red,
              onRefresh: carregarTudo,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildGraficoClientes(),
                    
                    const SizedBox(height: 20),
                    
                    _buildGraficoPizzaDividas(),
                    
                    const SizedBox(height: 20),
                    
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Expanded(
                            child: Divider(
                              color: Colors.red,
                              thickness: 2,
                              endIndent: 10,
                            ),
                          ),
                          Text(
                            "FUNCIONÁRIOS",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              color: Colors.red,
                              thickness: 2,
                              indent: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Total: ${funcionarios.length} funcionário(s)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    if (refreshingFuncionarios)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        ),
                      )
                    else if (funcionarios.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200!),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'Nenhum funcionário cadastrado',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Clique no botão + para adicionar',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: funcionarios
                            .map((f) => _itemFuncionario(f))
                            .cast<Widget>()
                            .toList(),
                      ),
                    
                    const SizedBox(height: 25),
                    _buildSairButton(),
                  ],
                ),
              ),
            ),

      bottomNavigationBar: ConvexAppBar(
        backgroundColor: Colors.red, 
        items: const [
          TabItem(icon: Icons.people, title: 'Clientes'),
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.attach_money, title: 'Dívidas'),
        ],
        initialActiveIndex: 1,
        onTap: (i) {
          if (i == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TelaClientes(users: widget.users),
              ),
            );
          } else if (i == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TelaDividas(users: widget.users),
              ),
            );
          }
        },
      ),
    );
  }
}