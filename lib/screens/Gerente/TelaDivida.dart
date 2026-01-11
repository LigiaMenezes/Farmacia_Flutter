import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_farmacia/utils/utils.dart';
import 'package:flutter_farmacia/screens/Gerente/home.dart';
import 'package:flutter_farmacia/screens/Gerente/TelaCliente.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class TelaDividas extends StatefulWidget {
  final String users;
  
  const TelaDividas({super.key, required this.users});
  
  @override
  State<TelaDividas> createState() => _TelaDividasState();
}

class _TelaDividasState extends State<TelaDividas> {
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
  
  String? clienteSelecionadoId;
  String? clienteSelecionadoNome;

  final TextEditingController pagamentoValorController = TextEditingController();
  final TextEditingController pagamentoDataController = TextEditingController();
  String? formaPagamentoSelecionada;
  List<String> formasPagamento = [
    'PIX',
    'Espécie',
    'Cartão',
    'Outros'
  ];
  Map<String, dynamic>? dividaSelecionadaParaPagamento;

  String ordenarPor = 'vencimento';
  bool ordenarAscendente = false;

  Map<String, dynamic>? dividaParaEditar;

  // ==================== MÉTODOS DE POP-UP ====================

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
                        carregarDividas(); // Tentar novamente
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
      
      if (clientes.isEmpty) {
        await carregarClientes();
      }
      
      for (var divida in dividas) {
        final nomeCliente = getNomeClientePorCpf(divida['cpf']);
        divida['cliente_nome'] = nomeCliente ?? 'Cliente sem nome';
        divida['esta_vencida'] = divida['end_date'] != null && 
            DateTime.parse(divida['end_date']).isBefore(DateTime.now());
      }

      aplicarOrdenacaoEAtualizarFiltradas();
    } catch (e) {
      dividas = [];
      filtradas = [];
      
      await _mostrarPopUpErro(
        titulo: 'Erro ao Carregar',
        mensagem: 'Não foi possível carregar a lista de dívidas.',
        detalhes: e.toString(),
      );
    }
    setState(() => loading = false);
  }

  void aplicarOrdenacaoEAtualizarFiltradas() {
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
    
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(30),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.red,
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Atualizando lista de dívidas...',
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
    
    await carregarDividas();
    
    // Fechar loading
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    setState(() => refreshingDividas = false);
    
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
    final dataInicioText = dataInicioController.text.trim();
    final dataVencimentoText = dataVencimentoController.text.trim();

    if (valorText.isEmpty  || clienteSelecionadoId == null || dataInicioText.isEmpty) {
      await _mostrarPopUpErro(
        titulo: 'Campos Obrigatórios',
        mensagem: 'Todos os campos marcados com * são obrigatórios.',
      );
      return;
    }

    final valor = double.tryParse(valorText.replaceAll(',', '.'));
    
    if (valor == null || valor <= 0) {
      await _mostrarPopUpErro(
        titulo: 'Valor Inválido',
        mensagem: 'Informe um valor válido para a dívida.',
      );
      return;
    }

    try {
      final data = {
        'cpf': clienteSelecionadoId,
        'value': valor,
        'init_date': dataInicioText,
        'end_date': dataVencimentoText.isNotEmpty ? dataVencimentoText : null,
      };

      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Colors.red,
                  strokeWidth: 3,
                ),
                SizedBox(height: 20),
                Text(
                  'Salvando dívida...',
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

      if (dividaParaEditar == null) {
        await supabase.from('debts').insert(data);
        
        // Fechar loading
        if (mounted) Navigator.pop(context);
        
        await _mostrarPopUpSucesso(
          titulo: 'Dívida Cadastrada!',
          mensagem: 'Dívida de R\$${valor.toStringAsFixed(2)} cadastrada com sucesso.',
          icone: Icons.attach_money,
          corIcone: Colors.green,
        );
      } else {
        data['init_date'] = dividaParaEditar!['init_date'];
        
        await supabase
            .from('debts')
            .update(data)
            .eq('id', dividaParaEditar!['id']);

        // Fechar loading
        if (mounted) Navigator.pop(context);
        
        await _mostrarPopUpSucesso(
          titulo: 'Dívida Atualizada!',
          mensagem: 'As informações foram atualizadas com sucesso.',
          icone: Icons.edit,
          corIcone: Colors.blue,
        );
        dividaParaEditar = null;
      }

      limparCamposDivida();
      await atualizarDividasRapido();
    } catch (e) {
      // Fechar loading se estiver aberto
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      
      await _mostrarPopUpErro(
        titulo: 'Erro ao Salvar',
        mensagem: 'Não foi possível salvar as informações da dívida.',
        detalhes: e.toString(),
      );
    }
  }

  void limparCamposDivida() {
    valorController.clear();
    dataInicioController.clear();
    dataVencimentoController.clear();
    dataInicio = null;
    dataVencimento = null;
    clienteSelecionadoId = null;
    clienteSelecionadoNome = null;
    dividaParaEditar = null;
  }

  Future<void> deletarDivida(int id, double valor, String clienteNome) async {
    await _mostrarPopUpConfirmacao(
      titulo: 'Excluir Dívida',
      mensagem: 'Tem certeza que deseja excluir permanentemente a dívida de $clienteNome no valor de R\$${valor.toStringAsFixed(2)}?\n\nEsta ação excluirá TODOS os pagamentos associados.',
      textoConfirmar: 'Excluir',
      textoCancelar: 'Cancelar',
      corConfirmar: Colors.red,
      onConfirmar: () async {
        // Mostrar loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(30),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.red,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Excluindo dívida...',
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
        
        try {
          await supabase.from('payments').delete().eq('debts_id', id);
          await supabase.from('debts').delete().eq('id', id);
          
          // Fechar loading
          if (mounted) Navigator.pop(context);
          
          await _mostrarPopUpSucesso(
            titulo: 'Dívida Excluída!',
            mensagem: 'Dívida de $clienteNome removida do sistema com sucesso.',
            icone: Icons.delete_forever,
            corIcone: Colors.orange,
          );
          
          await atualizarDividasRapido();
        } catch (e) {
          // Fechar loading se estiver aberto
          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
          
          await _mostrarPopUpErro(
            titulo: 'Erro ao Excluir',
            mensagem: 'Não foi possível excluir a dívida.',
            detalhes: e.toString(),
          );
        }
      },
    );
  }

Future<void> _selecionarData(BuildContext context, bool isInicio) async {
  final localizations = MaterialLocalizations.of(context);
  if (localizations == null) return;

  final DateTime? dataSelecionada = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    cancelText: 'Cancelar',
    confirmText: 'Confirmar',
    helpText: 'Selecione uma data',
    fieldHintText: 'DD/MM/AAAA',
    fieldLabelText: 'Data',
    builder: (context, child) {
      return Theme(
        data: Theme.of(context),
        child: child!,
      );
    },
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
  final locale = const Locale('pt', 'BR');
  
  final DateTime? dataSelecionada = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    locale: locale,
    cancelText: 'Cancelar',
    confirmText: 'Confirmar',
    helpText: 'Selecione a data do pagamento',
    fieldHintText: 'DD/MM/AAAA',
    fieldLabelText: 'Data do Pagamento',
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

  void abrirDialogCadastroDivida({Map<String, dynamic>? divida}) {
    if (divida != null) {
      valorController.text = divida['value'].toString();
      clienteSelecionadoId = divida['cpf'];
      clienteSelecionadoNome = getNomeClientePorCpf(divida['cpf']) ?? 'Cliente sem nome';
      dataInicioController.text = divida['init_date'];
      if (divida['end_date'] != null) {
        dataVencimentoController.text = divida['end_date'];
      }
      dividaParaEditar = divida;
    } else {
      limparCamposDivida();
      final now = DateTime.now();
      dataInicioController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

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
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      divida == null ? Icons.attach_money : Icons.edit,
                      size: 30,
                      color: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: Text(
                    divida == null ? 'Nova Dívida' : 'Editar Dívida',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 15),
                
                TextField(
                  controller: valorController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor da Dívida*',
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 15),
                
                TextField(
                  controller: dataInicioController,
                  readOnly: divida != null,
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: divida == null
                        ? IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: () => _selecionarData(context, true),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 15),
                
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () => _selecionarData(context, false),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
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
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          salvarDivida();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
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
                const SizedBox(height: 10),
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

  final now = DateTime.now();
  pagamentoDataController.text =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  pagamentoValorController.text = divida['value'].toString();

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
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
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.payments,
                          size: 30,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Center(
                      child: Text(
                        'Registrar Pagamento',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
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
                          const SizedBox(height: 8),
                          Text(
                            'Valor da Dívida: R\$ ${(divida['value']?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: pagamentoValorController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Valor do Pagamento*',
                        prefixIcon: const Icon(Icons.attach_money,
                            color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.green, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: pagamentoDataController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Data do Pagamento*',
                        prefixIcon: const Icon(Icons.calendar_today,
                            color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.green, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () =>
                              _selecionarDataPagamento(context),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: formaPagamentoSelecionada,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        hint: const Text(
                          'Selecione a Forma de Pagamento*',
                          style: TextStyle(color: Colors.grey),
                        ),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.green),
                        items: formasPagamento.map((forma) {
                          return DropdownMenuItem<String>(
                            value: forma,
                            child: Text(
                              forma,
                              style:
                                  const TextStyle(fontSize: 16),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setDialogState(() {
                            formaPagamentoSelecionada = newValue;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 25),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(context),
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
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        SizedBox(
                          width: 120,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              registrarPagamento();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Registrar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
  
  Future<void> registrarPagamento() async {
    if (dividaSelecionadaParaPagamento == null) return;
    
    final valorText = pagamentoValorController.text.trim();
    final dataText = pagamentoDataController.text.trim();
    
    if (valorText.isEmpty || dataText.isEmpty || formaPagamentoSelecionada == null) {
      await _mostrarPopUpErro(
        titulo: 'Campos Obrigatórios',
        mensagem: 'Preencha todos os campos para registrar o pagamento.',
      );
      return;
    }

    final valorPagamento = double.tryParse(valorText.replaceAll(',', '.'));
    final valorDivida = dividaSelecionadaParaPagamento!['value']?.toDouble() ?? 0.0;
    
    if (valorPagamento == null || valorPagamento <= 0) {
      await _mostrarPopUpErro(
        titulo: 'Valor Inválido',
        mensagem: 'Informe um valor válido para o pagamento.',
      );
      return;
    }

    if (valorPagamento > valorDivida) {
      await _mostrarPopUpErro(
        titulo: 'Valor Excede Dívida',
        mensagem: 'O valor do pagamento não pode ser maior que a dívida.',
      );
      return;
    }

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Colors.red,
                  strokeWidth: 3,
                ),
                SizedBox(height: 20),
                Text(
                  'Registrando pagamento...',
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
        
        // Fechar loading
        if (mounted) Navigator.pop(context);
        
        await _mostrarPopUpSucesso(
          titulo: 'Dívida Quitada!',
          mensagem: 'Pagamento de R\$${valorPagamento.toStringAsFixed(2)} registrado e dívida quitada com sucesso!',
          icone: Icons.check_circle_outline,
          corIcone: Colors.green,
        );
      } else {
        await supabase
            .from('debts')
            .update({'value': novoValorDivida})
            .eq('id', dividaSelecionadaParaPagamento!['id']);
        
        // Fechar loading
        if (mounted) Navigator.pop(context);
        
        await _mostrarPopUpSucesso(
          titulo: 'Pagamento Registrado!',
          mensagem: 'Pagamento de R\$${valorPagamento.toStringAsFixed(2)} registrado com sucesso!\n\nValor restante: R\$${novoValorDivida.toStringAsFixed(2)}',
          icone: Icons.payments,
          corIcone: Colors.green,
        );
      }
      
      await atualizarDividasRapido();
      
    } catch (e) {
      // Fechar loading se estiver aberto
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      
      await _mostrarPopUpErro(
        titulo: 'Erro ao Registrar',
        mensagem: 'Não foi possível registrar o pagamento.',
        detalhes: e.toString(),
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
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: vencida ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        vencida ? Icons.warning_amber : Icons.attach_money,
                        size: 40,
                        color: vencida ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  Center(
                    child: Text(
                      'Detalhes da Dívida',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cliente: ${divida['cliente_nome']}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
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
                          "Valor da Dívida: R\$ ${(divida['value']?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}",
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  
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
                        elevation: 2,
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
                  
                  const SizedBox(height: 15),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            abrirDialogCadastroDivida(divida: divida);
                          },
                          icon: const Icon(Icons.edit, size: 20),
                          label: const Text("Editar"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      SizedBox(
                        width: 120,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            deletarDivida(divida['id'], divida['value']?.toDouble() ?? 0.0, divida['cliente_nome']);
                          },
                          icon: const Icon(Icons.delete, size: 20),
                          label: const Text("Excluir"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
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
                
                const SizedBox(width: 8),
                
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    color: Colors.black,
                    onPressed: () => abrirDialogCadastroDivida(divida: divida),
                    padding: EdgeInsets.zero,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    color: Colors.red,
                    onPressed: () => deletarDivida(divida['id'], valor, divida['cliente_nome']),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          backgroundColor: Colors.black,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () => abrirDialogCadastroDivida(),
        ),
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

              const SizedBox(height: 35),
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
              TelaClientes(users: widget.users),
            );
          } else if (i == 1) {
            redirect(
              context,
              HomeGerente(users: widget.users),
            );
          }
        },
      ),
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