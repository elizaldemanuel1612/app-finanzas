import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/almacenamiento/almacen_fotos.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/clasificacion/cascada_clasificacion.dart';
import '../../domain/clasificacion/historial_comercios.dart';
import '../../domain/clasificacion/regla_aprendida.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/reglas/creacion_movimiento.dart';
import '../../domain/reglas/fecha_movimiento.dart';
import '../../domain/reglas/monto.dart';
import '../comun/asegurar_ciclo_abierto.dart';
import '../comun/formato_dinero.dart';
import '../comun/popscope_descartar.dart';
import '../comun/selector_fecha.dart';
import '../comun/tema.dart';
import 'hoja_dictado.dart';
import 'pantalla_dividir_ticket.dart';
import 'pantalla_revision_dictado.dart';

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

  @override
  void initState() {
    super.initState();
    _categorias = widget.categoriaRepositorio.listarActivas();
    _categorias.then((categorias) {
      if (mounted) setState(() => _categoriasCache = categorias);
    });
    _cargarCascada();

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
    if (!resultado.resuelto) return;
    for (final c in _categoriasCache) {
      if (c.id == resultado.categoriaId) {
        setState(() {
          _seleccionada = c;
          _sugerida = true;
        });
        break;
      }
    }
  }

  bool get _hayCambiosSinGuardar =>
      _montoControlador.text.isNotEmpty ||
      _descripcionControlador.text.isNotEmpty ||
      _seleccionada != null ||
      _fotoUrl != null;

  @override
  void dispose() {
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
          );
          await widget.movimientoRepositorio.actualizar(editado);
          if (!mounted) return;
          Navigator.of(context).pop(editado);
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
        final aGuardar = fotoUrl == null
            ? valor
            : valor.copyWith(ticketId: _uuid.v4(), fotoUrl: fotoUrl);
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
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
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
    final categorias = await _categorias;
    if (!mounted) return;
    final gastos = await mostrarHojaDictado(context, categorias: categorias);
    if (gastos == null) return;
    if (!mounted) return;

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
      setState(() {
        _montoControlador.text = textoEditableDeDinero(unico.monto!);
        _descripcionControlador.text = unico.descripcion;
        _medio = unico.medio;
        _error = null;
        if (unico.categoriaId != null) {
          for (final c in categorias) {
            if (c.id == unico.categoriaId) {
              _seleccionada = c;
              break;
            }
          }
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final rangoFecha = _rangoFecha;
    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _hayCambiosSinGuardar,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.paraEditar == null ? 'Registrar gasto' : 'Editar gasto',
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '¿Cuánto gastaste?',
                style: TextStyle(color: ColoresApp.medio),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montoControlador,
                // Con el dictado abriéndose, el teclado solo estorbaría.
                autofocus: !widget.iniciarDictado,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: formateadoresDeMonto,
                style: _estiloMonto,
                decoration: InputDecoration(
                  // prefixIcon (no prefixText): se ve siempre, también
                  // sin foco, así el campo vacío nunca parece un hueco.
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(r'$', style: _estiloMonto),
                  ),
                  prefixIconConstraints: const BoxConstraints(),
                  hintText: '0',
                  hintStyle: const TextStyle(color: ColoresApp.linea),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // En la web no hay dónde guardar fotos (spec §4.2.2).
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            color: ColoresApp.azul,
                          ),
                          tooltip: 'Foto de ticket',
                          onPressed: _cargandoFoto ? null : _mostrarOpcionesFoto,
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.mic_none,
                          color: ColoresApp.azul,
                        ),
                        tooltip: 'Dictar por voz',
                        onPressed: _dictar,
                      ),
                    ],
                  ),
                ),
              ),
              if (_cargandoFoto) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_fotoUrl != null) ...[
                const SizedBox(height: 12),
                _TarjetaFotoTicket(
                  fotoUrl: _fotoUrl!,
                  onQuitar: () => setState(() => _fotoUrl = null),
                  onDividir: _dividirTicket,
                ),
              ],
              const SizedBox(height: 16),
              SelectorFecha(
                seleccionada: _fecha,
                onCambio: (f) => setState(() => _fecha = f),
                primeraFecha: rangoFecha.primera,
                ultimaFecha: rangoFecha.ultima,
              ),
              const Divider(height: 32),
              const Text(
                'Categoría',
                style: TextStyle(color: ColoresApp.medio),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Categoria>>(
                future: _categorias,
                builder: (context, snapshot) {
                  final categorias = snapshot.data ?? const [];
                  if (snapshot.hasData && categorias.isEmpty) {
                    return const Text(
                      'No tienes categorías todavía. Crea una desde Categorías antes de registrar.',
                      style: TextStyle(color: ColoresApp.coralTexto),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categorias.map((c) {
                      final elegida = c.id == _seleccionada?.id;
                      return ChoiceChip(
                        label: Text('${c.emoji} ${c.nombre}'),
                        selected: elegida,
                        onSelected: (_) => setState(() {
                          _seleccionada = c;
                          _categoriaTocadaManualmente = true;
                          _sugerida = false;
                        }),
                      );
                    }).toList(),
                  );
                },
              ),
              if (_sugerida) ...[
                const SizedBox(height: 6),
                const Text(
                  'Sugerida por tus gastos anteriores',
                  style: TextStyle(
                    color: ColoresApp.azul,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Medio', style: TextStyle(color: ColoresApp.medio)),
              const SizedBox(height: 8),
              SegmentedButton<MedioPago>(
                segments: const [
                  ButtonSegment(
                    value: MedioPago.tarjeta,
                    label: Text('Tarjeta'),
                  ),
                  ButtonSegment(
                    value: MedioPago.efectivo,
                    label: Text('Efectivo'),
                  ),
                ],
                selected: {_medio},
                onSelectionChanged: (s) => setState(() => _medio = s.first),
              ),
              const SizedBox(height: 20),
              TextField(
                // Sin esta key, insertar el aviso "Sugerida por tus gastos
                // anteriores" arriba (cuando `_sugerida` pasa a true) corre
                // este campo dos posiciones dentro de la lista sin llaves
                // del ListView — Flutter deja de reconocerlo como el mismo
                // widget, le destruye el Element y el cursor/foco se pierde
                // a media escritura. La key le da identidad estable sin
                // importar en qué posición de la lista termine.
                key: const ValueKey('campo_descripcion'),
                controller: _descripcionControlador,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: ColoresApp.coralTexto),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _registrar,
                child: Text(
                  _guardando
                      ? 'Guardando…'
                      : (widget.paraEditar == null
                            ? 'Listo'
                            : 'Guardar cambios'),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Sin internet · se guarda y sincroniza sola',
                  style: TextStyle(color: ColoresApp.medio, fontSize: 12),
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
                    child: const Text(
                      'Dividir en varias categorías',
                      style: TextStyle(
                        color: ColoresApp.azul,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: ColoresApp.medio),
              onPressed: onQuitar,
              tooltip: 'Quitar foto',
            ),
          ],
        ),
      ),
    );
  }
}

/// Mismo estilo para la cifra capturada y su signo de pesos.
const _estiloMonto = TextStyle(fontSize: 40, fontWeight: FontWeight.w800);
