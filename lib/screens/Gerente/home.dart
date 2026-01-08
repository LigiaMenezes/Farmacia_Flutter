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

  int totalClientes = 0;
  int totalDividas = 0;
  double valorDividaTotal = 0.0;

  List<Map<String, dynamic>> funcionarios = [];
  bool loading = true;
  bool refreshingFuncionarios = false;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController positionController = TextEditingController();

  String? editarFuncionarioUsername;

  @override
  void initState() {
    super.initState();
    carregarTudo();
  }

  Future<void> carregarTudo() async {
    setState(() => loading = true);
    await Future.wait([carregarDados(), carregarFuncionarios()]);
    setState(() => loading = false);
  }

  Future<void> carregarDados() async {
    try {
      final clientes = await supabase.from('clients').select('cpf');
      totalClientes = clientes.length;

      final dividas = await supabase.from('debts').select('value');
      totalDividas = dividas.length;

      double soma = 0.0;
      for (var d in dividas) {
        final num? v = d['value'] is num ? d['value'] : num.tryParse('${d['value']}');
        if (v != null) soma += v.toDouble();
      }
      valorDividaTotal = soma;
    } catch (_) {}
  }

  Future<void> carregarFuncionarios() async {
    try {
      final response = await supabase
          .from('users')
          .select('username, password, position')
          .order('username');

      funcionarios = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      funcionarios = [];
    }
  }

  // Função para atualizar rapidamente apenas os funcionários
  Future<void> atualizarFuncionariosRapido() async {
    setState(() => refreshingFuncionarios = true);
    
    // Feedback visual com snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Atualizando lista de funcionários...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    await carregarFuncionarios();
    
    setState(() => refreshingFuncionarios = false);
    
    // Feedback de sucesso
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lista atualizada! ${funcionarios.length} funcionário(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> salvarFuncionario() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final position = positionController.text.trim();

    if (username.isEmpty || password.isEmpty || position.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Preencha todos os campos!')));
      return;
    }

    try {
      final data = {
        'username': username,
        'password': password,
        'position': position,
      };

      if (editarFuncionarioUsername == null) {
        await supabase.from('users').insert(data);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Funcionário "$username" criado!')));
      } else {
        await supabase
            .from('users')
            .update({
              'password': password,
              'position': position,
            })
            .eq('username', editarFuncionarioUsername!);

        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Funcionário atualizado!')));
        editarFuncionarioUsername = null;
      }

      limparCamposFuncionario();
      // Atualização rápida após salvar
      await atualizarFuncionariosRapido();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  void limparCamposFuncionario() {
    usernameController.clear();
    passwordController.clear();
    positionController.clear();
  }

  Future<void> deletarFuncionario(String username) async {
    try {
      await supabase.from('users').delete().eq('username', username);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Funcionário "$username" excluído!')),
      );
      // Atualização rápida após deletar
      await atualizarFuncionariosRapido();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
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
      builder: (_) => AlertDialog(
        title: Text(funcionario == null ? 'Novo Funcionário' : 'Editar Funcionário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              enabled: funcionario == null,
              decoration: const InputDecoration(labelText: 'Usuário'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            TextField(
              controller: positionController,
              decoration: const InputDecoration(labelText: 'Cargo (gerente / caixa)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                salvarFuncionario();
              },
              child: const Text('Salvar')),
        ],
      ),
    );
  }

  Widget _itemFuncionario(Map<String, dynamic> f) {
  // Definir cores com base no cargo
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
      border: Border.all(
        color: Colors.grey.shade200,
        width: 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Ícone do tipo de usuário
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
          
          // Informações do usuário e cargo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Usuário
                Text(
                  f['username'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Cargo
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
          
          // Botões de ação compactos
          Row(
            children: [
              // Botão Editar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    width: 1,
                  ),
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
              
              // Botão Excluir
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.red,
                  onPressed: () async {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Excluir Funcionário"),
                        content: Text('Tem certeza que deseja excluir "${f['username']}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancelar"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Excluir"),
                          ),
                        ],
                      ),
                    );
                    if (confirmar == true) {
                      deletarFuncionario(f['username']);
                    }
                  },
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
  // Widget para criar os containers como na imagem
  Widget _buildStatsContainer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Primeira linha: Clientes e Dívidas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                title: 'Clientes',
                value: totalClientes.toString().padLeft(3, '0'),
                icon: Icons.people,
                color: Colors.blue,
              ),
              _buildStatItem(
                title: 'Dívidas',
                value: totalDividas.toString().padLeft(3, '0'),
                icon: Icons.money_off,
                color: Colors.orange,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Segunda linha: Símbolo $ e Dívida Total
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green,
                    width: 2,
                  ),
                ),
                child: const Text(
                  '\$',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dívida Total:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'R\$${valorDividaTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Botão SAIR
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('username');
                await prefs.remove('password');
                supabase.auth.signOut().then((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Login()),
                  );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
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
        ],
      ),
    );
  }

  // Widget para cada item de estatística (Clientes e Dívidas)
  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para cabeçalho dos funcionários com botão de refresh

  int _navIndex = 1;

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
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: carregarTudo,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatsContainer(),
                  
                  const SizedBox(height: 20),
                  
                  // Título FUNCIONÁRIOS com linha azul
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
                            endIndent: 10, // Espaço à direita antes da linha
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
                            indent: 10, // Espaço à esquerda depois da linha
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  const SizedBox(height: 10),
                  
                  // Contador de funcionários
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
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (funcionarios.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
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
                      children: funcionarios.map((f) => _itemFuncionario(f)).toList(),
                    )
                ],
              ),
            ),
          ),

// No home.dart:
bottomNavigationBar: ConvexAppBar(
  backgroundColor: Colors.red, 
  items: const [
    TabItem(icon: Icons.people, title: 'Clientes'),
    TabItem(icon: Icons.home, title: 'Home'),
    TabItem(icon: Icons.attach_money, title: 'Dívidas'),
  ],
  initialActiveIndex: _navIndex,
  onTap: (i) {
    setState(() => _navIndex = i);
    
    if (i == 0) {
      // Navegar para Clientes usando a função redirect
      redirect(
        context,
        TelaClientes(users: widget.users),
      );
    } else if (i == 2) {
      // Navegar para Dívidas usando a função redirect
      redirect(
        context,
        TelaDividas(users: widget.users),
      );
    }
    // i == 1 (Home) não precisa navegar
  },
),
  );
}
}