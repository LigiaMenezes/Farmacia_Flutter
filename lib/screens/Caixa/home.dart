import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_farmacia/utils/utils.dart';
import 'package:flutter_farmacia/screens/login.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter_farmacia/screens/Caixa/TelaCliente.dart';
import 'package:flutter_farmacia/screens/Caixa/TelaDivida.dart';

class HomeCaixa extends StatefulWidget {
  final String users;

  const HomeCaixa({super.key, required this.users});

  @override
  State<HomeCaixa> createState() => _HomeCaixaState();
}

class _HomeCaixaState extends State<HomeCaixa> {
  final supabase = Supabase.instance.client;

  int totalClientes = 0;
  int totalDividas = 0;
  double valorDividaTotal = 0.0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    setState(() => loading = true);
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
    setState(() => loading = false);
  }

  // Função para atualizar rapidamente
  Future<void> atualizarDadosRapido() async {
    setState(() => loading = true);
    
    // Feedback visual com snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Atualizando dados...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    await carregarDados();
    
    setState(() => loading = false);
    
    // Feedback de sucesso
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dados atualizados!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
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

  // Widget para cabeçalho com botão de refresh
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Divider(
            color: Colors.blue,
            thickness: 2,
            endIndent: 10, // Espaço à direita da linha
          ),
        ),
        const Text(
          '  CAIXA   ',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.blue,
            thickness: 2,
            indent: 10, // Espaço à esquerda da linha
          ),
        ),
      ],
    );
  }


  // Widget para o botão SAIR na parte inferior
  Widget _buildSairButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
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
    );
  }

  int _navIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: carregarDados,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildHeader(),
                          
                          const SizedBox(height: 20),
                          
                          _buildStatsContainer(),
                        ],
                      ),
                    ),
                  ),
                  
                  // Botão SAIR fixo na parte inferior
                  _buildSairButton(),
                ],
              ),
            ),

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
              TelaClientesCaixa(users: widget.users),
            );
          } else if (i == 2) {
            // Navegar para Dívidas usando a função redirect
            redirect(
              context,
              TelaDividasCaixa(users: widget.users),
            );
          }
          // i == 1 (Home) não precisa navegar
        },
      ),
    );
  }
}