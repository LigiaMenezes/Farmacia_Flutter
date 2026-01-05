import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_farmacia/screens/Caixa/home.dart';
import 'package:flutter_farmacia/screens/Caixa/TelaCliente.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_farmacia/utils/utils.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class TelaDividasCaixa extends StatefulWidget {
  final String users;
  
  const TelaDividasCaixa({super.key, required this.users});
  
  @override
  State<TelaDividasCaixa> createState() => _TelaDividasCaixaState();
}

class _TelaDividasCaixaState extends State<TelaDividasCaixa> {
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> dividas = [];
  List<Map<String, dynamic>> filtradas = [];
  TextEditingController searchController = TextEditingController();
  bool loading = true;
  bool refreshingDividas = false;
  Timer? _debounce;

  final TextEditingController valorController = TextEditingController();
  final TextEditingController valorInicialController = TextEditingController();
  final TextEditingController dataInicioController = TextEditingController();
  final TextEditingController dataVencimentoController = TextEditingController();
  
  DateTime? dataInicio;
  DateTime? dataVencimento;
  List<Map<String, dynamic>> clientes = [];
  
  // Variável para armazenar o cliente selecionado no dropdown
  String? clienteSelecionadoId;
  String? clienteSelecionadoNome;

  // Controles para registrar pagamento
  final TextEditingController pagamentoValorController = TextEditingController();
  final TextEditingController pagamentoDataController = TextEditingController();
  String? formaPagamentoSelecionada;
  List<String> formasPagamento = [
    'Dinheiro',
    'Cartão de Crédito',
    'Cartão de Débito',
    'PIX',
    'Transferência Bancária',
    'Cheque'
  ];
  Map<String, dynamic>? dividaSelecionadaParaPagamento;

  String ordenarPor = 'vencimento'; // 'preco', 'vencimento', 'data_inicio'
  bool ordenarAscendente = false;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    carregarDividas();
    carregarClientes();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      filtrarDividas();
    });
  }

  Future<void> carregarClientes() async {
    try {
      final response = await supabase
          .from('clients')
          .select('cpf, name')
          .order('name');
      
      clientes = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erro ao carregar clientes: $e');
      clientes = [];
    }
  }

  String? getNomeClientePorCpf(String cpf) {
    for (var cliente in clientes) {
      if (cliente['cpf'] == cpf) {
        return cliente['name'];
      }
    }
    return 'Cliente sem nome';
  }

  Future<void> carregarDividas() async {
    setState(() => loading = true);
    try {
      final response = await supabase
          .from('debts')
          .select('*')
          .order('init_date', ascending: false);

      dividas = List<Map<String, dynamic>>.from(response);
      
      // Verificar se clientes já foram carregados, se não, carregar
      if (clientes.isEmpty) {
        await carregarClientes();
      }
      
      // Adicionar nome do cliente a cada dívida
      for (var divida in dividas) {
        final nomeCliente = getNomeClientePorCpf(divida['cpf']);
        divida['cliente_nome'] = nomeCliente ?? 'Cliente sem nome';
        // Adicionar flag para verificar se está vencida
        divida['esta_vencida'] = divida['end_date'] != null && 
            DateTime.parse(divida['end_date']).isBefore(DateTime.now());
      }

      // Ordenar as dívidas conforme especificação
      aplicarOrdenacaoEAtualizarFiltradas();
    } catch (e) {
      print('Erro ao carregar dívidas: $e');
      dividas = [];
      filtradas = [];
    }
    setState(() => loading = false);
  }

  void aplicarOrdenacaoEAtualizarFiltradas() {
    // Criar cópia para ordenar
    List<Map<String, dynamic>> listaParaOrdenar = List.from(dividas);
    
    listaParaOrdenar.sort((a, b) {
      int comparacao = 0;
      
      switch (ordenarPor) {
        case 'preco':
          final valorA = a['value']?.toDouble() ?? 0.0;
          final valorB = b['value']?.toDouble() ?? 0.0;
          comparacao = valorB.compareTo(valorA);
          break;
          
        case 'vencimento':
          final bool vencidaA = a['esta_vencida'] ?? false;
          final bool vencidaB = b['esta_vencida'] ?? false;
          
          if (vencidaA && !vencidaB) {
            comparacao = -1;
          } else if (!vencidaA && vencidaB) {
            comparacao = 1;
          } else {
            final vencA = a['end_date'] ?? '';
            final vencB = b['end_date'] ?? '';
            
            if (vencidaA && vencidaB) {
              comparacao = vencA.compareTo(vencB);
            } else if (!vencidaA && !vencidaB) {
              comparacao = vencA.compareTo(vencB);
            } else {
              if (vencA.isEmpty && vencB.isNotEmpty) return 1;
              if (vencA.isNotEmpty && vencB.isEmpty) return -1;
            }
          }
          break;
          
        case 'data_inicio':
        default:
          final inicioA = a['init_date'] ?? '';
          final inicioB = b['init_date'] ?? '';
          comparacao = inicioA.compareTo(inicioB);
          break;
      }
      
      return ordenarAscendente ? -comparacao : comparacao;
    });
    
    setState(() {
      dividas = listaParaOrdenar;
      aplicarFiltroBusca();
    });
  }

  void ordenar(String tipo) {
    if (ordenarPor == tipo) {
      ordenarAscendente = !ordenarAscendente;
    } else {
      ordenarPor = tipo;
      
      switch (tipo) {
        case 'preco':
          ordenarAscendente = false;
          break;
        case 'vencimento':
          ordenarAscendente = false;
          break;
        case 'data_inicio':
          ordenarAscendente = true;
          break;
      }
    }
    
    aplicarOrdenacaoEAtualizarFiltradas();
  }

  void ordenarPorPreco() => ordenar('preco');
  void ordenarPorVencimento() => ordenar('vencimento');
  void ordenarPorDataInicial() => ordenar('data_inicio');

  Future<void> atualizarDividasRapido() async {
    setState(() => refreshingDividas = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Atualizando lista de dívidas...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    await carregarDividas();
    
    setState(() => refreshingDividas = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lista atualizada! ${dividas.length} dívida(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void aplicarFiltroBusca() {
    String query = searchController.text.toLowerCase();
    
    if (query.isEmpty) {
      filtradas = List.from(dividas);
    } else {
      filtradas = dividas.where((divida) {
        return divida['cliente_nome'].toString().toLowerCase().contains(query) ||
               divida['cpf'].toString().contains(query) ||
               divida['value'].toString().contains(query) ||
               (divida['end_date'] != null && divida['end_date'].toString().contains(query));
      }).toList();
    }
  }

  void filtrarDividas() {
    setState(() {
      aplicarFiltroBusca();
    });
  }

  // Máscara para CPF
  String _aplicarMascaraCPF(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cpf.length <= 3) {
      return cpf;
    } else if (cpf.length <= 6) {
      return '${cpf.substring(0, 3)}.${cpf.substring(3)}';
    } else if (cpf.length <= 9) {
      return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6)}';
    } else {
      return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9, 11)}';
    }
  }

  Future<void> salvarDivida() async {
    final valorText = valorController.text.trim();
    final valorInicialText = valorInicialController.text.trim();
    final dataInicioText = dataInicioController.text.trim();
    final dataVencimentoText = dataVencimentoController.text.trim();

    if (valorText.isEmpty || valorInicialText.isEmpty || clienteSelecionadoId == null || dataInicioText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os campos são obrigatórios!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final valor = double.tryParse(valorText.replaceAll(',', '.'));
    final valorInicial = double.tryParse(valorInicialText.replaceAll(',', '.'));
    
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valor atual inválido!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (valorInicial == null || valorInicial <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valor inicial inválido!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final data = {
        'cpf': clienteSelecionadoId,
        'init_value': valorInicial,
        'value': valor,
        'init_date': dataInicioText,
        'end_date': dataVencimentoText.isNotEmpty ? dataVencimentoText : null,
      };

      await supabase.from('debts').insert(data);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dívida de R\$${valor.toStringAsFixed(2)} cadastrada!'),
          backgroundColor: Colors.green,
        ),
      );

      limparCamposDivida();
      await atualizarDividasRapido();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void limparCamposDivida() {
    valorController.clear();
    valorInicialController.clear();
    dataInicioController.clear();
    dataVencimentoController.clear();
    dataInicio = null;
    dataVencimento = null;
    clienteSelecionadoId = null;
    clienteSelecionadoNome = null;
  }

  Future<void> _selecionarData(BuildContext context, bool isInicio) async {
    final DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (dataSelecionada != null) {
      final String ano = dataSelecionada.year.toString();
      final String mes = dataSelecionada.month.toString().padLeft(2, '0');
      final String dia = dataSelecionada.day.toString().padLeft(2, '0');
      final String formatada = '$ano-$mes-$dia';
      
      if (isInicio) {
        dataInicio = dataSelecionada;
        dataInicioController.text = formatada;
      } else {
        dataVencimento = dataSelecionada;
        dataVencimentoController.text = formatada;
      }
    }
  }

  Future<void> _selecionarDataPagamento(BuildContext context) async {
    final DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (dataSelecionada != null) {
      final String ano = dataSelecionada.year.toString();
      final String mes = dataSelecionada.month.toString().padLeft(2, '0');
      final String dia = dataSelecionada.day.toString().padLeft(2, '0');
      pagamentoDataController.text = '$ano-$mes-$dia';
    }
  }

  Widget _ordenarBotao(String texto, String tipo, IconData icon, Color corAtivo) {
    final bool ativo = ordenarPor == tipo;
    final bool ascendente = ordenarAscendente;
    
    return GestureDetector(
      onTap: () {
        if (tipo == 'preco') {
          ordenarPorPreco();
        } else if (tipo == 'vencimento') {
          ordenarPorVencimento();
        } else {
          ordenarPorDataInicial();
        }
      },
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: ativo ? corAtivo : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ativo ? corAtivo : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: ativo ? Colors.white : corAtivo,
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ativo ? Colors.white : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (ativo)
              Icon(
                ascendente ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  void abrirDialogCadastroDivida() {
    limparCamposDivida();
    // Definir data atual como padrão para nova dívida
    final now = DateTime.now();
    dataInicioController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nova Dívida',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }

                    return clientes.where((cliente) {
                      final nome = cliente['name'].toString().toLowerCase();
                      return nome.contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  displayStringForOption: (cliente) =>
                      '${cliente['name']} (${_aplicarMascaraCPF(cliente['cpf'])})',
                  onSelected: (cliente) {
                    setState(() {
                      clienteSelecionadoId = cliente['cpf'];
                      clienteSelecionadoNome = cliente['name'];
                    });
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Cliente*',
                        hintText: 'Digite o nome do cliente',
                        prefixIcon: const Icon(Icons.person_search, color: Colors.black),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 15),
                
                // Valor Inicial
                TextField(
                  controller: valorInicialController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor Inicial*',
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                
                // Valor Atual
                TextField(
                  controller: valorController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor Atual*',
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                
                // Data de Início
                TextField(
                  controller: dataInicioController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Data de Início*',
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () => _selecionarData(context, true),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                
                // Data de Vencimento (opcional)
                TextField(
                  controller: dataVencimentoController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Data de Vencimento (opcional)',
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () => _selecionarData(context, false),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        salvarDivida();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void abrirDialogRegistrarPagamento(Map<String, dynamic> divida) {
    dividaSelecionadaParaPagamento = divida;
    pagamentoValorController.clear();
    pagamentoDataController.clear();
    formaPagamentoSelecionada = null;
    
    // Definir data atual como padrão
    final now = DateTime.now();
    pagamentoDataController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    // Definir valor máximo como o valor atual da dívida
    pagamentoValorController.text = divida['value'].toString();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registrar Pagamento',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                
                // Informações da dívida
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente: ${divida['cliente_nome']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Valor da Dívida: R\$ ${(divida['value']?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Valor do Pagamento
                TextField(
                  controller: pagamentoValorController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor do Pagamento*',
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                
                // Data do Pagamento
                TextField(
                  controller: pagamentoDataController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Data do Pagamento*',
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () => _selecionarDataPagamento(context),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                
                // Forma de Pagamento
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: formaPagamentoSelecionada,
                      isExpanded: true,
                      hint: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text('Selecione a Forma de Pagamento*', style: TextStyle(color: Colors.grey)),
                      ),
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.arrow_drop_down, color: Colors.green),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Text('Selecione a Forma de Pagamento*', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        ...formasPagamento.map((forma) {
                          return DropdownMenuItem<String>(
                            value: forma,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                forma,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          formaPagamentoSelecionada = newValue;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        registrarPagamento();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Registrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> registrarPagamento() async {
    if (dividaSelecionadaParaPagamento == null) return;
    
    final valorText = pagamentoValorController.text.trim();
    final dataText = pagamentoDataController.text.trim();
    
    if (valorText.isEmpty || dataText.isEmpty || formaPagamentoSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os campos são obrigatórios!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final valorPagamento = double.tryParse(valorText.replaceAll(',', '.'));
    final valorDivida = dividaSelecionadaParaPagamento!['value']?.toDouble() ?? 0.0;
    
    if (valorPagamento == null || valorPagamento <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valor do pagamento inválido!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (valorPagamento > valorDivida) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Valor do pagamento (R\$${valorPagamento.toStringAsFixed(2)}) não pode ser maior que a dívida (R\$${valorDivida.toStringAsFixed(2)})'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final novoPagamento = {
        'cpf': dividaSelecionadaParaPagamento!['cpf'],
        'debts_id': dividaSelecionadaParaPagamento!['id'],
        'value': valorPagamento,
        'date': dataText,
        'method': formaPagamentoSelecionada,
        'type': 'pagamento',
      };
      
      await supabase.from('payments').insert(novoPagamento);
      
      final novoValorDivida = valorDivida - valorPagamento;
      
      if (novoValorDivida <= 0) {
        await supabase.from('debts').delete().eq('id', dividaSelecionadaParaPagamento!['id']);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pagamento de R\$${valorPagamento.toStringAsFixed(2)} registrado! Dívida quitada e removida do sistema.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        await supabase
            .from('debts')
            .update({'value': novoValorDivida})
            .eq('id', dividaSelecionadaParaPagamento!['id']);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pagamento de R\$${valorPagamento.toStringAsFixed(2)} registrado com sucesso! Valor restante: R\$${novoValorDivida.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      await atualizarDividasRapido();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao registrar pagamento: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _mostrarDetalhesDivida(Map<String, dynamic> divida) {
    final bool temVencimento = divida['end_date'] != null;
    final bool vencida = divida['esta_vencida'] ?? false;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Detalhes da Dívida',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    "Cliente: ${divida['cliente_nome']}",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Text(
                    "Data de Início: ${divida['init_date']}",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Text(
                    "Data de Vencimento: ${temVencimento ? divida['end_date'] : 'Não definida'}",
                    style: TextStyle(
                      fontSize: 16,
                      color: vencida ? Colors.red : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Text(
                    "Valor Inicial: R\$ ${(divida['init_value']?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Text(
                    "Valor Atual: R\$ ${(divida['value']?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  
                  // Botão Registrar Pagamento
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        abrirDialogRegistrarPagamento(divida);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "REGISTRAR PAGAMENTO",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDividaCard(Map<String, dynamic> divida) {
    final bool temVencimento = divida['end_date'] != null;
    final bool vencida = divida['esta_vencida'] ?? false;
    final String cpfFormatado = _aplicarMascaraCPF(divida['cpf']);
    final double valor = divida['value']?.toDouble() ?? 0.0;
    
    // Formatar data no formato brasileiro (DD/MM/YYYY)
    String formatarData(String data) {
      if (data.isEmpty) return data;
      try {
        final parts = data.split('-');
        if (parts.length == 3) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
        return data;
      } catch (e) {
        return data;
      }
    }
    
    return GestureDetector(
      onTap: () => _mostrarDetalhesDivida(divida),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha 1: Nome do Cliente e CPF
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    divida['cliente_nome'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Text(
                  cpfFormatado,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Linha 2: Valor e Data de Vencimento
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (temVencimento)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: vencida ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: vencida ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      "Vcto: ${formatarData(divida['end_date'])}",
                      style: TextStyle(
                        fontSize: 12,
                        color: vencida ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Linha 3: Botão de Pagamento APENAS
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.payments, size: 18),
                    color: Colors.green,
                    onPressed: () => abrirDialogRegistrarPagamento(divida),
                    padding: EdgeInsets.zero,
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
    double valorTotal = dividas.fold(0.0, (sum, d) => sum + (d['value']?.toDouble() ?? 0.0));
    int dividasVencidas = dividas.where((d) => d['esta_vencida'] ?? false).length;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => abrirDialogCadastroDivida(),
      ),


      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Pesquisar cliente, CPF ou valor...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "ORDENAR POR ${ordenarPor == 'preco' ? 'VALOR' : ordenarPor == 'vencimento' ? 'VENCIMENTO' : 'DATA INICIAL'} ${ordenarAscendente ? '↑' : '↓'}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ordenarBotao("VALOR", 'preco', Icons.attach_money, Colors.red),
                    _ordenarBotao("VENCIMENTO", 'vencimento', Icons.calendar_today, Colors.green),
                    _ordenarBotao("DATA INICIAL", 'data_inicio', Icons.calendar_month, Colors.black),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                
              ),
              
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade400,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      "DÍVIDAS (${filtradas.length})",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade400,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              Expanded(
                child: loading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 15),
                            Text(
                              'Carregando dívidas...',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : refreshingDividas
                        ? const Center(child: CircularProgressIndicator(color: Colors.black))
                        : filtradas.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.money_off,
                                      size: 80,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      searchController.text.isEmpty
                                          ? 'Nenhuma dívida cadastrada'
                                          : 'Nenhuma dívida encontrada',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      searchController.text.isEmpty
                                          ? 'Clique no botão + para adicionar uma dívida'
                                          : 'Tente uma busca diferente',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                color: Colors.black,
                                onRefresh: carregarDividas,
                                child: ListView.builder(
                                  itemCount: filtradas.length,
                                  padding: const EdgeInsets.only(bottom: 20),
                                  itemBuilder: (context, index) {
                                    return _buildDividaCard(filtradas[index]);
                                  },
                                ),
                              ),
              ),
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
        initialActiveIndex: 2,
        onTap: (i) {
          if (i == 0) {
            redirect(
              context,
              TelaClientesCaixa(users: widget.users),
            );
          } else if (i == 1) {
            redirect(
              context,
              HomeCaixa(users: widget.users),
            );
          }
        },
      ),
    );
  }

  Widget _buildResumoItem(String titulo, String valor, IconData icon, Color cor) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: cor.withOpacity(0.3), width: 2),
          ),
          child: Icon(
            icon,
            color: cor,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    valorController.dispose();
    valorInicialController.dispose();
    dataInicioController.dispose();
    dataVencimentoController.dispose();
    pagamentoValorController.dispose();
    pagamentoDataController.dispose();
    super.dispose();
  }
}