import 'package:flutter/material.dart';
import 'package:flutter_farmacia/utils/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_farmacia/screens/Gerente/home.dart'; 
import 'package:flutter_farmacia/screens/Caixa/home.dart';
import 'package:shared_preferences/shared_preferences.dart';


class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {

  bool _senhaVisivel = false;

  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLogin();
    });
  }

  Future<void> _autoLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final username = prefs.getString('username');
    final password = prefs.getString('password');

    if (username == null || password == null) return;

    setState(() => isLoading = true);

    final user = await supabase
        .from('users')
        .select()
        .eq('username', username)
        .eq('password', password)
        .maybeSingle();

    setState(() => isLoading = false);

    if (user != null) {
      final position = user['position'];
      if (position == 'gerente' || position == 'admin' || position == 'Gerente') {
        redirect(context, HomeGerente(users: username));
      } else if (position == 'caixa') {
        redirect(context, HomeCaixa(users: username));
      }
    } else {
      prefs.remove('username');
      prefs.remove('password');
    }
  }

  final supabase = Supabase.instance.client;

  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  bool isLoading = false;

  Future<void> loginUsuario() async {
    final usuario = usuarioController.text.trim();
    final senha = senhaController.text.trim();

    if (usuario.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos!")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Consulta o usuário
      final response = await supabase
          .from('users')
          .select()
          .eq('username', usuario)
          .maybeSingle();

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usuário não encontrado.")),
        );
      } else if (response['password'] != senha) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Senha incorreta.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bem-vindo, ${response['username']}!")),
        );
        String username = response['username'];
        String position = response['position']; // gerente, caixa, etc.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', usuarioController.text);
        await prefs.setString('password', senhaController.text);

        if (position == "gerente" || position == "admin" || position == "Gerente") {
          redirect(context, HomeGerente(users: username));
        } else if (position == "caixa") {
          redirect(context, HomeCaixa(users: username));
        }

      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Login',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000000),
                ),
              ),

              const SizedBox(height: 20),

              // Campo usuário
              SizedBox(
                width: 300,
                child: TextField(
                  controller: usuarioController,
                  decoration: InputDecoration(
                    labelText: 'USUÁRIO',
                    labelStyle: const TextStyle(color: Color(0xFF000000)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF000000),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Campo senha
              SizedBox(
                width: 300,
                child: TextField(
                  controller: senhaController,
                  obscureText: !_senhaVisivel,
                  decoration: InputDecoration(
                    labelText: 'SENHA',
                    labelStyle: const TextStyle(color: Color(0xFF000000)),

                    suffixIcon: IconButton(
                      icon: Icon(
                        _senhaVisivel ? Icons.visibility : Icons.visibility_off,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _senhaVisivel = !_senhaVisivel;
                        });
                      },
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF000000),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botão login
              ElevatedButton(
                onPressed: isLoading ? null : loginUsuario,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000000),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ENTRAR', style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 202),
            ],
          ),
        ),
      ),
    );
  }
}