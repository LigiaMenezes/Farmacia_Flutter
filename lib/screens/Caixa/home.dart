import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_farmacia/utils/utils.dart';
import 'package:flutter_farmacia/screens/login.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter_farmacia/screens/Caixa/TelaCliente.dart';
import 'package:flutter_farmacia/screens/Caixa/TelaDivida.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeCaixa extends StatefulWidget {
  final String users;

  const HomeCaixa({super.key, required this.users});

  @override
  State<HomeCaixa> createState() => _HomeCaixaState();
}

class _HomeCaixaState extends State<HomeCaixa> {
  final supabase = Supabase.instance.client;

  int clientesQuitados = 0;
  int clientesEndividados = 0;
  int totalClientes = 0;
  double valorDividaTotal = 0.0;

  bool loading = true;
  int _navIndex = 1;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    carregarDados();
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
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
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 2,
            color: Colors.red,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'CAIXA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  // Função para mostrar popup de confirmação
  Future<bool> _mostrarPopUpConfirmacao({
    required String titulo,
    required String mensagem,
    required String textoConfirmar,
    required String textoCancelar,
    required Color corConfirmar,
    required VoidCallback onConfirmar,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone de alerta
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: corConfirmar.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber,
                    size: 40,
                    color: corConfirmar,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Título
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 15),
                
                // Mensagem
                Text(
                  mensagem,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 30),
                
                // Botões
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botão Cancelar
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            textoCancelar,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 15),
                    
                    // Botão Confirmar
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                            onConfirmar();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: corConfirmar,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            textoConfirmar,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false;
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
        const SizedBox(height: 15),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                const SizedBox(height: 46),
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        _buildGraficoClientes(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                _buildSairButton(),
              ],
            ),
      bottomNavigationBar: ConvexAppBar(
        backgroundColor: Colors.red,
        activeColor: Colors.white,
        items: const [
          TabItem(icon: Icons.people, title: 'Clientes'),
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.attach_money, title: 'Dívidas'),
        ],
        initialActiveIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          if (i == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TelaClientesCaixa(users: widget.users),
              ),
            ).then((_) {
              carregarDados();
              setState(() => _navIndex = 1);
            });
          } else if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TelaDividasCaixa(users: widget.users),
              ),
            ).then((_) {
              carregarDados();
              setState(() => _navIndex = 1);
            });
          }
        },
      ),
    );
  }
}