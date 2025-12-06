import 'package:flutter/material.dart';

class HomeCaixa extends StatelessWidget {
  final String users;

  const HomeCaixa({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Bem-vindo Caixa: ${users}"),
      ),
    );
  }
}
