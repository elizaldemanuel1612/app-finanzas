import 'package:flutter/material.dart';

import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/objetivo_repositorio.dart';
import '../../domain/cuentas/saldos.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/objetivo.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/objetivos/progreso_objetivos.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../analisis/graficas_analisis.dart';
import '../comun/tema.dart';
import 'pantalla_editar_objetivo.dart';

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// "3 ciclos", "1 ciclo".
String _ciclos(int n) => '$n ${n == 1 ? 'ciclo' : 'ciclos'}';

/// Qué significa el avance para el usuario, en una frase (regla #23).
String fraseDeObjetivo(ProgresoObjetivo p) {
  final alRitmo = p.ciclosAlRitmoActual;
  switch (p.estado) {
    case EstadoObjetivo.logrado:
      return '¡Lo lograste! Ya está completo.';
    case EstadoObjetivo.vencido:
      return 'La fecha ya pasó y faltan ${p.falta.formateado()}. Ponle una fecha nueva.';
    case EstadoObjetivo.sinFecha:
      return alRitmo == null
          ? 'Faltan ${p.falta.formateado()}.'
          : 'Faltan ${p.falta.formateado()}: con lo que apartas por ciclo llegarías en ${_ciclos(alRitmo)}.';
    case EstadoObjetivo.enCamino:
      final fecha = p.objetivo.fechaLimite!;
      final base = 'Para ${_meses[fecha.month - 1]} ${fecha.year}: aparta ${p.porCiclo!.formateado()} por ciclo '
          '(${p.ciclosRestantes == 1 ? 'queda' : 'quedan'} ${_ciclos(p.ciclosRestantes!)}).';
      return switch (p.alcanzaATiempo) {
        null => base,
        true => '$base Con lo que apartas hoy, llegas a tiempo.',
        false => '$base Con lo que apartas hoy llegarías en ${_ciclos(alRitmo!)}.',
      };
  }
}

/// Objetivos de ahorro (spec-app-finanzas-v2.md §7.3.3): para qué se
/// ahorra, cuánto va y qué falta. El cálculo vive en
/// `domain/objetivos/progreso_objetivos.dart`.
class PantallaObjetivos extends StatefulWidget {
  final Perfil perfil;
  final ObjetivoRepositorio objetivoRepositorio;
  final CuentaRepositorio cuentaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final MovimientoCuentaRepositorio movimientoCuentaRepositorio;

  /// Para saber lo que se aparta por ciclo (la meta de siempre, sin
  /// extras) y estimar cuándo se llega.
  final CategoriaRepositorio categoriaRepositorio;

  const PantallaObjetivos({
    super.key,
    required this.perfil,
    required this.objetivoRepositorio,
    required this.cuentaRepositorio,
    required this.movimientoRepositorio,
    required this.movimientoCuentaRepositorio,
    required this.categoriaRepositorio,
  });

  @override
  State<PantallaObjetivos> createState() => _PantallaObjetivosState();
}

class _PantallaObjetivosState extends State<PantallaObjetivos> {
  List<ProgresoObjetivo>? _progreso;
  List<Objetivo> _archivados = const [];
  Map<String, Cuenta> _cuentas = const {};
  bool _verArchivados = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final objetivos = await widget.objetivoRepositorio.listarTodos();
    final cuentas = await widget.cuentaRepositorio.listarTodas();
    final gastos = await widget.movimientoRepositorio.listarTodos();
    final abonos = await widget.movimientoCuentaRepositorio.listarTodos();
    final categorias = await widget.categoriaRepositorio.listarTodas();
    final progreso = calcularProgresoObjetivos(
      objetivos: objetivos,
      saldoPorCuenta: {
        for (final c in cuentas)
          if (c.tipo == TipoCuenta.ahorro) c.id: ?saldoDe(c, gastos, abonos),
      },
      hoy: DateTime.now(),
      calculadora: widget.perfil.calculadoraCiclo,
      apartadoPorCiclo: calcularMetaBase(
        perfil: widget.perfil,
        categorias: [for (final c in categorias) if (c.activa) c],
      ),
    );
    if (!mounted) return;
    setState(() {
      _progreso = progreso;
      _archivados = [for (final o in objetivos) if (!o.activo) o];
      _cuentas = {for (final c in cuentas) c.id: c};
    });
  }

  Future<void> _editar([Objetivo? objetivo]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaEditarObjetivo(
          objetivoRepositorio: widget.objetivoRepositorio,
          cuentaRepositorio: widget.cuentaRepositorio,
          existente: objetivo,
        ),
      ),
    );
    if (guardado == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final progreso = _progreso;
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Objetivos de ahorro')),
      floatingActionButton: FloatingActionButton(
        onPressed: _editar,
        tooltip: 'Nuevo objetivo',
        child: const Icon(Icons.add),
      ),
      body: progreso == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (progreso.isEmpty) ...[
                  const SizedBox(height: 40),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(color: ColoresApp.oroSuave, shape: BoxShape.circle),
                      child: Icon(Icons.flag_outlined, size: 40, color: ColoresApp.oroTexto),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('¿Para qué estás ahorrando?', textAlign: TextAlign.center, style: textos.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Ponle nombre y monto a lo que quieres lograr: un fondo de emergencia, un viaje, el enganche. '
                    'Verás cuánto llevas y cuánto apartar por ciclo para llegar.',
                    textAlign: TextAlign.center,
                    style: textos.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(onPressed: _editar, child: const Text('Crear mi primer objetivo')),
                  ),
                ] else ...[
                  Text(
                    'El avance de cada objetivo es lo que hay en su cuenta de ahorro. Para sumarle, aporta a esa cuenta.',
                    style: textos.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final p in progreso)
                    _TarjetaObjetivo(
                      progreso: p,
                      cuenta: _cuentas[p.objetivo.cuentaId],
                      alTocar: () => _editar(p.objetivo),
                    ),
                ],
                if (_archivados.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => setState(() => _verArchivados = !_verArchivados),
                    child: Text('${_verArchivados ? 'Ocultar' : 'Ver'} archivados (${_archivados.length})'),
                  ),
                  if (_verArchivados)
                    for (final o in _archivados)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _editar(o),
                          leading: ExcludeSemantics(child: Text(o.emoji, style: textos.titleMedium)),
                          title: Text(o.nombre),
                          subtitle: Text(o.monto.formateado()),
                          trailing: Icon(Icons.chevron_right, color: ColoresApp.medio),
                        ),
                      ),
                ],
              ],
            ),
    );
  }
}

/// Un objetivo con su barra de avance y su frase.
class _TarjetaObjetivo extends StatelessWidget {
  final ProgresoObjetivo progreso;
  final Cuenta? cuenta;
  final VoidCallback alTocar;

  const _TarjetaObjetivo({required this.progreso, required this.cuenta, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final p = progreso;
    final textos = Theme.of(context).textTheme;
    final logrado = p.estado == EstadoObjetivo.logrado;
    final atencion = p.estado == EstadoObjetivo.vencido || p.alcanzaATiempo == false;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(
            label: '${p.objetivo.nombre}: llevas ${p.llevas.formateado()} de ${p.objetivo.monto.formateado()}. '
                '${fraseDeObjetivo(p)}',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(p.objetivo.emoji, style: textos.titleMedium),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.objetivo.nombre, overflow: TextOverflow.ellipsis, style: textos.titleMedium),
                      ),
                      Text(
                        '${(p.avance * 100).floor()}%',
                        style: textos.titleMedium?.copyWith(color: logrado ? ColoresApp.verdeTexto : null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  BarraProporcion(valor: p.avance, color: logrado ? ColoresApp.verde : ColoresApp.oro, alto: 8),
                  const SizedBox(height: 8),
                  Text(
                    '${p.llevas.formateado()} de ${p.objetivo.monto.formateado()}'
                    '${cuenta == null ? '' : ' · en ${cuenta!.nombre}'}',
                    style: textos.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fraseDeObjetivo(p),
                    style: textos.bodySmall?.copyWith(
                      color: logrado
                          ? ColoresApp.verdeTexto
                          : atencion
                              ? ColoresApp.ambarTexto
                              : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
