import 'package:flutter/material.dart';

/// ---- FUNÇÃO DE NAVEGAÇÃO  ----
void redirect(BuildContext context, Widget tela) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => tela),
  );
}
/// ---- FUNÇÃO DE NAVEGAÇÃO COM REPLACEMENT (substitui tela atual) ----
void redirectReplace(BuildContext context, Widget tela) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => tela),
  );
}