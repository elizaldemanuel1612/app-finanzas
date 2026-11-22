import 'dart:async';

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/voz/interpretar_gasto.dart';
import '../../domain/voz/monto_hablado.dart';
import '../../data/almacenamiento/almacen_fotos.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/clasificacion/cascada_clasificacion.dart';
import '../../domain/clasificacion/historial_comercios.dart';
import '../../domain/clasificacion/regla_aprendida.dart';
import '../../domain/cuentas/compra_a_meses.dart';
import '../../domain/cuentas/saldos.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/reglas/creacion_movimiento.dart';
import '../../domain/reglas/fecha_movimiento.dart';
import '../../domain/reglas/monto.dart';
import '../../domain/rollups/orden_categorias.dart';
import '../../plataforma/dictado_web.dart';
import '../../plataforma/ia_dictado.dart';
import '../comun/asegurar_ciclo_abierto.dart';
import '../comun/formato_dinero.dart';
import '../comun/tarjeta_app.dart';
import '../comun/renglon_app.dart';
import '../comun/formato_fecha.dart';
import '../../data/ia/servicio_ia.dart';
import '../comun/borde_para_regresar.dart';
import '../comun/boton_burbuja.dart';
import '../comun/popscope_descartar.dart';
import '../comun/selector_fecha.dart';
import '../comun/tema.dart';
import 'hoja_dictado.dart';
import 'pantalla_dividir_ticket.dart';
import 'pantalla_revision_dictado.dart';
import '../comun/hoja.dart';

const _uuid = Uuid();

/// Captura manual — la regla de los dos taps (addendum-v3 §3.4): monto,
/// categoría, listo. Escritura local optimista: no hay ningún `await` de
/// red aquí, el gasto se guarda de inmediato (spec-app-finanzas-v2.md §4.1).
///
/// Si [paraEditar] viene con un movimiento, la pantalla entra en modo
/// edición: precarga sus valores y, al guardar, reemplaza ese movimiento en
/// vez de crear uno nuevo. El `cicloId` original nunca se toca (regla no
/// negociable #5) — solo se editan monto, categoría, medio y descripción.
class PantallaCaptura extends StatefulWidget {
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;
  final CicloRepositorio cicloRepositorio;
  final Movimiento? paraEditar;

  /// Carpeta de documentos **ya namespaced por cuenta**
  /// (`AlmacenLocal.directorio`, ver `main.dart`) — se recibe por fuera en
  /// vez de resolverse con `getApplicationDocumentsDirectory()` aquí adentro
  /// para no reintroducir el hallazgo de seguridad que ese namespace
  /// arregló (fotos de tickets compartidas entre cualquier cuenta que
  /// iniciara sesión en el dispositivo).
  final Directory documentos;

  /// Abre el dictado en cuanto aparece la pantalla — es lo que piden el
  /// botón "Dictar" del widget y el atajo de Siri (spec-app-finanzas-v2.md
  /// §5.6). El dictado llena el formulario y el usuario confirma con
  /// "Listo", igual que si hubiera tocado el micrófono.
  final bool iniciarDictado;

  /// Para elegir con qué tarjeta o efectivo se pagó (spec §7.3.1). Sin él,
  /// el selector Tarjeta / Efectivo de antes.
  final CuentaRepositorio? cuentaRepositorio;

  /// La IA del usuario para el Nivel 3 de la cascada (spec §6.5); `null` =
  /// solo reglas e historial.
  final ServicioIA? servicioIA;

  /// Para decir cuánto le queda a cada categoría con los ajustes del ciclo;
  /// sin él, contra su presupuesto base.
  final AjustePresupuestoCicloRepositorio? ajustePresupuestoCicloRepositorio;

  const PantallaCaptura({
    super.key,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
    required this.cicloRepositorio,
    required this.documentos,
    this.paraEditar,
    this.iniciarDictado = false,
    this.cuentaRepositorio,
    this.servicioIA,
    this.ajustePresupuestoCicloRepositorio,
  });

  @override
  State<PantallaCaptura> createState() => _PantallaCapturaState();
}

class _PantallaCapturaState extends State<PantallaCaptura> {
  final _montoControlador = TextEditingController();
  final _descripcionControlador = TextEditingController();
  late Future<List<Categoria>> _categorias;
  Categoria? _seleccionada;
  MedioPago _medio = MedioPago.tarjeta;

  /// Activas, la más usada primero; vacía si no hay [PantallaCaptura.cuentaRepositorio].
  List<Cuenta> _cuentas = [];
  String? _cuentaId;

  /// Compra a meses sin intereses (spec §7.3.1): `null` = de contado. Solo
  /// con una tarjeta de crédito y al crear.
  int? _meses;
  late DateTime _fecha;
  String? _error;
  bool _guardando = false;
  String? _fotoUrl;
  bool _cargandoFoto = false;

  List<Categoria> _categoriasCache = [];
  List<ReglaAprendida> _reglasCache = [];
  Map<String, String> _historialComercios = {};
  bool _categoriaTocadaManualmente = false;
  bool _sugerida = false;

  /// La sugerencia vino de la IA del usuario, no del historial.
  bool _sugeridaPorIA = false;
  Timer? _esperaIA;

  @override
  void initState() {
    super.initState();
    _categorias = _cargarCategorias();
    _categorias.then((categorias) {
      if (mounted) setState(() => _categoriasCache = categorias);
    });
    _cargarCascada();
    _cargarCuentas();
    _cargarQuedan();

    final paraEditar = widget.paraEditar;
    _fecha = paraEditar?.fecha ?? DateTime.now();
    if (paraEditar != null) {
      _categoriaTocadaManualmente =
          true; // no auto-sugerir sobre algo que ya se editó a mano
      _montoControlador.text = textoEditableDeDinero(paraEditar.monto);
      _descripcionControlador.text = paraEditar.descripcion;
      _medio = paraEditar.medio;
      _categorias.then((categorias) {
        if (!mounted) return;
        for (final c in categorias) {
          if (c.id == paraEditar.categoriaId) {
            setState(() => _seleccionada = c);
            break;
          }
        }
      });
    } else {
      _descripcionControlador.addListener(_sugerirCategoriaPorDescripcion);
    }
    if (widget.iniciarDictado) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dictar();
      });
    }
  }

  /// Lo que le queda a cada variable en el ciclo de hoy, para la rejilla
  /// ("Quedan $1,880"); las fijas dicen "Fijo".
  Map<String, Dinero> _quedan = const {};

  Future<void> _cargarQuedan() async {
    final ciclo = widget.perfil.calculadoraCiclo.calcularPara(DateTime.now());
    final categorias = await widget.categoriaRepositorio.listarActivas();
    final ajustes = await widget.ajustePresupuestoCicloRepositorio?.listarPorCiclo(ciclo.id) ?? const [];
    final efectivas = presupuestosEfectivosParaCiclo(base: categorias, ajustesDelCiclo: ajustes);
    final movimientos = await widget.movimientoRepositorio.listarPorCiclo(ciclo.id);
    final gastado = <String, int>{};
    for (final m in movimientos) {
      if (m.estado == EstadoMovimiento.activo) gastado[m.categoriaId] = (gastado[m.categoriaId] ?? 0) + m.monto.centavos;
    }
    if (!mounted) return;
    setState(() {
      _quedan = {
        // Sin presupuesto (spec §7.3.6) no hay "lo que le queda".
        for (final c in efectivas.whereType<CategoriaVariable>())
          if (!c.sinPresupuesto) c.id: c.presupuestoMensualCentavos - Dinero(gastado[c.id] ?? 0),
      };
    });
  }

  /// Por omisión, la del gasto que se edita o la del último gasto.
  Future<void> _cargarCuentas() async {
    final repo = widget.cuentaRepositorio;
    if (repo == null) return;
    final cuentas = await repo.listarTodas();
    final gastos = await widget.movimientoRepositorio.listarTodos();
    final ordenadas = ordenarCuentasPorUso(cuentas, gastos);
    if (!mounted || ordenadas.isEmpty) return;
    final editar = widget.paraEditar;
    final propuesta = editar != null ? cuentaDe(editar) : ultimaCuentaUsada(gastos);
    final elegida = ordenadas.where((c) => c.id == propuesta).firstOrNull ??
        ordenadas.where((c) => editar != null && c.tipo.medio == editar.medio).firstOrNull ??
        ordenadas.first;
    setState(() {
      // La del gasto que se edita aparece aunque esté archivada.
      _cuentas = [
        ...ordenadas,
        if (editar != null && !ordenadas.any((c) => c.id == cuentaDe(editar)))
          ...cuentas.where((c) => c.id == cuentaDe(editar)),
      ];
      _elegirCuenta(_cuentas.firstWhere((c) => c.id == propuesta, orElse: () => elegida));
    });
  }

  void _elegirCuenta(Cuenta cuenta) {
    _cuentaId = cuenta.id;
    _medio = cuenta.tipo.medio;
    if (cuenta.tipo != TipoCuenta.credito) _meses = null;
  }

  /// Una mensualidad: solo se cambian la categoría y la nota, para toda la
  /// compra (spec §7.3.1).
  bool get _editandoAMeses => widget.paraEditar?.esAMeses ?? false;

  Future<void> _elegirMeses() async {
    final monto = _monto;
    final hayMonto = monto != null && monto.esPositivo;
    final elegido = await mostrarHoja<int>(
      context,
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿A meses sin intereses?', style: Theme.of(contexto).textTheme.seccion),
              const SizedBox(height: 4),
              Text(
                'Cada mensualidad cuenta en su mes: en tu presupuesto y en el pago de tu tarjeta.',
                style: Theme.of(contexto).textTheme.etiqueta,
              ),
              const SizedBox(height: 12),
              TarjetaApp.lista(renglones: [
                RenglonApp(
                  icono: Icons.payments_outlined,
                  titulo: 'De contado',
                  subtitulo: 'Todo en este mes',
                  derecha: _meses == null ? Icon(Icons.check_rounded, color: ColoresApp.texto) : null,
                  onTap: () => Navigator.of(contexto).pop(0),
                ),
                for (final n in plazosAMeses)
                  RenglonApp(
                    icono: Icons.calendar_view_month_outlined,
                    titulo: '$n meses',
                    subtitulo: hayMonto && monto.centavos >= n
                        ? '${enPesos(repartirEnMensualidades(monto, n).last)} al mes'
                        : null,
                    derecha: _meses == n ? Icon(Icons.check_rounded, color: ColoresApp.texto) : null,
                    onTap: () => Navigator.of(contexto).pop(n),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (elegido != null && mounted) setState(() => _meses = elegido == 0 ? null : elegido);
  }

  /// Lo que dijo el dictado ("en efectivo"): la cuenta elegida si ya es de
  /// ese medio; si no, la primera que lo sea.
  void _elegirMedio(MedioPago medio) {
    _medio = medio;
    final actual = _cuentas.where((c) => c.id == _cuentaId).firstOrNull;
    if (actual == null || actual.tipo.medio == medio) return;
    final otra = _cuentas.where((c) => c.tipo.medio == medio).firstOrNull;
    if (otra != null) _elegirCuenta(otra);
  }

  /// Las más usadas primero (`ordenarPorUso`, spec §5.6).
  Future<List<Categoria>> _cargarCategorias() async {
    final categorias = await widget.categoriaRepositorio.listarActivas();
    final movimientos = await widget.movimientoRepositorio.listarTodos();
    return ordenarPorUso(categorias, movimientos);
  }

  /// Reglas del usuario (Nivel 1) e historial de comercios ya clasificados
  /// (Nivel 2) para la cascada (spec-app-finanzas-v2.md §6.1). Sin IA
  /// conectada todavía (Nivel 3) — la app funciona completa solo con
  /// estos dos niveles (§6.4).
  Future<void> _cargarCascada() async {
    final reglas = await widget.reglasAprendidasRepositorio.listarTodas();
    final movimientos = await widget.movimientoRepositorio.listarTodos();
    if (!mounted) return;
    setState(() {
      _reglasCache = reglas;
      _historialComercios = construirHistorialComercios([
        for (final m in movimientos)
          if (m.estado == EstadoMovimiento.activo)
            ObservacionComercio(m.descripcion, m.categoriaId),
      ]);
    });
  }

  void _sugerirCategoriaPorDescripcion() {
    if (_categoriaTocadaManualmente) return;
    final texto = _descripcionControlador.text;
    if (texto.trim().isEmpty) return;
    final resultado = clasificar(
      texto: texto,
      reglasUsuario: _reglasCache,
      historialComercios: _historialComercios,
    );
    _esperaIA?.cancel();
    if (!resultado.resuelto) {
      // Nivel 3 (spec §6.5): la IA del usuario, cuando deja de escribir. Si
      // tarda o falla no pasa nada: la captura nunca la espera.
      if (widget.servicioIA != null) {
        _esperaIA = Timer(const Duration(milliseconds: 700), () => _sugerirConIA(texto));
      }
      return;
    }
    _resaltar(resultado.categoriaId!, porIA: false);
  }

  Future<void> _sugerirConIA(String texto) async {
    final porIA = await widget.servicioIA!.clasificar(texto, _categoriasCache);
    // Si ya cambió la nota o eligió a mano, la respuesta llegó tarde.
    if (!mounted || porIA == null || _categoriaTocadaManualmente || _descripcionControlador.text != texto) return;
    final cascada = cascadaDesdeIA(porIA);
    if (cascada.resuelto) _resaltar(cascada.categoriaId!, porIA: true);
  }

  void _resaltar(String categoriaId, {required bool porIA}) {
    for (final c in _categoriasCache) {
      if (c.id == categoriaId) {
        setState(() {
          _seleccionada = c;
          _sugerida = true;
          _sugeridaPorIA = porIA;
        });
        break;
      }
    }
  }

  /// Al editar, solo cuenta lo que difiere del gasto original: el monto ya
  /// viene lleno, y tratarlo como cambio bloqueaba el gesto de atrás.
  bool get _hayCambiosSinGuardar {
    final e = widget.paraEditar;
    if (e == null) return _hayCambiosEnNuevo;
    return _monto != e.monto ||
        _descripcionControlador.text != e.descripcion ||
        (_seleccionada != null && _seleccionada!.id != e.categoriaId) ||
        _fecha != e.fecha ||
        (_cuentaId != null && _cuentaId != cuentaDe(e)) ||
        (_fotoUrl != null && _fotoUrl != e.fotoUrl);
  }

  bool get _hayCambiosEnNuevo =>
      _montoControlador.text.isNotEmpty ||
      _descripcionControlador.text.isNotEmpty ||
      _seleccionada != null ||
      _fotoUrl != null;

  @override
  void dispose() {
    _esperaIA?.cancel();
    _montoControlador.dispose();
    _descripcionControlador.dispose();
    super.dispose();
  }

  /// Rango que el calendario del [SelectorFecha] puede tocar. Al crear, no
  /// hay tope inferior estricto y el superior es hoy (regla de que un gasto
  /// no puede ser futuro). Al editar, el rango se acota al ciclo del
  /// movimiento — así el calendario **físicamente no deja salir del
  /// ciclo** (regla no negociable #5), y `editarFechaMovimiento` queda de
  /// respaldo por si este cálculo se equivocara.
  ({DateTime primera, DateTime ultima}) get _rangoFecha {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final paraEditar = widget.paraEditar;
    if (paraEditar == null) {
      return (primera: hoy.subtract(const Duration(days: 365)), ultima: hoy);
    }
    final ciclo = widget.perfil.calculadoraCiclo.calcularPara(paraEditar.fecha);
    final ultima = ciclo.fechaFin.isAfter(hoy) ? hoy : ciclo.fechaFin;
    return (primera: ciclo.fechaInicio, ultima: ultima);
  }

  Future<void> _registrar() async {
    final monto = Dinero.intentarDesdeTexto(_montoControlador.text);
    final categoria = _seleccionada;

    if (monto == null) {
      setState(() => _error = 'Escribe un monto válido.');
      return;
    }
    if (categoria == null) {
      setState(() => _error = 'Elige una categoría.');
      return;
    }

    final paraEditar = widget.paraEditar;
    final calculadoraCiclo = widget.perfil.calculadoraCiclo;

    if (paraEditar == null) {
      final puedeCapturar = await asegurarCicloAbierto(
        context,
        cicloId: calculadoraCiclo.calcularPara(_fecha).id,
        cicloRepositorio: widget.cicloRepositorio,
        esCaptura: true,
      );
      if (!puedeCapturar || !mounted) return;
    }

    setState(() {
      _error = null;
      _guardando = true;
    });

    final descripcion = _descripcionControlador.text.trim().isEmpty
        ? categoria.nombre
        : _descripcionControlador.text.trim();

    if (paraEditar != null && paraEditar.esAMeses) {
      // Una mensualidad: la categoría y la nota cambian en toda la compra;
      // monto, fecha y cuenta no se tocan (spec §7.3.1).
      final todos = await widget.movimientoRepositorio.listarTodos();
      Movimiento? editado;
      for (final m in mensualidadesDe(paraEditar.compraId!, todos)) {
        final cambiado = m.copyWith(categoriaId: categoria.id, descripcion: descripcion);
        await widget.movimientoRepositorio.actualizar(cambiado);
        if (m.clientId == paraEditar.clientId) editado = cambiado;
      }
      if (!mounted) return;
      Navigator.of(context).pop(editado ?? paraEditar.copyWith(categoriaId: categoria.id, descripcion: descripcion));
      return;
    }

    if (paraEditar != null) {
      final montoValido = validarMontoPositivo(
        monto,
        etiqueta: 'monto del gasto',
      );
      if (montoValido case Falla(:final mensaje)) {
        setState(() {
          _error = mensaje;
          _guardando = false;
        });
        return;
      }
      final conFecha = editarFechaMovimiento(
        movimiento: paraEditar,
        nuevaFecha: _fecha,
        calculadoraCiclo: calculadoraCiclo,
      );
      switch (conFecha) {
        case Falla(:final mensaje):
          setState(() {
            _error = mensaje;
            _guardando = false;
          });
          return;
        case Exito(:final valor):
          final editado = valor.copyWith(
            monto: monto,
            categoriaId: categoria.id,
            medio: _medio,
            descripcion: descripcion,
            cuentaId: _cuentaId,
          );
          await widget.movimientoRepositorio.actualizar(editado);
          if (!mounted) return;
          Navigator.of(context).pop(editado);
      }
      return;
    }

    final meses = _meses;
    if (meses != null) {
      final compra = crearCompraAMeses(
        compraId: _uuid.v4(),
        fecha: _fecha,
        calculadoraCiclo: calculadoraCiclo,
        total: monto,
        meses: meses,
        categoriaId: categoria.id,
        descripcion: descripcion,
        origenCaptura: OrigenCaptura.manual,
        cuentaId: _cuentaId,
      );
      switch (compra) {
        case Falla(:final mensaje):
          setState(() {
            _error = mensaje;
            _guardando = false;
          });
        case Exito(valor: final mensualidades):
          final fotoUrl = _fotoUrl;
          final primera = fotoUrl == null
              ? mensualidades.first
              : mensualidades.first.copyWith(ticketId: _uuid.v4(), fotoUrl: fotoUrl);
          for (final m in [primera, ...mensualidades.skip(1)]) {
            await widget.movimientoRepositorio.guardar(m);
          }
          await _aprenderDeLaCaptura(descripcion, categoria.id);
          if (!mounted) return;
          Navigator.of(context).pop(primera);
      }
      return;
    }

    final resultado = crearMovimiento(
      clientId: _uuid.v4(),
      fecha: _fecha,
      calculadoraCiclo: calculadoraCiclo,
      monto: monto,
      categoriaId: categoria.id,
      medio: _medio,
      descripcion: descripcion,
      origenCaptura: OrigenCaptura.manual,
    );

    switch (resultado) {
      case Falla(:final mensaje):
        setState(() {
          _error = mensaje;
          _guardando = false;
        });
      case Exito(:final valor):
        final fotoUrl = _fotoUrl;
        final conCuenta = valor.copyWith(cuentaId: _cuentaId);
        final aGuardar = fotoUrl == null
            ? conCuenta
            : conCuenta.copyWith(ticketId: _uuid.v4(), fotoUrl: fotoUrl);
        await widget.movimientoRepositorio.guardar(aGuardar);
        await _aprenderDeLaCaptura(descripcion, categoria.id);
        if (!mounted) return;
        Navigator.of(context).pop(aGuardar);
    }
  }

  /// Cada captura confirma o corrige la sugerencia (§6.2): con el tiempo,
  /// las reglas que el usuario más repite ganan por contador cuando hay
  /// empate en especificidad (ver `_mejorCoincidenciaRegla`).
  Future<void> _aprenderDeLaCaptura(
    String descripcion,
    String categoriaId,
  ) async {
    final actualizadas = registrarCorreccion(
      reglasActuales: _reglasCache,
      patron: descripcion,
      categoriaId: categoriaId,
    );
    if (identical(actualizadas, _reglasCache)) return;
    await widget.reglasAprendidasRepositorio.guardarTodas(actualizadas);
  }

  Future<void> _elegirFoto(ImageSource origen) async {
    final archivo = await ImagePicker().pickImage(
      source: origen,
      imageQuality: 85,
    );
    if (archivo == null || !mounted) return;
    setState(() => _cargandoFoto = true);
    final ruta = await guardarFotoTicket(
      File(archivo.path),
      documentos: widget.documentos,
    );
    if (!mounted) return;
    setState(() {
      _fotoUrl = ruta;
      _cargandoFoto = false;
    });
  }

  Future<void> _mostrarOpcionesFoto() async {
    final origen = await mostrarHoja<ImageSource>(
      context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen != null) await _elegirFoto(origen);
  }

  Future<void> _dividirTicket() async {
    final fotoUrl = _fotoUrl;
    if (fotoUrl == null) return;
    final registrados = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaDividirTicket(
          fotoUrl: fotoUrl,
          totalInicial: Dinero.intentarDesdeTexto(_montoControlador.text),
          fechaInicial: _fecha,
          perfil: widget.perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
        ),
      ),
    );
    if (registrados == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _dictar() async {
    // En la web el micrófono se abre aquí, todavía dentro del toque: Safari
    // no lo deja abrir después de una espera (ver `DictadoWeb`).
    final dictadoWeb = kIsWeb ? DictadoWeb.iniciar() : null;
    final categorias = await _categorias;
    if (!mounted) {
      dictadoWeb?.cancelar();
      return;
    }
    final dictado = await mostrarHojaDictado(context, categorias: categorias, dictadoWeb: dictadoWeb);
    if (dictado == null) return;
    if (!mounted) return;
    final gastos = dictado.gastos;

    if (gastos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No entendí ningún gasto. Intenta de nuevo.'),
        ),
      );
      return;
    }

    final unico = gastos.length == 1 ? gastos.single : null;
    if (unico != null && !unico.esAmbiguo) {
      // El mismo intérprete que Siri (spec §5.6.3): además del monto,
      // entiende la fecha ("ayer", "el lunes") y la cuenta ("con la BBVA").
      final ctx = ContextoDictado(
        categorias: categorias,
        cuentas: _cuentas,
        cuentaPorOmision: _cuentaId,
        hoy: DateTime.now(),
        reglas: _reglasCache,
        historialComercios: _historialComercios,
      );
      final g = interpretarFraseGasto(dictado.texto, ctx);
      final monto = g.monto ?? unico.monto!;
      setState(() {
        _montoControlador.text = textoEditableDeDinero(monto);
        _descripcionControlador.text = g.descripcion.isEmpty ? unico.descripcion : g.descripcion;
        if (g.cuentaDicha && g.cuentaId != null) {
          _elegirCuenta(_cuentas.firstWhere((c) => c.id == g.cuentaId));
        } else {
          _elegirMedio(unico.medio);
        }
        if (g.fechaDicha) _fecha = g.fecha;
        _error = null;
        final categoriaId = g.categoriaId ?? unico.categoriaId;
        if (categoriaId != null) {
          for (final c in categorias) {
            if (c.id == categoriaId) {
              _seleccionada = c;
              break;
            }
          }
        }
      });
      // Sin categoría: la IA (Apple en el iPhone, o el complemento activo)
      // solo la resalta, como en la nota (§6.5); nunca guarda sola.
      if (g.categoriaId == null && unico.categoriaId == null && widget.servicioIA != null) {
        final ia = await iaParaDictado(widget.servicioIA!);
        if (ia == null) return;
        final conIA = completarConIA(g.copyWith(monto: monto), await ia(dictado.texto, ctx), ctx);
        if (!mounted || conIA.categoriaId == null || _categoriaTocadaManualmente) return;
        _resaltar(conIA.categoriaId!, porIA: true);
      }
      return;
    }

    final registrados = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaRevisionDictado(
          gastos: gastos,
          fechaInicial: _fecha,
          perfil: widget.perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
        ),
      ),
    );
    if (registrados == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Dinero? get _monto => Dinero.intentarDesdeTexto(_montoControlador.text);

  /// El teclado numérico propio (componentes/Campo.md): sin teclado del
  /// sistema, con punto y ⌫. Máximo dos decimales y nueve cifras.
  void _teclear(String tecla) {
    if (_editandoAMeses) return;
    final actual = _montoControlador.text.replaceAll(',', '');
    String nuevo;
    if (tecla == '⌫') {
      nuevo = actual.isEmpty ? '' : actual.substring(0, actual.length - 1);
    } else if (tecla == '.') {
      nuevo = actual.contains('.') ? actual : (actual.isEmpty ? '0.' : '$actual.');
    } else {
      final punto = actual.indexOf('.');
      if (punto >= 0 && actual.length - punto > 2) return;
      if (punto < 0 && actual.replaceAll('.', '').length >= 9) return;
      nuevo = actual == '0' ? tecla : '$actual$tecla';
    }
    setState(() {
      _montoControlador.text = conComasDeMiles(nuevo);
      _error = null;
    });
  }

  /// Un teclado físico (web, iPad) también escribe el monto.
  KeyEventResult _alTeclaFisica(FocusNode _, KeyEvent evento) {
    if (evento is! KeyDownEvent && evento is! KeyRepeatEvent) return KeyEventResult.ignored;
    final caracter = evento.character;
    if (evento.logicalKey == LogicalKeyboardKey.backspace) {
      _teclear('⌫');
      return KeyEventResult.handled;
    }
    if (caracter != null && RegExp(r'^[0-9.]$').hasMatch(caracter)) {
      _teclear(caracter);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Tocar una categoría guarda y cierra (dos toques: monto → categoría).
  /// Al editar solo la elige; se guarda con el botón.
  void _tocarCategoria(Categoria c) {
    setState(() {
      _seleccionada = c;
      _categoriaTocadaManualmente = true;
      _sugerida = false;
    });
    if (widget.paraEditar == null) _registrar();
  }

  String get _textoFecha {
    final hoy = DateTime.now();
    final f = DateTime(_fecha.year, _fecha.month, _fecha.day);
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    if (f == h) return 'Hoy';
    if (f == h.subtract(const Duration(days: 1))) return 'Ayer';
    return fechaCorta(_fecha);
  }

  Future<void> _elegirFecha() async {
    final rango = _rangoFecha;
    await mostrarHoja<void>(
      context,
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: StatefulBuilder(
            builder: (contexto, actualizar) => SelectorFecha(
              seleccionada: _fecha,
              onCambio: (f) {
                setState(() => _fecha = f);
                Navigator.of(contexto).pop();
              },
              primeraFecha: rango.primera,
              ultimaFecha: rango.ultima,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _elegirCuentaEnHoja() async {
    // Con varias cuentas la lista no cabía en la hoja y las de abajo (las
    // tarjetas de crédito, casi siempre) quedaban fuera de alcance: se
    // desplaza.
    final elegida = await mostrarHoja<Cuenta>(
      context,
      builder: (contexto) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(contexto).height * 0.8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Con qué pagaste?', style: Theme.of(contexto).textTheme.seccion),
              const SizedBox(height: 12),
              TarjetaApp.lista(renglones: [
                for (final c in _cuentas)
                  RenglonApp(
                    emoji: c.emoji,
                    titulo: c.nombre,
                    subtitulo: c.tipo.etiqueta,
                    derecha: c.id == _cuentaId ? Icon(Icons.check_rounded, color: ColoresApp.texto) : null,
                    onTap: () => Navigator.of(contexto).pop(c),
                  ),
              ]),
            ],
          ),
          ),
        ),
      ),
    );
    if (elegida != null) setState(() => _elegirCuenta(elegida));
  }

  Future<void> _escribirNota() async {
    await mostrarHoja<void>(
      context,
      builder: (contexto) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(contexto).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nota', style: Theme.of(contexto).textTheme.seccion),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('campo_descripcion'),
              controller: _descripcionControlador,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.of(contexto).pop(),
              decoration: const InputDecoration(hintText: 'Dónde o en qué, por ejemplo "Oxxo"'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.of(contexto).pop(), child: const Text('Listo')),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final editando = widget.paraEditar != null;
    final monto = _monto;
    final hayMonto = monto != null && monto.esPositivo;
    final cuenta = _cuentas.where((c) => c.id == _cuentaId).firstOrNull;
    final nota = _descripcionControlador.text.trim();
    final textoMonto = _montoControlador.text.isEmpty ? '0' : _montoControlador.text;
    final punto = textoMonto.indexOf('.');
    final (enteros, decimales) = punto < 0 ? (textoMonto, '') : (textoMonto.substring(0, punto), textoMonto.substring(punto));
    final estiloMonto = textos.cifraHeroe.copyWith(fontSize: 56, height: 64 / 56, color: hayMonto ? p.texto : p.textoDesactivado);

    Widget chip(IconData icono, String texto, VoidCallback? onTap, {bool desplegable = true}) => ActionChip(
          avatar: Icon(icono, size: 18, color: p.accion),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
              if (desplegable) ...[const SizedBox(width: 2), Icon(Icons.expand_more_rounded, size: 18, color: p.texto2)],
            ],
          ),
          backgroundColor: p.superficie,
          side: BorderSide(color: p.bordeControl),
          shape: const StadiumBorder(),
          labelStyle: textos.cuerpoFuerte,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          onPressed: onTap,
        );

    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _hayCambiosSinGuardar,
      child: Focus(
        autofocus: !widget.iniciarDictado,
        onKeyEvent: _alTeclaFisica,
        child: _conBordeSiHayCambios(Scaffold(
          backgroundColor: p.superficie,
          appBar: AppBar(
            backgroundColor: p.superficie,
            leading: const CloseButton(),
            centerTitle: true,
            title: Text(editando ? 'Editar gasto' : 'Nuevo gasto', style: textos.cuerpoFuerte),
            actions: [
              BotonBurbuja(icono: Icons.mic_none_rounded, tooltip: 'Dictar gasto', onPressed: _dictar),
              // En la web no hay dónde guardar fotos (spec §4.2.2).
              if (!kIsWeb)
                BotonBurbuja(
                  icono: Icons.photo_camera_outlined,
                  tooltip: 'Foto del ticket',
                  onPressed: _cargandoFoto ? null : _mostrarOpcionesFoto,
                ),
              const SizedBox(width: 4),
            ],
          ),
          // Sin margen seguro abajo: el panel del teclado llega al borde y
          // aparta él mismo sus teclas de la barra de inicio del iPhone.
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    children: [
                      Semantics(
                        label: hayMonto ? 'Monto: ${montoEnPalabras(monto)}' : 'Monto: vacío',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(r'$ ', style: textos.titulo.copyWith(color: p.texto2)),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: enteros),
                                    TextSpan(text: decimales, style: TextStyle(color: p.texto2)),
                                  ]),
                                  style: estiloMonto,
                                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          chip(Icons.calendar_today_rounded, _textoFecha, _editandoAMeses ? null : _elegirFecha,
                              desplegable: !_editandoAMeses),
                          if (cuenta != null)
                            chip(Icons.account_balance_wallet_outlined, cuenta.nombre, _editandoAMeses ? null : _elegirCuentaEnHoja,
                                desplegable: !_editandoAMeses),
                          if (_editandoAMeses)
                            chip(Icons.calendar_view_month_outlined,
                                'Mensualidad ${widget.paraEditar!.mensualidad} de ${widget.paraEditar!.meses}', null,
                                desplegable: false)
                          else if (!editando && cuenta?.tipo == TipoCuenta.credito)
                            chip(Icons.calendar_view_month_outlined, _meses == null ? 'Meses' : '$_meses meses', _elegirMeses),
                          chip(Icons.edit_outlined, nota.isEmpty ? 'Nota' : nota, _escribirNota, desplegable: false),
                        ],
                      ),
                      if (_meses case final n? when hayMonto && monto.centavos >= n) ...[
                        const SizedBox(height: 10),
                        Text(
                          '$n mensualidades de ${enPesos(repartirEnMensualidades(monto, n).last)}. '
                          'A tu presupuesto de este ciclo solo va la primera.',
                          textAlign: TextAlign.center,
                          style: textos.etiqueta,
                        ),
                      ],
                      if (_editandoAMeses) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Es parte de una compra a meses: la categoría y la nota cambian en todas sus mensualidades.',
                          textAlign: TextAlign.center,
                          style: textos.etiqueta,
                        ),
                      ],
                      if (_cargandoFoto) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
                      if (_fotoUrl != null) ...[
                        const SizedBox(height: 12),
                        _TarjetaFotoTicket(
                          fotoUrl: _fotoUrl!,
                          onQuitar: () => setState(() => _fotoUrl = null),
                          onDividir: _dividirTicket,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        !hayMonto
                            ? 'Escribe cuánto gastaste'
                            : editando
                                ? 'Elige la categoría y guarda'
                                : 'Toca la categoría y listo',
                        textAlign: TextAlign.center,
                        style: textos.etiqueta,
                      ),
                      const SizedBox(height: 10),
                      _rejillaCategorias(hayMonto),
                      if (_sugerida) ...[
                        const SizedBox(height: 8),
                        Text(
                          _sugeridaPorIA
                              ? 'Resaltada: la sugiere tu IA por la nota.'
                              : 'Resaltada: la sugerimos por tus gastos anteriores.',
                          textAlign: TextAlign.center,
                          style: textos.etiqueta,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 18, color: p.peligroTexto),
                            const SizedBox(width: 6),
                            Flexible(child: Text(_error!, style: textos.etiqueta.copyWith(color: p.peligroTexto))),
                          ],
                        ),
                      ],
                      if (editando) ...[
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _guardando || !hayMonto || _seleccionada == null ? null : _registrar,
                          child: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
                        ),
                      ],
                    ],
                  ),
                ),
                _Teclado(alTeclear: _teclear),
              ],
            ),
          ),
        )),
      ),
    );
  }

  /// Con algo capturado, el `PopScope` apaga el deslizar de iOS; la franja
  /// del borde lo devuelve y pasa por `maybePop`, que pregunta "¿Descartar?".
  Widget _conBordeSiHayCambios(Widget pantalla) => _hayCambiosSinGuardar
      ? BordeParaRegresar(alRegresar: () => Navigator.of(context).maybePop(), child: pantalla)
      : pantalla;

  /// Rejilla de 4 columnas: emoji, nombre y cuánto le queda. Sin monto, las
  /// categorías van deshabilitadas; la sugerida, resaltada.
  Widget _rejillaCategorias(bool hayMonto) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    return FutureBuilder<List<Categoria>>(
      future: _categorias,
      builder: (context, snapshot) {
        final categorias = snapshot.data ?? const <Categoria>[];
        if (snapshot.hasData && categorias.isEmpty) {
          return Text(
            'No tienes categorías todavía. Crea una desde Ajustes → Categorías.',
            textAlign: TextAlign.center,
            style: textos.etiqueta.copyWith(color: p.peligroTexto),
          );
        }
        return AnimatedOpacity(
          opacity: hayMonto ? 1 : 0.45,
          duration: Duracion.rapida,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
            children: [
              for (final c in categorias)
                _CeldaCategoria(
                  categoria: c,
                  resto: switch (c) {
                    CategoriaFija() => 'Fijo',
                    CategoriaVariable() => _textoQuedan(_quedan[c.id]),
                  },
                  // La sugerida por la nota o el dictado; si no hay, la más
                  // usada (la lista ya viene en ese orden).
                  resaltada: c.id == (_seleccionada?.id ?? categorias.first.id),
                  onTap: hayMonto && !_guardando ? () => _tocarCategoria(c) : null,
                ),
            ],
          ),
        );
      },
    );
  }

  String _textoQuedan(Dinero? quedan) {
    if (quedan == null) return '';
    return quedan.esNegativo ? 'Pasada ${enPesos(quedan.absoluto)}' : enPesos(quedan);
  }
}

class _CeldaCategoria extends StatelessWidget {
  final Categoria categoria;
  final String resto;
  final bool resaltada;
  final VoidCallback? onTap;

  const _CeldaCategoria({required this.categoria, required this.resto, required this.resaltada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: resaltada,
      label: 'Guardar en ${categoria.nombre}${resto.isEmpty ? '' : ', $resto'}',
      excludeSemantics: true,
      child: Material(
        color: p.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: resaltada ? p.accion : p.borde, width: resaltada ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle),
                  child: Text(categoria.emoji, style: textos.seccion, textScaler: TextScaler.noScaling),
                ),
                const SizedBox(height: 6),
                Text(
                  categoria.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textos.etiqueta.copyWith(color: p.texto, fontWeight: FontWeight.w600),
                ),
                if (resto.isNotEmpty)
                  Text(resto, maxLines: 1, overflow: TextOverflow.ellipsis, style: textos.etiqueta),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Teclado numérico propio: 1–9, punto, 0 y ⌫; teclas de 52 de alto.
class _Teclado extends StatelessWidget {
  final ValueChanged<String> alTeclear;

  const _Teclado({required this.alTeclear});

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    const teclas = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    // Panel propio, separado de la rejilla por un borde y esquinas
    // redondeadas arriba; cada tecla es una pastilla con su contorno.
    return Semantics(
      label: 'Teclado numérico',
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: p.superficieHundida,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radios.l)),
          border: Border(top: BorderSide(color: p.borde)),
          boxShadow: sombra1(p),
        ),
        // Las teclas quedan por encima de la barra de inicio del iPhone,
        // con aire extra. En la web de la pantalla de inicio el margen
        // seguro llega en 0, por eso el mínimo de 28.
        padding: EdgeInsets.fromLTRB(12, 12, 12, math.max(MediaQuery.viewPaddingOf(context).bottom + 12, 28)),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: [
              for (final t in teclas)
                Semantics(
                  button: true,
                  label: t == '⌫' ? 'Borrar' : (t == '.' ? 'Punto' : t),
                  excludeSemantics: true,
                  child: Material(
                    color: t == '⌫' || t == '.' ? Colors.transparent : p.superficie,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radios.m),
                      side: t == '⌫' || t == '.' ? BorderSide.none : BorderSide(color: p.borde),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => alTeclear(t),
                      child: Center(
                        child: t == '⌫'
                            ? Icon(Icons.backspace_outlined, color: p.texto)
                            : Text(t, style: textos.titulo.copyWith(fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaFotoTicket extends StatelessWidget {
  final String fotoUrl;
  final VoidCallback onQuitar;
  final VoidCallback onDividir;

  const _TarjetaFotoTicket({
    required this.fotoUrl,
    required this.onQuitar,
    required this.onDividir,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(fotoUrl),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ticket adjunto',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onDividir,
                    child: Text(
                      'Dividir en varias categorías',
                      style: Theme.of(context).textTheme.etiqueta.copyWith(
                        color: ColoresApp.texto,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: ColoresApp.medio),
              onPressed: onQuitar,
              tooltip: 'Quitar foto',
            ),
          ],
        ),
      ),
    );
  }
}

