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
import '../../core/money.dart';
import '../../domain/voz/monto_hablado.dart';
import '../comun/aviso.dart';
import '../comun/chip_estado.dart';
import '../comun/esqueleto.dart';
import '../comun/formato_dinero.dart';
import '../comun/formato_fecha.dart';
import '../comun/renglon_app.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';
import 'pantalla_editar_objetivo.dart';

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
      // Repartido por los días de cada ciclo hasta la fecha (spec §7.3.3):
      // si la fecha cae a 4 días de un corte, ese ciclo pide poco.
      final fecha = p.objetivo.fechaLimite!;
      final r = p.reparto;
      final anio = fecha.year == r.first.ciclo.fechaInicio.year ? '' : ' ${fecha.year}';
      final cuando = 'Para el ${fechaCorta(fecha)}$anio';
      final este = '${enPesos(r.first.monto)} en este ciclo';
      final base = switch (r.length) {
        1 => '$cuando: aparta $este.',
        2 => '$cuando: aparta $este y ${enPesos(r[1].monto)} en el siguiente.',
        _ => '$cuando: aparta $este y unos '
            '${enPesos(r.skip(1).map((t) => t.monto).reduce((a, b) => a.centavos >= b.centavos ? a : b))} '
            'en cada uno de los ${r.length - 1} siguientes.',
      };
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

  /// Dentro de la pestaña Patrimonio, sin barra ni botón flotante propios.
  final bool embebida;

  const PantallaObjetivos({
    super.key,
    this.embebida = false,
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

  Future<void> _editar([Objetivo? objetivo, ({String emoji, String nombre})? sugerencia]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaEditarObjetivo(
          objetivoRepositorio: widget.objetivoRepositorio,
          cuentaRepositorio: widget.cuentaRepositorio,
          existente: objetivo,
          sugerencia: sugerencia,
        ),
      ),
    );
    if (guardado == true) await _cargar();
  }

  static const _sugerencias = [
    (emoji: '✈️', nombre: 'Viaje'),
    (emoji: '🛟', nombre: 'Emergencias'),
    (emoji: '🏡', nombre: 'Enganche'),
  ];

  @override
  Widget build(BuildContext context) {
    final progreso = _progreso;
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final llevas = progreso == null ? const Dinero.cero() : progreso.fold(const Dinero.cero(), (Dinero s, x) => s + x.llevas);
    final meta = progreso == null ? const Dinero.cero() : progreso.fold(const Dinero.cero(), (Dinero s, x) => s + x.objetivo.monto);
    final vencido = progreso?.where((x) => x.estado == EstadoObjetivo.vencido).firstOrNull;
    final cuerpo = progreso == null
        ? const CargandoPantalla(formas: [Esqueleto.tarjeta(alto: 120), SizedBox(height: 12), Esqueleto.tarjeta(alto: 150)])
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              if (progreso.isEmpty) ...[
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle),
                    child: Icon(Icons.flag_outlined, size: 40, color: p.texto2),
                  ),
                ),
                const SizedBox(height: 20),
                Text('¿Para qué ahorras?', textAlign: TextAlign.center, style: textos.titulo),
                const SizedBox(height: 8),
                Text(
                  'Ponle nombre, monto y fecha. Te decimos cuánto apartar.',
                  textAlign: TextAlign.center,
                  style: textos.cuerpo.copyWith(color: p.texto2),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _sugerencias)
                      ActionChip(label: Text('${s.emoji} ${s.nombre}'), onPressed: () => _editar(null, s)),
                  ],
                ),
                const SizedBox(height: 16),
                Center(child: ElevatedButton(onPressed: _editar, child: const Text('Crear objetivo'))),
              ] else ...[
                TarjetaApp(
                  etiquetaSemantica: 'Llevas ahorrado ${montoEnPalabras(llevas)} de ${montoEnPalabras(meta)}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Llevas ahorrado', style: textos.etiqueta),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(enPesos(llevas), style: textos.titulo),
                          const SizedBox(width: 6),
                          Text('de ${enPesos(meta)}', style: textos.cuerpo.copyWith(color: p.texto2)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      BarraProporcion(
                        valor: meta.esPositivo ? (llevas.centavos / meta.centavos).clamp(0.0, 1.0) : 0,
                        color: p.exito,
                        alto: 8,
                      ),
                    ],
                  ),
                ),
                if (vencido != null) ...[
                  const SizedBox(height: 12),
                  Aviso(
                    tono: TonoEstado.atencion,
                    titulo: 'Pasó la fecha de ${vencido.objetivo.nombre}',
                    apoyo: 'Te faltan ${enPesos(vencido.falta)}. ¿Le das más tiempo?',
                    accion: 'Cambiar fecha',
                    onAccion: () => _editar(vencido.objetivo),
                  ),
                ],
                const SizedBox(height: 12),
                for (final x in progreso)
                  _TarjetaObjetivo(
                    progreso: x,
                    cuenta: _cuentas[x.objetivo.cuentaId],
                    alTocar: () => _editar(x.objetivo),
                  ),
                OutlinedButton.icon(onPressed: _editar, icon: const Icon(Icons.add), label: const Text('Nuevo objetivo')),
              ],
              if (_archivados.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _verArchivados = !_verArchivados),
                  child: Text('${_verArchivados ? 'Ocultar' : 'Ver'} archivados (${_archivados.length})'),
                ),
                if (_verArchivados)
                  TarjetaApp.lista(renglones: [
                    for (final o in _archivados)
                      RenglonApp(emoji: o.emoji, titulo: o.nombre, monto: o.monto.formateado(), onTap: () => _editar(o)),
                  ]),
              ],
            ],
          );
    if (!widget.embebida) {
      return Scaffold(appBar: AppBar(title: const Text('Objetivos de ahorro')), body: cuerpo);
    }
    return cuerpo;
  }
}

/// Un objetivo: emoji, nombre, la cuenta donde vive, su estado, avance y
/// la frase de qué hacer.
class _TarjetaObjetivo extends StatelessWidget {
  final ProgresoObjetivo progreso;
  final Cuenta? cuenta;
  final VoidCallback alTocar;

  const _TarjetaObjetivo({required this.progreso, required this.cuenta, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final x = progreso;
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final chip = switch (x.estado) {
      EstadoObjetivo.logrado => const ChipEstado(tono: TonoEstado.exito, texto: 'Logrado'),
      EstadoObjetivo.vencido => const ChipEstado(tono: TonoEstado.atencion, texto: 'Pasó la fecha'),
      EstadoObjetivo.sinFecha => const ChipEstado(tono: TonoEstado.neutro, texto: 'Sin fecha'),
      EstadoObjetivo.enCamino => x.alcanzaATiempo == false
          ? const ChipEstado(tono: TonoEstado.atencion, texto: 'Vas lento')
          : const ChipEstado(tono: TonoEstado.exito, texto: 'A tiempo'),
    };
    final color = switch (chip.tono) {
      TonoEstado.exito => p.exito,
      TonoEstado.atencion => p.atencion,
      _ => p.accion,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaApp(
        onTap: alTocar,
        etiquetaSemantica: '${x.objetivo.nombre}: ${chip.texto}. Llevas ${x.llevas.formateado()} '
            'de ${x.objetivo.monto.formateado()}. ${fraseDeObjetivo(x)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle),
                  child: Text(x.objetivo.emoji, style: textos.seccion, textScaler: TextScaler.noScaling),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(x.objetivo.nombre, overflow: TextOverflow.ellipsis, style: textos.cuerpoFuerte),
                      if (cuenta != null) Text(cuenta!.nombre, style: textos.etiqueta),
                    ],
                  ),
                ),
                chip,
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(enPesos(x.llevas), style: textos.seccion),
                const SizedBox(width: 6),
                Text('de ${enPesos(x.objetivo.monto)}', style: textos.etiqueta),
              ],
            ),
            const SizedBox(height: 8),
            BarraProporcion(valor: x.avance, color: color, alto: 8),
            const SizedBox(height: 8),
            Text(fraseDeObjetivo(x), style: textos.etiqueta),
          ],
        ),
      ),
    );
  }
}
