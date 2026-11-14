import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/ciclo_de_vida/ciclos_para_consultar.dart';
import '../../domain/clasificacion/normalizacion_texto.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/reglas/creacion_movimiento.dart';
import '../../domain/voz/monto_hablado.dart';
import '../captura/pantalla_captura.dart';
import '../comun/asegurar_ciclo_abierto.dart';
import '../comun/aviso_gesto.dart';
import '../comun/formato_fecha.dart';
import '../comun/guia_rapida.dart';
import '../comun/tema.dart';

const _uuid = Uuid();

/// app-finanzas-gastos-v3.html §1–3: agrupado por día, con el total de
/// cada día; la búsqueda contesta "¿cuánto llevo?", no solo filtra.
///
/// Cada movimiento responde a tres gestos (app-finanzas-eliminar-
/// reembolsos-v10.html §1): tocar para editar, deslizar a la izquierda
/// para eliminar (anular — regla no negociable #3, nunca se borra
/// físicamente), deslizar a la derecha para duplicar con la fecha de hoy
/// — "el atajo más usado" para gastos que se repiten casi idénticos.
///
/// Arriba se elige el ciclo (2026-11-14): abre en [cicloId] (el ciclo en
/// curso) y deja consultar los anteriores. Los de un ciclo cerrado se ven
/// pero no se cambian: al tocarlos, `asegurarCicloAbierto` ofrece reabrir
/// el ciclo, igual que antes.
class PantallaGastos extends StatefulWidget {
  final String cicloId;
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;
  final CicloRepositorio cicloRepositorio;
  final CuentaRepositorio? cuentaRepositorio;

  /// Se reenvía tal cual a `PantallaCaptura` cuando se edita un movimiento
  /// desde aquí — ver el comentario en `PantallaCaptura.documentos`.
  final Directory documentos;

  const PantallaGastos({
    super.key,
    required this.cicloId,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
    required this.cicloRepositorio,
    this.cuentaRepositorio,
    required this.documentos,
  });

  @override
  State<PantallaGastos> createState() => _PantallaGastosState();
}

class _PantallaGastosState extends State<PantallaGastos> {
  _DatosGastos? _datos;
  final _busquedaControlador = TextEditingController();
  String _busqueda = '';
  Set<String> _filtroCategorias = {};
  Set<MedioPago> _filtroMedios = {};

  /// El ciclo que se está viendo; arranca en el que recibe la pantalla.
  late String _cicloVisto = widget.cicloId;

  @override
  void initState() {
    super.initState();
    _refrescar();
    WidgetsBinding.instance.addPostFrameCallback((_) => mostrarGuiaRapidaPrimeraVez(context, GuiaRapida.gastos));
    _busquedaControlador.addListener(() {
      setState(
        () => _busqueda = normalizarTexto(_busquedaControlador.text),
      );
    });
  }

  @override
  void dispose() {
    _busquedaControlador.dispose();
    super.dispose();
  }

  Future<void> _refrescar() async {
    final datos = await _cargar();
    if (!mounted) return;
    setState(() => _datos = datos);
  }

  Future<_DatosGastos> _cargar() async {
    final todos = await widget.movimientoRepositorio.listarTodos();
    final guardados = await widget.cicloRepositorio.listarTodos();
    final calculadora = widget.perfil.calculadoraCiclo;
    final ciclos = ciclosParaConsultar(
      enCurso: calculadora.calcularPara(DateTime.now()),
      movimientos: todos,
      guardados: guardados,
      calculadora: calculadora,
    );
    final movimientos = [for (final m in todos) if (m.cicloId == _cicloVisto) m];
    final categorias = await widget.categoriaRepositorio.listarTodas();
    final cuentas = await widget.cuentaRepositorio?.listarTodas() ?? const <Cuenta>[];
    return _DatosGastos(
      ciclos: ciclos,
      cuentasPorId: {for (final c in cuentas) c.id: c},
      movimientos: movimientos
          .where((m) => m.estado == EstadoMovimiento.activo)
          .toList(),
      categoriasPorId: {for (final c in categorias) c.id: c},
    );
  }

  /// Una sola hoja modal para las dos dimensiones de filtro, ambas de
  /// selección múltiple (antes eran `ChoiceChip` de una sola opción cada
  /// una). `FilterChip`/`SegmentedButton` con `multiSelectionEnabled`
  /// caben en una sola pantalla sin scroll para el número de categorías
  /// de una app de uso personal — si algún día no cupieran, el
  /// `SingleChildScrollView` de abajo es la red de seguridad, no el
  /// diseño esperado.
  Future<void> _abrirFiltros(List<Categoria> categorias) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void actualizar(void Function() cambio) {
            setModalState(cambio);
            setState(cambio);
          }

          final hayFiltros = _filtroCategorias.isNotEmpty || _filtroMedios.isNotEmpty;

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtros',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      if (hayFiltros)
                        TextButton(
                          onPressed: () => actualizar(() {
                            _filtroCategorias = {};
                            _filtroMedios = {};
                          }),
                          child: const Text('Limpiar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Categoría (puedes elegir varias)',
                    style: TextStyle(color: ColoresApp.medio),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categorias.map((c) {
                      final elegida = _filtroCategorias.contains(c.id);
                      return FilterChip(
                        label: Text('${c.emoji} ${c.nombre}'),
                        selected: elegida,
                        onSelected: (sel) => actualizar(() {
                          _filtroCategorias = sel
                              ? {..._filtroCategorias, c.id}
                              : _filtroCategorias.difference({c.id});
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Medio de pago',
                    style: TextStyle(color: ColoresApp.medio),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<MedioPago>(
                    multiSelectionEnabled: true,
                    emptySelectionAllowed: true,
                    segments: const [
                      ButtonSegment(value: MedioPago.tarjeta, label: Text('Tarjeta')),
                      ButtonSegment(value: MedioPago.efectivo, label: Text('Efectivo')),
                    ],
                    selected: _filtroMedios,
                    onSelectionChanged: (nuevo) => actualizar(() => _filtroMedios = nuevo),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Listo'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _verCiclo(String cicloId) {
    setState(() => _cicloVisto = cicloId);
    _refrescar();
  }

  /// Hoja con todos los ciclos: más práctico que las flechas cuando hay
  /// mucha historia.
  Future<void> _elegirCiclo(List<CicloConsultable> ciclos) async {
    final elegido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (contexto) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(contexto).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('¿Qué ciclo quieres ver?', style: Theme.of(contexto).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in ciclos)
                      ListTile(
                        selected: c.ciclo.id == _cicloVisto,
                        leading: Icon(c.cerrado ? Icons.lock_outline : Icons.lock_open_outlined),
                        title: Text('Ciclo ${c.ciclo.etiquetaConAnio}'),
                        subtitle: Text(
                          '${fechaCorta(c.ciclo.fechaInicio)} – ${fechaCorta(c.ciclo.fechaFin)} · '
                          '${c.ciclo.id == widget.cicloId ? 'En curso' : c.cerrado ? 'Cerrado' : 'Sin cerrar'}',
                        ),
                        trailing: Text(Dinero(c.totalCentavos).formateado()),
                        onTap: () => Navigator.of(contexto).pop(c.ciclo.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (elegido != null && elegido != _cicloVisto) _verCiclo(elegido);
  }

  List<Movimiento> _filtrar(
    List<Movimiento> movimientos,
    Map<String, Categoria> categoriasPorId,
  ) {
    return movimientos.where((m) {
      if (_filtroCategorias.isNotEmpty && !_filtroCategorias.contains(m.categoriaId)) {
        return false;
      }
      if (_filtroMedios.isNotEmpty && !_filtroMedios.contains(m.medio)) return false;
      if (_busqueda.isNotEmpty) {
        final categoria = categoriasPorId[m.categoriaId];
        // Sin acentos ("cafe" encuentra "Café") y también por monto
        // ("450" encuentra $450.00 y $1,450.00).
        final texto = normalizarTexto(
          '${m.descripcion} ${categoria?.nombre ?? ''} '
          '${m.monto.centavos ~/ 100} ${m.monto.formateado()}',
        );
        if (!texto.contains(_busqueda)) return false;
      }
      return true;
    }).toList()..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      body: datos == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContenido(datos),
    );
  }

  Widget _buildContenido(_DatosGastos datos) {
    final categorias = datos.categoriasPorId.values.toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    final filtrados = _filtrar(datos.movimientos, datos.categoriasPorId);
    final hayFiltrosActivos =
        _busqueda.isNotEmpty ||
        _filtroCategorias.isNotEmpty ||
        _filtroMedios.isNotEmpty;

    final indice = datos.ciclos.indexWhere((c) => c.ciclo.id == _cicloVisto);
    final visto = indice < 0 ? null : datos.ciclos[indice];

    return Column(
      children: [
        if (visto != null)
          _SelectorCiclo(
            visto: visto,
            esEnCurso: visto.ciclo.id == widget.cicloId,
            // La lista va del más reciente al más viejo: "anterior" es el
            // siguiente índice.
            alAnterior: indice + 1 < datos.ciclos.length ? () => _verCiclo(datos.ciclos[indice + 1].ciclo.id) : null,
            alSiguiente: indice > 0 ? () => _verCiclo(datos.ciclos[indice - 1].ciclo.id) : null,
            alElegir: () => _elegirCiclo(datos.ciclos),
          ),
        if (visto != null && visto.cerrado)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColoresApp.azulSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 18, color: ColoresApp.azul),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ciclo cerrado: solo para consultar. Si quieres cambiar un gasto, tócalo y '
                      'te ofreceremos reabrir el ciclo.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ColoresApp.tinta),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busquedaControlador,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar comercio o monto',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Filtros',
                onPressed: () => _abrirFiltros(categorias),
              ),
            ],
          ),
        ),
        if (hayFiltrosActivos)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                label:
                    '${filtrados.length} movimiento(s), total ${montoEnPalabras(Dinero.suma(filtrados.map((m) => m.monto)))}',
                excludeSemantics: true,
                child: Text(
                  '${filtrados.length} movimiento(s) · '
                  '${Dinero.suma(filtrados.map((m) => m.monto)).formateado()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.azul,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: filtrados.isEmpty
              ? Center(
                  child: Text(
                    'Nada por aquí.',
                    style: TextStyle(color: ColoresApp.medio),
                  ),
                )
              : _ListaAgrupadaPorDia(
                  movimientos: filtrados,
                  categoriasPorId: datos.categoriasPorId,
                  perfil: widget.perfil,
                  categoriaRepositorio: widget.categoriaRepositorio,
                  movimientoRepositorio: widget.movimientoRepositorio,
                  reglasAprendidasRepositorio:
                      widget.reglasAprendidasRepositorio,
                  cicloRepositorio: widget.cicloRepositorio,
                  cuentaRepositorio: widget.cuentaRepositorio,
                  cuentasPorId: datos.cuentasPorId,
                  documentos: widget.documentos,
                  onCambio: _refrescar,
                ),
        ),
      ],
    );
  }
}

class _ListaAgrupadaPorDia extends StatelessWidget {
  final List<Movimiento> movimientos;
  final Map<String, Categoria> categoriasPorId;
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;
  final CicloRepositorio cicloRepositorio;
  final CuentaRepositorio? cuentaRepositorio;
  final Map<String, Cuenta> cuentasPorId;
  final Directory documentos;
  final VoidCallback onCambio;

  const _ListaAgrupadaPorDia({
    required this.movimientos,
    required this.categoriasPorId,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
    required this.cicloRepositorio,
    this.cuentaRepositorio,
    required this.cuentasPorId,
    required this.documentos,
    required this.onCambio,
  });

  Future<void> _editar(BuildContext context, Movimiento m) async {
    final puedeModificar = await asegurarCicloAbierto(
      context,
      cicloId: m.cicloId,
      cicloRepositorio: cicloRepositorio,
    );
    if (!puedeModificar || !context.mounted) return;
    await Navigator.of(context).push<Movimiento>(
      MaterialPageRoute(
        builder: (_) => PantallaCaptura(
          perfil: perfil,
          categoriaRepositorio: categoriaRepositorio,
          movimientoRepositorio: movimientoRepositorio,
          reglasAprendidasRepositorio: reglasAprendidasRepositorio,
          cicloRepositorio: cicloRepositorio,
          documentos: documentos,
          paraEditar: m,
          cuentaRepositorio: cuentaRepositorio,
        ),
      ),
    );
    // También sin cambios: si el ciclo se reabrió para editar, el aviso
    // de "cerrado" debe irse.
    onCambio();
  }

  Future<bool> _confirmarEliminar(BuildContext context, Movimiento m) async {
    final puedeModificar = await asegurarCicloAbierto(
      context,
      cicloId: m.cicloId,
      cicloRepositorio: cicloRepositorio,
    );
    if (!puedeModificar || !context.mounted) return false;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este gasto?'),
        content: Text('${m.descripcion} · ${m.monto.formateado()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (context.mounted) await avisarGestoPrimeraVez(context, GestoApp.eliminarGasto);
    if (confirmado != true) return false;
    await movimientoRepositorio.anular(m.id!);
    onCambio();
    return true;
  }

  Future<void> _duplicar(BuildContext context, Movimiento m) async {
    final resultado = crearMovimiento(
      clientId: _uuid.v4(),
      fecha: DateTime.now(),
      calculadoraCiclo: perfil.calculadoraCiclo,
      monto: m.monto,
      categoriaId: m.categoriaId,
      medio: m.medio,
      descripcion: m.descripcion,
      origenCaptura: OrigenCaptura.manual,
    );
    switch (resultado) {
      case Falla():
        return;
      case Exito(valor: final nuevo):
        // El duplicado sale de la misma cuenta.
        final valor = nuevo.copyWith(cuentaId: m.cuentaId);
        await movimientoRepositorio.guardar(valor);
        onCambio();
        if (!context.mounted) return;
        // La primera vez, la explicación ya dice que se duplicó.
        if (await avisarGestoPrimeraVez(context, GestoApp.duplicarGasto)) return;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gasto duplicado: ${valor.descripcion} hoy'),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupos = <DateTime, List<Movimiento>>{};
    for (final m in movimientos) {
      final dia = DateTime(m.fecha.year, m.fecha.month, m.fecha.day);
      grupos.putIfAbsent(dia, () => []).add(m);
    }
    final dias = grupos.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: dias.length,
      itemBuilder: (context, i) {
        final dia = dias[i];
        final movsDelDia = grupos[dia]!;
        final total = Dinero.suma(movsDelDia.map((m) => m.monto));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fechaLarga(dia),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.medio,
                    ),
                  ),
                  Text(
                    total.formateado(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.medio,
                    ),
                  ),
                ],
              ),
            ),
            ...movsDelDia.map((m) {
              final categoria = categoriasPorId[m.categoriaId];
              return Dismissible(
                key: ValueKey(m.id),
                direction: DismissDirection.horizontal,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: ColoresApp.verde,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy, color: Colors.white),
                ),
                secondaryBackground: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: ColoresApp.coral,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) =>
                    direction == DismissDirection.startToEnd
                    ? _duplicar(context, m).then((_) => false)
                    : _confirmarEliminar(context, m),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _editar(context, m),
                    child: ListTile(
                      leading: Text(
                        categoria?.emoji ?? '❔',
                        style: const TextStyle(fontSize: 18),
                      ),
                      title: Text(m.descripcion),
                      subtitle: Text(
                        '${categoria?.nombre ?? m.categoriaId} · '
                        '${cuentasPorId[cuentaDe(m)]?.nombre ?? m.medio.name}',
                      ),
                      trailing: Text(
                        m.monto.formateado(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

String _fechaLarga(DateTime f) {
  const dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  final nombreDia = dias[f.weekday - 1];
  final nombreDia0 = nombreDia[0].toUpperCase() + nombreDia.substring(1);
  return '$nombreDia0 ${f.day} ${meses[f.month - 1]}';
}

class _DatosGastos {
  /// Del más reciente al más viejo (`ciclosParaConsultar`).
  final List<CicloConsultable> ciclos;
  final List<Movimiento> movimientos;
  final Map<String, Categoria> categoriasPorId;
  final Map<String, Cuenta> cuentasPorId;

  const _DatosGastos({
    required this.ciclos,
    required this.movimientos,
    required this.categoriasPorId,
    required this.cuentasPorId,
  });
}

/// "‹ Ciclo Oct 2026 ›" con sus fechas, si está cerrado y cuánto se gastó.
/// Tocar el nombre abre la lista de todos los ciclos.
class _SelectorCiclo extends StatelessWidget {
  final CicloConsultable visto;
  final bool esEnCurso;
  final VoidCallback? alAnterior;
  final VoidCallback? alSiguiente;
  final VoidCallback alElegir;

  const _SelectorCiclo({
    required this.visto,
    required this.esEnCurso,
    required this.alAnterior,
    required this.alSiguiente,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final ciclo = visto.ciclo;
    final estado = esEnCurso ? 'En curso' : visto.cerrado ? 'Cerrado' : 'Sin cerrar';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Ciclo anterior',
            onPressed: alAnterior,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: alElegir,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (visto.cerrado) ...[
                          Icon(Icons.lock_outline, size: 16, color: ColoresApp.medio),
                          const SizedBox(width: 4),
                        ],
                        Flexible(child: Text('Ciclo ${ciclo.etiquetaConAnio}', style: textos.titleMedium)),
                        Icon(Icons.arrow_drop_down, color: ColoresApp.medio),
                      ],
                    ),
                    Text(
                      '${fechaCorta(ciclo.fechaInicio)} – ${fechaCorta(ciclo.fechaFin)} · $estado · '
                      '${Dinero(visto.totalCentavos).formateado()}',
                      textAlign: TextAlign.center,
                      style: textos.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Ciclo siguiente',
            onPressed: alSiguiente,
          ),
        ],
      ),
    );
  }
}
