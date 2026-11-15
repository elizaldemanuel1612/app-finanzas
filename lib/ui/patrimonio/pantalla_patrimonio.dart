import 'package:flutter/material.dart';

import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/categoria_ingreso_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/objetivo_repositorio.dart';
import '../../domain/modelos/perfil.dart';
import '../comun/avatar_ajustes.dart';
import '../cuentas/pantalla_cuentas.dart';
import '../objetivos/pantalla_objetivos.dart';

enum _Vista { cuentas, objetivos }

/// Pestaña Patrimonio (`docs/rediseno/plan-rediseno.md`, navegación nueva):
/// ¿cuánto tengo y cuánto debo? Control segmentado Cuentas | Objetivos.
/// Reemplaza la tarjeta de cuentas y el renglón de objetivos de Inicio, y
/// la vista "Cuentas" de Análisis.
class PantallaPatrimonio extends StatefulWidget {
  final Perfil perfil;
  final CuentaRepositorio cuentaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final MovimientoCuentaRepositorio movimientoCuentaRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;
  final ObjetivoRepositorio objetivoRepositorio;
  final CategoriaRepositorio categoriaRepositorio;

  /// Para el avatar del encabezado.
  final String? nombre;
  final VoidCallback alAbrirAjustes;

  /// Categorías de ingreso para los abonos (spec §7.3.4); sin él, el abono
  /// no pide categoría.
  final CategoriaIngresoRepositorio? categoriaIngresoRepositorio;

  const PantallaPatrimonio({
    super.key,
    required this.perfil,
    required this.cuentaRepositorio,
    required this.movimientoRepositorio,
    required this.movimientoCuentaRepositorio,
    required this.ingresoExtraRepositorio,
    required this.objetivoRepositorio,
    required this.categoriaRepositorio,
    required this.nombre,
    required this.alAbrirAjustes,
    this.categoriaIngresoRepositorio,
  });

  @override
  State<PantallaPatrimonio> createState() => _PantallaPatrimonioState();
}

class _PantallaPatrimonioState extends State<PantallaPatrimonio> {
  _Vista _vista = _Vista.cuentas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoRaiz(titulo: 'Patrimonio', nombre: widget.nombre, alAbrirAjustes: widget.alAbrirAjustes),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<_Vista>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Vista.cuentas, label: Text('Cuentas')),
                  ButtonSegment(value: _Vista.objetivos, label: Text('Objetivos')),
                ],
                selected: {_vista},
                onSelectionChanged: (s) => setState(() => _vista = s.first),
              ),
            ),
            Expanded(
              child: switch (_vista) {
                _Vista.cuentas => PantallaCuentas(
                    embebida: true,
                    perfil: widget.perfil,
                    cuentaRepositorio: widget.cuentaRepositorio,
                    movimientoRepositorio: widget.movimientoRepositorio,
                    movimientoCuentaRepositorio: widget.movimientoCuentaRepositorio,
                    ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
                    categoriaIngresoRepositorio: widget.categoriaIngresoRepositorio,
                  ),
                _Vista.objetivos => PantallaObjetivos(
                    embebida: true,
                    perfil: widget.perfil,
                    objetivoRepositorio: widget.objetivoRepositorio,
                    cuentaRepositorio: widget.cuentaRepositorio,
                    movimientoRepositorio: widget.movimientoRepositorio,
                    movimientoCuentaRepositorio: widget.movimientoCuentaRepositorio,
                    categoriaRepositorio: widget.categoriaRepositorio,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
