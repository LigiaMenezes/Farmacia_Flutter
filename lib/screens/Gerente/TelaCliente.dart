import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_farmacia/utils/utils.dart';
import 'package:flutter_farmacia/screens/Gerente/home.dart';
import 'package:flutter_farmacia/screens/Gerente/TelaDivida.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class TelaClientes extends StatefulWidget {
  final String users;
  
  const TelaClientes({super.key, required this.users});
  
  @override
  State<TelaClientes> createState() => _TelaClientesState();
}

class _TelaClientesState extends State<TelaClientes> {
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> clientes = [];
  List<Map<String, dynamic>> filtrados = [];
  TextEditingController searchController = TextEditingController();
  bool loading = true;
  bool refreshingClientes = false;
  Timer? _debounce;

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController cpfController = TextEditingController();
  final TextEditingController telefoneController = TextEditingController();
  final TextEditingController enderecoController = TextEditingController();

  Map<String, dynamic>? clienteParaEditar;
  
  static const List<String> dddsValidos = [
    '11','12','13','14','15','16','17','18','19',
    '21','22','24',
    '27','28',
    '31','32','33','34','35','37','38',
    '41','42','43','44','45','46',
    '47','48','49',
    '51','53','54','55',
    '61',
    '62','64',
    '63',
    '65','66',
    '67',
    '68',
    '69',
    '71','73','74','75','77',
    '79',
    '81','87',
    '82',
    '83',
    '84',
    '85','88',
    '86','89',
    '91','93','94',
    '92','97',
    '95',
    '96',
    '98','99',
  ];

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
                        carregarClientes(); // Tentar novamente
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
    return showDialog(
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

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    carregarClientes();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      filtrarClientes();
    });
  }

  Future<void> carregarClientes() async {
    setState(() => loading = true);
    try {
      final response = await supabase
          .from('clients')
          .select('*')
          .order('name');

      clientes = List<Map<String, dynamic>>.from(response);
      
      // Calcular dívida total para cada cliente
      for (var cliente in clientes) {
        final dividas = await supabase
            .from('debts')
            .select('value')
            .eq('cpf', cliente['cpf']);
        
        double totalDivida = 0.0;
        for (var d in dividas) {
          final num? v = d['value'] is num ? d['value'] : num.tryParse('${d['value']}');
          if (v != null) totalDivida += v.toDouble();
        }
        cliente['total_divida'] = totalDivida;
        
        // Carregar detalhes das dívidas
        final detalhesDividas = await supabase
            .from('debts')
            .select('*')
            .eq('cpf', cliente['cpf'])
            .order('init_date', ascending: false);
        
        cliente['detalhes_dividas'] = List<Map<String, dynamic>>.from(detalhesDividas);
      }

      filtrados = List.from(clientes);
    } catch (e) {
      print('Erro ao carregar clientes: $e');
      clientes = [];
      filtrados = [];
      if (!mounted) return;
      await _mostrarPopUpErro(
        titulo: 'Erro ao Carregar',
        mensagem: 'Não foi possível carregar a lista de clientes.',
        detalhes: e.toString(),
      );
    }
    setState(() => loading = false);
  }

  Future<void> atualizarClientesRapido() async {
    setState(() => refreshingClientes = true);
    
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

            ],
          ),
        ),
      ),
    );
    
    await carregarClientes();
    
    // Fechar loading
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    setState(() => refreshingClientes = false);
    
  }

  void filtrarClientes() {
    String query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filtrados = List.from(clientes);
      } else {
        filtrados = clientes.where((cliente) {
          return cliente['name'].toString().toLowerCase().contains(query) ||
                 cliente['cpf'].toString().contains(query) ||
                 cliente['phone'].toString().toLowerCase().contains(query) ||
                 (cliente['endereco']?.toString() ?? '').toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  bool _validarCPF(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cpf.length != 11) return false;
    
    if (RegExp(r'^(\d)\1*$').hasMatch(cpf)) return false;
    
    int soma = 0;
    for (int i = 0; i < 9; i++) {
      soma += int.parse(cpf[i]) * (10 - i);
    }
    int primeiroDigito = (soma * 10) % 11;
    if (primeiroDigito == 10) primeiroDigito = 0;
    
    if (primeiroDigito != int.parse(cpf[9])) return false;
    
    soma = 0;
    for (int i = 0; i < 10; i++) {
      soma += int.parse(cpf[i]) * (11 - i);
    }
    int segundoDigito = (soma * 10) % 11;
    if (segundoDigito == 10) segundoDigito = 0;
    
    return segundoDigito == int.parse(cpf[10]);
  }

  bool _validarTelefone(String telefone) {
    telefone = telefone.replaceAll(RegExp(r'[^\d]'), '');

    if (telefone.length != 10 && telefone.length != 11) return false;

    final String ddd = telefone.substring(0, 2);

    if (ddd == '00' || ddd == '01') return false;

    if (!dddsValidos.contains(ddd)) return false;

    if (RegExp(r'^(\d)\1+$').hasMatch(telefone)) return false;

    if (RegExp(r'0123456789|1234567890').hasMatch(telefone)) return false;

    if (RegExp(r'(.)\1{3,}').hasMatch(telefone.substring(2))) return false;

    if (telefone.length == 11 && telefone[2] != '9') return false;

    if (telefone.length == 10) {
      final String primeiroNumero = telefone[2];
      if (primeiroNumero == '0' || primeiroNumero == '1') return false;
    }

    return true;
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

  String _aplicarMascaraTelefone(String telefone) {
    telefone = telefone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (telefone.length == 10) {
      return '(${telefone.substring(0, 2)}) ${telefone.substring(2, 6)}-${telefone.substring(6)}';
    } else if (telefone.length == 11) {
      return '(${telefone.substring(0, 2)}) ${telefone.substring(2, 7)}-${telefone.substring(7)}';
    } else {
      return telefone;
    }
  }

  Future<void> salvarCliente() async {
    final nome = nomeController.text.trim();
    String cpf = cpfController.text.trim();
    String telefone = telefoneController.text.trim();
    final endereco = enderecoController.text.trim();

    // Validações
    if (nome.isEmpty || cpf.isEmpty || telefone.isEmpty) {
      if (!mounted) return;

      await _mostrarPopUpErro(
        titulo: 'Campos Obrigatórios',
        mensagem: 'Nome, CPF e Telefone são obrigatórios!',
      );
      return;
    }

    cpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    
    if (!_validarCPF(cpf)) {
      if (!mounted) return;

      await _mostrarPopUpErro(
        titulo: 'CPF Inválido',
        mensagem: 'Por favor, informe um CPF válido.',
      );
      return;
    }

    if (telefone.isEmpty) {
      if (!mounted) return;

      await _mostrarPopUpErro(
        titulo: 'Telefone Obrigatório',
        mensagem: 'O telefone é obrigatório para cadastro.',
      );
      return;
    }

    telefone = telefone.replaceAll(RegExp(r'[^\d]'), '');
    if (!_validarTelefone(telefone)) {
      if (!mounted) return;

      await _mostrarPopUpErro(
        titulo: 'Telefone Inválido',
        mensagem: 'Informe um telefone válido no formato: (XX) XXXXX-XXXX',
      );
      return;
    }

    try {
      final data = {
        'name': nome,
        'cpf': cpf,
        'phone': telefone,
        'endereco': endereco.isNotEmpty ? endereco : null,
      };


      if (clienteParaEditar == null) {
        // Verificar se CPF já existe
        final clienteExistente = await supabase
            .from('clients')
            .select()
            .eq('cpf', cpf)
            .maybeSingle();
            
        if (clienteExistente != null) {
          // Fechar loading
          if (!mounted) return;

          await _mostrarPopUpErro(
            titulo: 'CPF Já Cadastrado',
            mensagem: 'Este CPF já está cadastrado no sistema.',
          );
          return;
        }

        await supabase.from('clients').insert(data);
        
        // Fechar loading
        if (!mounted) return;

        await _mostrarPopUpSucesso(
          titulo: 'Cliente Cadastrado!',
          mensagem: 'Cliente "$nome" cadastrado com sucesso.',
          icone: Icons.person_add,
          corIcone: Colors.green,
        );
      } else {
        await supabase
            .from('clients')
            .update(data)
            .eq('cpf', clienteParaEditar!['cpf']);

        // Fechar loading
        if (!mounted) return;

        await _mostrarPopUpSucesso(
          titulo: 'Cliente Atualizado!',
          mensagem: 'As informações foram atualizadas com sucesso.',
          icone: Icons.edit,
          corIcone: Colors.blue,
        );
        clienteParaEditar = null;
      }

      limparCamposCliente();
      await atualizarClientesRapido();
    } catch (e) {
      // Fechar loading se estiver aberto
      if (!mounted) return;

      await _mostrarPopUpErro(
        titulo: 'Erro ao Salvar',
        mensagem: 'Não foi possível salvar as informações do cliente.',
        detalhes: e.toString(),
      );
    }
  }

  void limparCamposCliente() {
    nomeController.clear();
    cpfController.clear();
    telefoneController.clear();
    enderecoController.clear();
    clienteParaEditar = null;
  }

  Future<void> deletarCliente(String cpf, String nome) async {
    await _mostrarPopUpConfirmacao(
      titulo: 'Excluir Cliente',
      mensagem: 'Tem certeza que deseja excluir permanentemente o cliente "$nome"?\n\nEsta ação excluirá TODAS as dívidas e pagamentos associados.',
      textoConfirmar: 'Excluir',
      textoCancelar: 'Cancelar',
      corConfirmar: Colors.red,
      onConfirmar: () async {
        
        
        try {
          await supabase.from('payments').delete().eq('cpf', cpf);
          await supabase.from('debts').delete().eq('cpf', cpf);
          await supabase.from('clients').delete().eq('cpf', cpf);
          
          // Fechar loading
          if (!mounted) return;

          await _mostrarPopUpSucesso(
            titulo: 'Cliente Excluído!',
            mensagem: 'Cliente "$nome" removido do sistema com sucesso.',
            icone: Icons.delete_forever,
            corIcone: Colors.orange,
          );
          
          await atualizarClientesRapido();
        } catch (e) {
          // Fechar loading se estiver aberto
          if (!mounted) return;

          await _mostrarPopUpErro(
            titulo: 'Erro ao Excluir',
            mensagem: 'Não foi possível excluir o cliente.',
            detalhes: e.toString(),
          );
        }
      },
    );
  }

  void abrirDialogCadastroCliente({Map<String, dynamic>? cliente}) {
    if (cliente != null) {
      nomeController.text = cliente['name'];
      cpfController.text = _aplicarMascaraCPF(cliente['cpf']);
      telefoneController.text = cliente['phone'] != null 
          ? _aplicarMascaraTelefone(cliente['phone'])
          : '';
      enderecoController.text = cliente['endereco'] ?? '';
      clienteParaEditar = cliente;
    } else {
      limparCamposCliente();
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
                      color: Colors.black.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cliente == null ? Icons.person_add : Icons.edit,
                      size: 30,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: Text(
                    cliente == null ? 'Novo Cliente' : 'Editar Cliente',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextFieldDialog(
                  controller: nomeController,
                  label: 'Nome Completo*',
                  icon: Icons.person,
                ),
                const SizedBox(height: 15),
                _buildTextFieldDialog(
                  controller: cpfController,
                  label: 'CPF*',
                  icon: Icons.badge,
                  enabled: cliente == null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      
                      String text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
                      if (text.length > 11) text = text.substring(0, 11);
                      
                      String formatted = _aplicarMascaraCPF(text);
                      return TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 15),
                _buildTextFieldDialog(
                  controller: telefoneController,
                  label: 'Telefone*',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      
                      String text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
                      if (text.length > 11) text = text.substring(0, 11);
                      
                      String formatted = _aplicarMascaraTelefone(text);
                      return TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 15),
                _buildTextFieldDialog(
                  controller: enderecoController,
                  label: 'Endereço (opcional)',
                  icon: Icons.location_on,
                  maxLines: 3,
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
                          salvarCliente();
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

  Widget _buildTextFieldDialog({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black),
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
    );
  }

  void _mostrarDetalhesCliente(Map<String, dynamic> cliente) {
    final bool temDivida = (cliente['total_divida'] ?? 0.0) > 0;
    final List<Map<String, dynamic>> dividas = cliente['detalhes_dividas'] ?? [];
    
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
                        color: temDivida ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        temDivida ? Icons.warning_amber : Icons.check_circle,
                        size: 40,
                        color: temDivida ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  Center(
                    child: Text(
                      cliente['name'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _buildInfoItem('CPF', _aplicarMascaraCPF(cliente['cpf']), Icons.badge),
                  const SizedBox(height: 10),
                  
                  if (cliente['phone'] != null && cliente['phone'].toString().isNotEmpty)
                    Column(
                      children: [
                        _buildInfoItem('Telefone', _aplicarMascaraTelefone(cliente['phone'].toString()), Icons.phone),
                        const SizedBox(height: 10),
                      ],
                    ),
                  
                  if (cliente['endereco'] != null && cliente['endereco'].toString().isNotEmpty)
                    Column(
                      children: [
                        _buildInfoItem('Endereço', cliente['endereco'].toString(), Icons.location_on),
                        const SizedBox(height: 10),
                      ],
                    ),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: temDivida ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: temDivida ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          temDivida ? Icons.warning_amber : Icons.check_circle,
                          color: temDivida ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          temDivida ? 'EM DÉBITO' : 'SEM DÉBITO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: temDivida ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  Center(
                    child: Text(
                      'Dívida Total: R\$${(cliente['total_divida'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  if (dividas.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dívidas Detalhadas:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...dividas.map((divida) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'R\$${divida['value']?.toStringAsFixed(2) ?? '0.00'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    if (divida['end_date'] != null)
                                      Text(
                                        'Valor inicial:: ${divida['init_value']?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Início: ${divida['init_date']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                if (divida['end_date'] != null)
                                  Text(
                                    'Término: ${divida['end_date']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  
                  const SizedBox(height: 25),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: 120,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            abrirDialogCadastroCliente(cliente: cliente);
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
                      SizedBox(
                        width: 130,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await RelatorioExcelService.gerarRelatorioCliente(
                              cpf: cliente['cpf'],
                              nomeCliente: cliente['name'],
                              );
                          },
                          icon: const Icon(Icons.description, size: 20),
                          label: const Text("Relatório"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            deletarCliente(cliente['cpf'], cliente['name']);
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

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> cliente) {
    final bool temDivida = (cliente['total_divida'] ?? 0.0) > 0;
    final String cpfFormatado = _aplicarMascaraCPF(cliente['cpf']);
    
    return GestureDetector(
      onTap: () => _mostrarDetalhesCliente(cliente),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: temDivida ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: temDivida ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      temDivida ? 'R\$${(cliente['total_divida'] ?? 0.0).toStringAsFixed(2)}' : 'OK',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: temDivida ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  cpfFormatado,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
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
                        onPressed: () => abrirDialogCadastroCliente(cliente: cliente),
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
                        onPressed: () => deletarCliente(cliente['cpf'], cliente['name']),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
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
    int clientesComDivida = clientes.where((c) => (c['total_divida'] ?? 0.0) > 0).length;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          backgroundColor: Colors.black,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () => abrirDialogCadastroCliente(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar cliente por nome, CPF ou telefone...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 5),

                  IconButton(
                    onPressed: refreshingClientes ? null : atualizarClientesRapido,
                    iconSize: 32,
                    icon: refreshingClientes
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    color: Colors.red,
                    tooltip: 'Atualizar lista',
                  ),
                ],
              ),

              const SizedBox(height: 25),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Divider(
                      color: Colors.red,
                      thickness: 2,
                      endIndent: 10,
                    ),
                  ),
                  Column(
                    children: [
                      const Text(
                        "CLIENTES",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${clientes.length} cliente(s) | $clientesComDivida com dívida',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
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
              
              const SizedBox(height: 15),
              
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : refreshingClientes
                        ? const Center(child: CircularProgressIndicator())
                        : filtrados.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 80,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      searchController.text.isEmpty
                                          ? 'Nenhum cliente cadastrado'
                                          : 'Nenhum cliente encontrado',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      searchController.text.isEmpty
                                          ? 'Clique no botão + para adicionar um cliente'
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
                                onRefresh: carregarClientes,
                                child: ListView.builder(
                                  itemCount: filtrados.length,
                                  itemBuilder: (context, index) {
                                    return _buildClienteCard(filtrados[index]);
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
        initialActiveIndex: 0,
        onTap: (i) {
          if (i == 1) {
            redirect(
              context,
              HomeGerente(users: widget.users),
            );
          } else if (i == 2) {
            redirect(
              context,
              TelaDividas(users: widget.users),
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
    nomeController.dispose();
    cpfController.dispose();
    telefoneController.dispose();
    enderecoController.dispose();
    super.dispose();
  }
}