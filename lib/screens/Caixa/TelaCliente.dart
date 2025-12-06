import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_farmacia/utils/utils.dart';
import 'package:flutter_farmacia/screens/Caixa/home.dart';
import 'package:flutter_farmacia/screens/Caixa/TelaDivida.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class TelaClientesCaixa extends StatefulWidget {
  final String users;
  
  const TelaClientesCaixa({super.key, required this.users});
  
  @override
  State<TelaClientesCaixa> createState() => _TelaClientesState();
}

class _TelaClientesState extends State<TelaClientesCaixa> {
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
    }
    setState(() => loading = false);
  }

  Future<void> atualizarClientesRapido() async {
    setState(() => refreshingClientes = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Atualizando lista de clientes...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    await carregarClientes();
    
    setState(() => refreshingClientes = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lista atualizada! ${clientes.length} cliente(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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

  // Função para validar CPF
  bool _validarCPF(String cpf) {
    // Remove caracteres não numéricos
    cpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    
    // Verifica se tem 11 dígitos
    if (cpf.length != 11) return false;
    
    // Verifica se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1*$').hasMatch(cpf)) return false;
    
    // Algoritmo de validação do CPF
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

  // Função para validar telefone
  bool _validarTelefone(String telefone) {
    // Remove caracteres não numéricos
    telefone = telefone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Verifica se tem entre 10 e 11 dígitos (com DDD)
    return telefone.length >= 10 && telefone.length <= 11;
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

  // Máscara para telefone
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
    if (nome.isEmpty || cpf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nome e CPF são obrigatórios!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Remove máscara do CPF para validação
    cpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    
    if (!_validarCPF(cpf)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CPF inválido!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Valida telefone se preenchido
    if (telefone.isNotEmpty) {
      telefone = telefone.replaceAll(RegExp(r'[^\d]'), '');
      if (!_validarTelefone(telefone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Telefone inválido! Use o formato: (XX) XXXXX-XXXX'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      final data = {
        'name': nome,
        'cpf': cpf,
        'phone': telefone.isNotEmpty ? telefone : null,
        'endereco': endereco.isNotEmpty ? endereco : null,
        'encryption_key': 'default'
      };

      if (clienteParaEditar == null) {
        // Verificar se CPF já existe
        final clienteExistente = await supabase
            .from('clients')
            .select()
            .eq('cpf', cpf)
            .maybeSingle();
            
        if (clienteExistente != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CPF já cadastrado!'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await supabase.from('clients').insert(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente "$nome" cadastrado!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await supabase
            .from('clients')
            .update(data)
            .eq('cpf', clienteParaEditar!['cpf']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente atualizado!'),
            backgroundColor: Colors.green,
          ),
        );
        clienteParaEditar = null;
      }

      limparCamposCliente();
      await atualizarClientesRapido();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
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
                Text(
                  cliente == null ? 'Novo Cliente' : 'Editar Cliente',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
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
                  label: 'Telefone (opcional)',
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
                        salvarCliente();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
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
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
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
                  // Título com nome do cliente
                  Center(
                    child: Text(
                      cliente['name'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Informações básicas
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
                  
                  // Status da dívida
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
                  
                  // Total da dívida
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
                  
                  // Lista de dívidas detalhadas
                  if (dividas.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dívidas Detalhadas:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
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
                  
                  // Botões de ação
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Fecha o diálogo de detalhes
                          abrirDialogCadastroCliente(cliente: cliente);
                        },
                        icon: const Icon(Icons.edit, size: 20),
                        label: const Text("Editar"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
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
            // Informações do cliente (esquerda)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome
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
                  
                  // Status/Valor embaixo do nome
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
            
            // CPF e botões (direita)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // CPF em cima dos botões
                Text(
                  cpfFormatado,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Botões de ação
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: Colors.blue,
                        onPressed: () => abrirDialogCadastroCliente(cliente: cliente),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    

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

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => abrirDialogCadastroCliente(),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              
              // Campo de busca
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Pesquisar cliente por nome, CPF ou telefone...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              
              const SizedBox(height: 25),
              
              // Linha com título e botão de refresh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Divider(
                      color: Colors.blue,
                      thickness: 2,
                      endIndent: 10,
                    ),
                  ),
                  Column(
                    children: [
                      const Text(
                        "CLIENTES",
                        style: TextStyle(
                          color: Colors.blue,
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
                      color: Colors.blue,
                      thickness: 2,
                      indent: 10,
                    ),
                  ),
                  IconButton(
                    onPressed: refreshingClientes ? null : atualizarClientesRapido,
                    icon: refreshingClientes
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    color: Colors.blue,
                    tooltip: 'Atualizar lista',
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
            ],
          ),
        ),
      ),

      bottomNavigationBar: ConvexAppBar(
        items: const [
          TabItem(icon: Icons.people, title: 'Clientes'),
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.attach_money, title: 'Dívidas'),
        ],
        initialActiveIndex: 0, // Clientes ativo
        onTap: (i) {
          if (i == 1) {
            // Navegar para Home
            redirect(
              context,
              HomeCaixa(users: widget.users),
            );
          } else if (i == 2) {
            // Navegar para Dívidas
            redirect(
              context,
              TelaDividasCaixa(users: widget.users),
            );
          }
          // i == 0 (Clientes) já estamos aqui, não precisa navegar
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