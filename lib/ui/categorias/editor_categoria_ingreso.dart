import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositorios/categoria_ingreso_repositorio.dart';
import '../../domain/modelos/categoria_ingreso.dart';
import '../comun/tema.dart';
import '../comun/hoja.dart';

/// Hoja para crear o editar una categoría de ingreso (spec §7.3.4): nombre
/// y emoji, sin presupuesto. Regresa la guardada, o `null` si se canceló.
Future<CategoriaIngreso?> mostrarEditorCategoriaIngreso(
  BuildContext context, {
  required CategoriaIngresoRepositorio repositorio,
  CategoriaIngreso? existente,
}) =>
    mostrarHoja<CategoriaIngreso>(
      context,
      builder: (_) => _EditorCategoriaIngreso(repositorio: repositorio, existente: existente),
    );

class _EditorCategoriaIngreso extends StatefulWidget {
  final CategoriaIngresoRepositorio repositorio;
  final CategoriaIngreso? existente;
  const _EditorCategoriaIngreso({required this.repositorio, this.existente});

  @override
  State<_EditorCategoriaIngreso> createState() => _EditorCategoriaIngresoState();
}

class _EditorCategoriaIngresoState extends State<_EditorCategoriaIngreso> {
  late final _nombre = TextEditingController(text: widget.existente?.nombre ?? '');
  late final _emoji = TextEditingController(text: widget.existente?.emoji ?? '💰');
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Ponle un nombre, por ejemplo "Nómina".');
      return;
    }
    setState(() => _guardando = true);
    final emoji = _emoji.text.trim().isEmpty ? '💰' : _emoji.text.trim();
    final categoria = widget.existente?.copyWith(nombre: nombre, emoji: emoji) ??
        CategoriaIngreso(id: const Uuid().v4(), nombre: nombre, emoji: emoji);
    await widget.repositorio.guardar(categoria);
    if (mounted) Navigator.of(context).pop(categoria);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existente == null ? 'Nueva categoría de ingreso' : 'Editar categoría de ingreso', style: textos.seccion),
          const SizedBox(height: 4),
          Text('De dónde te entra dinero: tu nómina, una renta, una inversión…', style: textos.etiqueta),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _emoji,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Ícono'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nombre,
                  autofocus: widget.existente == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Nombre', hintText: 'Nómina', errorText: _error),
                  onSubmitted: (_) => _guardar(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
