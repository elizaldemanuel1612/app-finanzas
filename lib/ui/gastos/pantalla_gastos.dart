import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../domain/ciclo_de_vida/cierre_ciclo.dart';
import '../../core/ciclo.dart';
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
import '../comun/tarjeta_app.dart';
import '../comun/renglon_app.dart';
import '../comun/formato_fecha.dart';
import '../comun/esqueleto.dart';
import '../comun/avatar_ajustes.dart';
import '../comun/aviso.dart';
import '../comun/guia_rapida.dart';
import '../comun/selector_ciclo.dart';
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

  /// Como pestaña raíz: el encabezado lleva el avatar que abre Ajustes y el
  /// estado vacío ofrece registrar. Sin esto, barra con flecha ← de siempre.
  final String? nombre;
  final VoidCallback? alAbrirAjustes;
  final VoidCallback? alRegistrar;

  /// Abre ya filtrada por esta categoría (desde un ciclo de Historial).
  final String? categoriaInicial;

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
    this.nombre,
    this.alAbrirAjustes,
    this.alRegistrar,
    this.categoriaInicial,
  });

  @override
  State<PantallaGastos> createState() => _PantallaGastosState();
}

class _PantallaGastosState extends State<PantallaGastos> {
  _DatosGastos? _datos;
  final _busquedaControlador = TextEditingController();
  String _busqueda = '';
  late Set<String> _filtroCategorias = {?widget.categoriaInicial};
  Set<String> _filtroCuentas = {};

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
  Future<void> _abrirFiltros(List<Categoria> categorias, List<Cuenta> cuentas) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void actualizar(void Function() cambio) {
            setModalState(cambio);
            setState(cambio);
          }

          final hayFiltros = _filtroCategorias.isNotEmpty || _filtroCuentas.isNotEmpty;

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
                      Text('Filtros', style: Theme.of(context).textTheme.seccion),
                      if (hayFiltros)
                        TextButton(
                          onPressed: () => actualizar(() {
                            _filtroCategorias = {};
                            _filtroCuentas = {};
                          }),
                          child: const Text('Limpiar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Categoría (puedes elegir varias)', style: Theme.of(context).textTheme.etiqueta),
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
                  if (cuentas.isNotEmpty) ...[
                    Text('Cuenta', style: Theme.of(context).textTheme.etiqueta),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in cuentas)
                          FilterChip(
                            label: Text(c.nombre),
                            selected: _filtroCuentas.contains(c.id),
                            onSelected: (sel) => actualizar(() {
                              _filtroCuentas = sel ? {..._filtroCuentas, c.id} : _filtroCuentas.difference({c.id});
                            }),
                          ),
                      ],
                    ),
                  ],
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

  List<Movimiento> _filtrar(
    List<Movimiento> movimientos,
    Map<String, Categoria> categoriasPorId,
  ) {
    return movimientos.where((m) {
      if (_filtroCategorias.isNotEmpty && !_filtroCategorias.contains(m.categoriaId)) {
        return false;
      }
      if (_filtroCuentas.isNotEmpty && !_filtroCuentas.contains(cuentaDe(m))) return false;
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

  /// Reabrir desde el aviso de ciclo cerrado: confirma, porque cambia
  /// datos (componentes/Hoja.md), y deja rastro (regla #6).
  Future<void> _reabrir(Ciclo ciclo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Reabrir ${ciclo.etiquetaConAnio}?'),
        content: const Text('Podrás cambiar sus gastos. Ciérralo otra vez desde Análisis › Historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(contexto).pop(true), child: const Text('Reabrir')),
        ],
      ),
    );
    if (confirmado != true) return;
    final guardado = await widget.cicloRepositorio.buscarPorId(ciclo.id);
    if (guardado == null) return;
    if (reabrirCiclo(guardado) case Exito(:final valor)) {
      await widget.cicloRepositorio.guardar(valor);
    }
    await _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    final raiz = widget.alAbrirAjustes != null;
    final cuerpo = datos == null
        ? const CargandoPantalla(formas: [
            Esqueleto(alto: 44, radio: Radios.m),
            Esqueleto(alto: 52, radio: Radios.m),
            Esqueleto(ancho: 140, alto: 14),
            Esqueleto(alto: 64, radio: 16),
            Esqueleto(alto: 64, radio: 16),
            Esqueleto(ancho: 140, alto: 14),
            Esqueleto(alto: 64, radio: 16),
          ])
        : _buildContenido(datos);
    if (!raiz) {
      return Scaffold(appBar: AppBar(title: const Text('Gastos')), body: cuerpo);
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoRaiz(titulo: 'Gastos', nombre: widget.nombre, alAbrirAjustes: widget.alAbrirAjustes!),
            Expanded(child: cuerpo),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido(_DatosGastos datos) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final categorias = datos.categoriasPorId.values.toList()..sort((a, b) => a.nombre.compareTo(b.nombre));
    final filtrados = _filtrar(datos.movimientos, datos.categoriasPorId);
    final hayFiltrosActivos = _busqueda.isNotEmpty || _filtroCategorias.isNotEmpty || _filtroCuentas.isNotEmpty;
    final indice = datos.ciclos.indexWhere((c) => c.ciclo.id == _cicloVisto);
    final visto = indice < 0 ? null : datos.ciclos[indice];
    final cerrado = visto?.cerrado ?? false;

    // Chips rápidos: las categorías y cuentas que sí aparecen en el ciclo,
    // de la más usada a la menos (componentes/Chip.md: se combinan).
    final usos = <String, int>{};
    final usosCuenta = <String, int>{};
    for (final m in datos.movimientos) {
      usos[m.categoriaId] = (usos[m.categoriaId] ?? 0) + 1;
      usosCuenta[cuentaDe(m)] = (usosCuenta[cuentaDe(m)] ?? 0) + 1;
    }
    final categoriasUsadas = [
      for (final id in (usos.keys.toList()..sort((a, b) => usos[b]!.compareTo(usos[a]!))))
        ?datos.categoriasPorId[id],
    ];
    final cuentasUsadas = [
      for (final id in (usosCuenta.keys.toList()..sort((a, b) => usosCuenta[b]!.compareTo(usosCuenta[a]!))))
        ?datos.cuentasPorId[id],
    ];
    final cuentasTodas = datos.cuentasPorId.values.where((c) => c.activa).toList();

    final encabezado = <Widget>[
      SelectorCiclo(ciclos: datos.ciclos, vistoId: _cicloVisto, enCursoId: widget.cicloId, alCambiar: _verCiclo),
      if (visto != null && cerrado)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Aviso.info(
            icono: Icons.lock_outline_rounded,
            titulo: 'Ciclo cerrado',
            apoyo: 'Solo para consultar',
            boton: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: () => _reabrir(visto.ciclo),
              child: const Text('Reabrir'),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _busquedaControlador,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Buscar gasto o monto',
                  fillColor: p.superficieHundida,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radios.m), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radios.m), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              height: 52,
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: p.superficieHundida,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
                ),
                icon: Badge(isLabelVisible: hayFiltrosActivos, smallSize: 8, child: Icon(Icons.tune_rounded, color: p.texto)),
                tooltip: 'Filtros',
                onPressed: () => _abrirFiltros(categorias, cuentasTodas),
              ),
            ),
          ],
        ),
      ),
      if (categoriasUsadas.length + cuentasUsadas.length > 1)
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: _filtroCategorias.isEmpty && _filtroCuentas.isEmpty,
                onSelected: (_) => setState(() {
                  _filtroCategorias = {};
                  _filtroCuentas = {};
                }),
              ),
              for (final c in categoriasUsadas) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('${c.emoji} ${c.nombre}'),
                  selected: _filtroCategorias.contains(c.id),
                  onSelected: (sel) => setState(() {
                    _filtroCategorias = sel ? {..._filtroCategorias, c.id} : _filtroCategorias.difference({c.id});
                  }),
                ),
              ],
              for (final c in cuentasUsadas) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(c.nombre),
                  selected: _filtroCuentas.contains(c.id),
                  onSelected: (sel) => setState(() {
                    _filtroCuentas = sel ? {..._filtroCuentas, c.id} : _filtroCuentas.difference({c.id});
                  }),
                ),
              ],
            ],
          ),
        ),
      if (hayFiltrosActivos)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Semantics(
            label: '${filtrados.length} ${filtrados.length == 1 ? 'gasto' : 'gastos'}, '
                'total ${montoEnPalabras(Dinero.suma(filtrados.map((m) => m.monto)))}',
            excludeSemantics: true,
            child: Text(
              '${filtrados.length} ${filtrados.length == 1 ? 'gasto' : 'gastos'} · '
              '${Dinero.suma(filtrados.map((m) => m.monto)).formateado()}',
              style: textos.cuerpoFuerte,
            ),
          ),
        ),
    ];

    final Widget lista;
    if (datos.movimientos.isEmpty) {
      lista = Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
        child: TarjetaApp(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle),
                child: Icon(Icons.receipt_long_outlined, color: p.texto),
              ),
              const SizedBox(height: 12),
              Text('Aún no hay gastos', style: textos.seccion),
              const SizedBox(height: 4),
              Text('Aquí verás en qué se va tu dinero.', style: textos.etiqueta, textAlign: TextAlign.center),
              if (widget.alRegistrar != null && !cerrado) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: widget.alRegistrar,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Registrar gasto'),
                ),
              ],
            ],
          ),
        ),
      );
    } else if (filtrados.isEmpty) {
      lista = Padding(
        padding: const EdgeInsets.all(32),
        child: Text('Nada con esos filtros.', textAlign: TextAlign.center, style: textos.etiqueta),
      );
    } else {
      lista = _ListaAgrupadaPorDia(
        movimientos: filtrados,
        categoriasPorId: datos.categoriasPorId,
        perfil: widget.perfil,
        categoriaRepositorio: widget.categoriaRepositorio,
        movimientoRepositorio: widget.movimientoRepositorio,
        reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
        cicloRepositorio: widget.cicloRepositorio,
        cuentaRepositorio: widget.cuentaRepositorio,
        cuentasPorId: datos.cuentasPorId,
        documentos: widget.documentos,
        cerrado: cerrado,
        onCambio: _refrescar,
      );
    }

    return RefreshIndicator(
      onRefresh: _refrescar,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [...encabezado, lista],
      ),
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

  /// Ciclo cerrado: solo se consulta, sin deslizar.
  final bool cerrado;

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
    required this.cerrado,
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

  /// Deslizar a la izquierda anula al instante y ofrece Deshacer
  /// (componentes/Renglon.md); nada se borra (regla #3).
  Future<bool> _anular(BuildContext context, Movimiento m) async {
    final puedeModificar = await asegurarCicloAbierto(context, cicloId: m.cicloId, cicloRepositorio: cicloRepositorio);
    if (!puedeModificar || !context.mounted) return false;
    await movimientoRepositorio.anular(m.id!);
    onCambio();
    if (!context.mounted) return true;
    if (await avisarGestoPrimeraVez(context, GestoApp.eliminarGasto)) return true;
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Anulaste ${m.descripcion} · ${m.monto.formateado()}'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await movimientoRepositorio.actualizar(m.copyWith(estado: EstadoMovimiento.activo));
            onCambio();
          },
        ),
      ));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final grupos = <DateTime, List<Movimiento>>{};
    for (final m in movimientos) {
      final dia = DateTime(m.fecha.year, m.fecha.month, m.fecha.day);
      grupos.putIfAbsent(dia, () => []).add(m);
    }
    final dias = grupos.keys.toList()..sort((a, b) => b.compareTo(a));

    Widget renglon(Movimiento m) {
      final categoria = categoriasPorId[m.categoriaId];
      final cuenta = cuentasPorId[cuentaDe(m)]?.nombre ?? (m.medio == MedioPago.efectivo ? 'Efectivo' : 'Tarjeta');
      final fila = RenglonApp(
        emoji: categoria?.emoji ?? '❔',
        titulo: m.descripcion,
        subtitulo: '${categoria?.nombre ?? m.categoriaId} · $cuenta',
        monto: m.monto.formateado(),
        onTap: () => _editar(context, m),
      );
      // En ciclos cerrados no se desliza (componentes/Renglon.md).
      if (cerrado) return fila;
      Widget fondo(Color color, IconData icono, String texto, Alignment alineacion) => Container(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: alineacion,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, color: p.texto),
                const SizedBox(width: 6),
                Text(texto, style: textos.cuerpoFuerte),
              ],
            ),
          );
      return Dismissible(
        key: ValueKey(m.id),
        direction: DismissDirection.horizontal,
        background: fondo(p.exitoFondo, Icons.copy_rounded, 'Duplicar', Alignment.centerLeft),
        secondaryBackground: fondo(p.peligroFondo, Icons.block_rounded, 'Anular', Alignment.centerRight),
        confirmDismiss: (direccion) => direccion == DismissDirection.startToEnd
            ? _duplicar(context, m).then((_) => false)
            : _anular(context, m),
        child: fila,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final dia in dias) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fechaLarga(dia), style: textos.etiqueta.copyWith(fontWeight: FontWeight.w600, color: p.texto)),
                  Text(Dinero.suma(grupos[dia]!.map((m) => m.monto)).formateado(), style: textos.etiqueta),
                ],
              ),
            ),
            TarjetaApp.lista(renglones: [for (final m in grupos[dia]!) renglon(m)]),
          ],
        ],
      ),
    );
  }
}

/// "Hoy · sáb 14 nov", "Ayer · vie 13 nov" o "Jue 12 nov".
String _fechaLarga(DateTime f) {
  const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final corta = '${dias[f.weekday - 1]} ${fechaCorta(f)}';
  if (f == hoy) return 'Hoy · $corta';
  if (f == hoy.subtract(const Duration(days: 1))) return 'Ayer · $corta';
  return corta[0].toUpperCase() + corta.substring(1);
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

