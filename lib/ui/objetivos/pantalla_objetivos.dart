import 'package:flutter/material.dart';

import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/objetivo_repositorio.dart';
import '../../domain/cuentas/apartados.dart';
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
import '../comun/guia_rapida.dart';
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
  _VistaObjetivos? _vista;

  @override
  void initState() {
    super.initState();
    _cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) => mostrarGuiaRapidaPrimeraVez(context, GuiaRapida.objetivos));
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

  /// Un logrado que ya se usó: se archiva (no se borra) y deja de llenarse
  /// con el saldo de su cuenta.
  Future<void> _archivar(Objetivo objetivo) async {
    await widget.objetivoRepositorio.guardar(objetivo.copyWith(activo: false));
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Archivaste ${objetivo.nombre}. Lo encuentras en Archivados.')),
    );
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
    final grupos = progreso == null ? null : agruparObjetivos(progreso);
    final vencido = grupos?.porCumplir.where((x) => x.estado == EstadoObjetivo.vencido).firstOrNull;
    // Sin elegir: lo que falta; si no falta nada, lo logrado.
    // Una vista que se quedó vacía (se archivó el último logrado) regresa
    // a la de omisión.
    final elegida = switch (_vista) {
      _VistaObjetivos.logrados when grupos?.logrados.isEmpty ?? true => null,
      _VistaObjetivos.archivados when _archivados.isEmpty => null,
      final v => v,
    };
    final vista = elegida ??
        (grupos != null && grupos.porCumplir.isEmpty && grupos.logrados.isNotEmpty
            ? _VistaObjetivos.logrados
            : _VistaObjetivos.porCumplir);
    Widget tarjeta(ProgresoObjetivo x, {VoidCallback? alArchivar}) {
      final cuenta = _cuentas[x.objetivo.cuentaId];
      return _TarjetaObjetivo(
        progreso: x,
        cuenta: cuenta,
        nombreDeCuenta: cuenta == null ? null : nombreConCuenta(cuenta, _cuentas.values.toList()),
        alTocar: () => _editar(x.objetivo),
        alArchivar: alArchivar,
      );
    }

    final cuerpo = progreso == null
        ? const CargandoPantalla(formas: [Esqueleto.tarjeta(alto: 120), SizedBox(height: 12), Esqueleto.tarjeta(alto: 150)])
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              if (progreso.isEmpty && _archivados.isEmpty) ...[
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
                if (progreso.isNotEmpty) ...[
                  _Resumen(porCumplir: grupos!.porCumplir, logrados: grupos.logrados),
                  const SizedBox(height: 12),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (v, texto, n) in [
                        (_VistaObjetivos.porCumplir, 'Por cumplir', grupos!.porCumplir.length),
                        (_VistaObjetivos.logrados, 'Logrados', grupos.logrados.length),
                        (_VistaObjetivos.archivados, 'Archivados', _archivados.length),
                      ])
                        if (n > 0 || v == _VistaObjetivos.porCumplir)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$texto · $n'),
                              selected: vista == v,
                              onSelected: (_) => setState(() => _vista = v),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...switch (vista) {
                  _VistaObjetivos.porCumplir => [
                      if (grupos.porCumplir.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            progreso.isEmpty
                                ? 'No tienes objetivos activos. ¿Para qué quieres ahorrar ahora?'
                                : 'Cumpliste todos tus objetivos. ¿Cuál sigue?',
                            style: textos.cuerpo.copyWith(color: p.texto2),
                          ),
                        ),
                      if (vencido != null) ...[
                        Aviso(
                          tono: TonoEstado.atencion,
                          titulo: 'Pasó la fecha de ${vencido.objetivo.nombre}',
                          apoyo: 'Te faltan ${enPesos(vencido.falta)}. ¿Le das más tiempo?',
                          accion: 'Cambiar fecha',
                          onAccion: () => _editar(vencido.objetivo),
                        ),
                        const SizedBox(height: 12),
                      ],
                      for (final x in grupos.porCumplir) tarjeta(x),
                      OutlinedButton.icon(onPressed: _editar, icon: const Icon(Icons.add), label: const Text('Nuevo objetivo')),
                    ],
                  _VistaObjetivos.logrados => [
                      for (final x in grupos.logrados) tarjeta(x, alArchivar: () => _archivar(x.objetivo)),
                    ],
                  _VistaObjetivos.archivados => [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Los que ya usaste o dejaste. Tócalos para volver a activarlos.',
                          style: textos.etiqueta,
                        ),
                      ),
                      TarjetaApp.lista(renglones: [
                        for (final o in _archivados)
                          RenglonApp(emoji: o.emoji, titulo: o.nombre, monto: o.monto.formateado(), onTap: () => _editar(o)),
                      ]),
                    ],
                },
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

  /// "Viaje · BBVA débito" si la cuenta es un apartado (spec §7.3.5).
  final String? nombreDeCuenta;
  final VoidCallback alTocar;

  /// Solo en los logrados: "Ya lo usé" lo archiva.
  final VoidCallback? alArchivar;

  const _TarjetaObjetivo({
    required this.progreso,
    required this.cuenta,
    required this.alTocar,
    this.nombreDeCuenta,
    this.alArchivar,
  });

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
                      if (cuenta != null) Text(nombreDeCuenta ?? cuenta!.nombre, style: textos.etiqueta),
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
            if (alArchivar != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: alArchivar,
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Ya lo usé, archivar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _VistaObjetivos { porCumplir, logrados, archivados }

/// Lo de arriba: cuánto falta en lo que no se ha cumplido y cuánto pide
/// este ciclo para ir a tiempo; si ya no falta nada, lo logrado.
class _Resumen extends StatelessWidget {
  final List<ProgresoObjetivo> porCumplir;
  final List<ProgresoObjetivo> logrados;

  const _Resumen({required this.porCumplir, required this.logrados});

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    Dinero suma(Iterable<Dinero> xs) => Dinero.suma(xs.toList());
    final sinPendientes = porCumplir.isEmpty;
    final lista = sinPendientes ? logrados : porCumplir;
    final llevas = suma(lista.map((x) => x.llevas));
    final meta = suma(lista.map((x) => x.objetivo.monto));
    final falta = suma(porCumplir.map((x) => x.falta));
    final esteCiclo = aApartarEsteCiclo(porCumplir);
    final n = porCumplir.length;
    final titulo = sinPendientes ? 'Lograste' : 'Te faltan';
    final cifra = sinPendientes ? llevas : falta;
    final apoyo = sinPendientes
        ? 'en ${logrados.length} ${logrados.length == 1 ? 'objetivo' : 'objetivos'}'
        : 'en $n ${n == 1 ? 'objetivo' : 'objetivos'} · llevas ${enPesos(llevas)} de ${enPesos(meta)}';
    return TarjetaApp(
      etiquetaSemantica: '$titulo ${montoEnPalabras(cifra)} $apoyo'
          '${esteCiclo.esPositivo ? '. Este ciclo aparta ${montoEnPalabras(esteCiclo)} para ir a tiempo' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: textos.etiqueta),
          Text(enPesos(cifra), style: textos.titulo),
          Text(apoyo, style: textos.etiqueta),
          const SizedBox(height: 10),
          BarraProporcion(
            valor: meta.esPositivo ? (llevas.centavos / meta.centavos).clamp(0.0, 1.0) : 0,
            color: p.exito,
            alto: 8,
          ),
          if (esteCiclo.esPositivo) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.savings_outlined, size: 18, color: p.texto2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Este ciclo aparta ${enPesos(esteCiclo)} para ir a tiempo',
                    style: textos.cuerpo,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
