import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/perfil_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/meta_apartado.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/presupuesto/categorias.dart';
import '../../domain/presupuesto/reparto.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../ayuda/contenido_guia.dart';
import '../ayuda/modelo_guia.dart';
import '../ayuda/pantalla_guia.dart';
import '../comun/barra_ritmo.dart';
import '../comun/formato_dinero.dart';
import '../comun/marca.dart';
import '../comun/tema.dart';
import '../importacion/pantalla_importar.dart';
import '../meta/selector_meta.dart';

enum _TipoCiclo { corte, mesNatural, otroDia }

/// Una de las 8 categorías sugeridas del prototipo interactivo
/// (`app-finanzas-onboarding-INTERACTIVO.html`, arreglo `CATS`). Ninguna
/// trae un monto absoluto de fábrica: cada una sugiere su [porcentaje] del
/// ingreso capturado, sola, sin depender de las demás (addendum-v3-ajuste-
/// y-ux.md §2.5.1). [fijaSugerida] solo decide si arranca marcada como
/// "Fijo".
final class _CategoriaSugerida {
  final String id;
  final String emoji;
  final String nombre;
  final int porcentaje;
  final bool fijaSugerida;

  const _CategoriaSugerida({
    required this.id,
    required this.emoji,
    required this.nombre,
    required this.porcentaje,
    this.fijaSugerida = false,
  });
}

const _categoriasSugeridas = [
  _CategoriaSugerida(id: 'vivienda', emoji: '🏠', nombre: 'Vivienda', porcentaje: 30, fijaSugerida: true),
  _CategoriaSugerida(id: 'super', emoji: '🛒', nombre: 'Súper', porcentaje: 20),
  _CategoriaSugerida(id: 'salidas', emoji: '🍿', nombre: 'Salidas', porcentaje: 10),
  _CategoriaSugerida(id: 'auto', emoji: '🚗', nombre: 'Auto', porcentaje: 10),
  _CategoriaSugerida(id: 'salud', emoji: '💊', nombre: 'Salud', porcentaje: 5),
  _CategoriaSugerida(id: 'hijos', emoji: '👶', nombre: 'Hijos', porcentaje: 10),
  _CategoriaSugerida(id: 'gimnasio', emoji: '🏋️', nombre: 'Gimnasio', porcentaje: 3, fijaSugerida: true),
  _CategoriaSugerida(id: 'suscripciones', emoji: '🎵', nombre: 'Suscripciones', porcentaje: 2, fijaSugerida: true),
];

const _seleccionInicial = {'vivienda', 'super', 'salidas', 'auto', 'salud'};

/// Inducción de primer uso (Bloque C): la promesa, el ciclo, el ingreso, la
/// meta y las primeras categorías, más la marca de ritmo explicada al
/// final — un `PageView` de 7 pasos que cierra ofreciendo la guía por
/// temas. Sustituye a `PantallaConfiguracionInicial` (que pedía dos datos
/// y soltaba al usuario) como paso obligatorio para cuentas nuevas.
///
/// El último paso ofrece **Omitir** o **Ver la guía**: en ambos casos
/// [alTerminar] ya se invoca — el perfil y las categorías quedaron
/// guardados desde antes — así que "Omitir" salta solo la guía, nunca la
/// configuración.
class PantallaOnboarding extends StatefulWidget {
  final PerfilRepositorio perfilRepositorio;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final VoidCallback alTerminar;

  const PantallaOnboarding({
    super.key,
    required this.perfilRepositorio,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.alTerminar,
  });

  @override
  State<PantallaOnboarding> createState() => _PantallaOnboardingState();
}

class _PantallaOnboardingState extends State<PantallaOnboarding> {
  static const _totalPasos = 7;

  final _controlador = PageController();
  int _paso = 0;

  // Paso 1 — ¿Cuándo empieza tu mes?
  _TipoCiclo _tipoCiclo = _TipoCiclo.corte;
  // Día 1 como punto de partida neutro: no sugerir el corte de nadie.
  int _diaCorte = 1;

  // Paso 2 — ¿Cuánto entra al mes?
  final _ingresoControlador = TextEditingController();
  String? _errorIngreso;

  // Paso 3 — ¿Cuánto quieres apartar?
  MetaApartado? _meta = const MetaPorPorcentaje(10);

  // Paso 4 — ¿En qué se te va?
  final Set<String> _seleccionadas = {..._seleccionInicial};
  final Set<String> _marcadasComoFijas =
      {for (final c in _categoriasSugeridas) if (c.fijaSugerida) c.id};
  final Map<String, Dinero> _montosEditados = {};
  final Map<String, TextEditingController> _montoControladores = {
    for (final c in _categoriasSugeridas) c.id: TextEditingController(),
  };
  final Map<String, FocusNode> _montoFocos = {
    for (final c in _categoriasSugeridas) c.id: FocusNode(),
  };

  bool _guardando = false;
  Perfil? _perfilGuardado;

  @override
  void dispose() {
    _controlador.dispose();
    _ingresoControlador.dispose();
    for (final c in _montoControladores.values) {
      c.dispose();
    }
    for (final f in _montoFocos.values) {
      f.dispose();
    }
    super.dispose();
  }

  Dinero? get _ingreso => Dinero.intentarDesdeTexto(_ingresoControlador.text);

  Future<void> _avanzar() async {
    FocusScope.of(context).unfocus();
    if (_paso == 2) {
      final ingreso = _ingreso;
      if (ingreso == null || !ingreso.esPositivo) {
        setState(() => _errorIngreso = 'Escribe cuánto entra en un mes normal, ej. \$20,000.');
        return;
      }
      setState(() => _errorIngreso = null);
    } else if (_paso == 3) {
      await _guardarPerfil();
    } else if (_paso == 4) {
      await _guardarCategoriasSeleccionadas();
    }

    if (!mounted) return;
    setState(() => _paso += 1);
    await _controlador.animateToPage(_paso, duration: const Duration(milliseconds: 250), curve: Curves.ease);
  }

  Future<void> _retroceder() async {
    FocusScope.of(context).unfocus();
    if (_paso == 0) return;
    setState(() => _paso -= 1);
    await _controlador.animateToPage(_paso, duration: const Duration(milliseconds: 250), curve: Curves.ease);
  }

  /// "Omitir" salta solo la guía: el perfil se guardó al llegar al paso 4
  /// y las categorías al llegar al paso 5, así que [alTerminar] cierra la
  /// inducción con la configuración ya lista.
  Future<void> _omitirGuia() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cuando quieras, la guía está en Ajustes → "Cómo funciona la app".'),
        duration: Duration(seconds: 6),
      ),
    );
    widget.alTerminar();
  }

  Future<void> _verGuia() async {
    // Capturado ANTES de alTerminar(): esa llamada hace setState en
    // _ContenidoAppState (main.dart) y desmonta esta pantalla, así que
    // `context` deja de servir. El NavigatorState es el de MaterialApp y
    // sigue vivo — empujar después deja PantallaInicio abajo y la guía
    // encima, que es lo que queremos: al cerrar la guía, cae en Inicio.
    final navegador = Navigator.of(context);
    widget.alTerminar();
    await navegador.push(MaterialPageRoute(builder: (_) => const PantallaGuia()));
  }

  int get _diaEfectivo => _tipoCiclo == _TipoCiclo.mesNatural ? 1 : _diaCorte;

  Future<void> _guardarPerfil() async {
    setState(() => _guardando = true);
    final perfil = Perfil(
      diaCorte: _diaEfectivo,
      ingresoBaseMensual: _ingreso!,
      metaApartado: _meta,
    );
    await widget.perfilRepositorio.guardar(perfil);
    if (!mounted) return;
    setState(() {
      _perfilGuardado = perfil;
      _guardando = false;
    });
  }

  /// Lo que queda para categorías después de la meta. Con "Lo que sobre"
  /// (`_meta == null`) es todo el ingreso.
  Dinero _disponibleParaCategorias() {
    final ingreso = _ingreso ?? const Dinero.cero();
    final meta = _meta?.montoPara(ingreso) ?? const Dinero.cero();
    final disponible = ingreso - meta;
    return disponible.esNegativo ? const Dinero.cero() : disponible;
  }

  /// Lo que el usuario escribió a mano se respeta tal cual (regla #10); las
  /// demás sugieren su porcentaje del ingreso, cada una por su lado
  /// (addendum-v3 §2.5.1). Editar una nunca mueve las otras: lo que no se
  /// asigna queda libre para apartar.
  Map<String, Dinero> _montosCalculados() {
    final ingreso = _ingreso ?? const Dinero.cero();
    return {
      for (final c in _categoriasSugeridas)
        if (_seleccionadas.contains(c.id))
          c.id: _montosEditados[c.id] ?? porcentajeDelIngreso(ingreso, c.porcentaje),
    };
  }

  Future<void> _guardarCategoriasSeleccionadas() async {
    setState(() => _guardando = true);
    final montos = _montosCalculados();
    for (final c in _categoriasSugeridas) {
      final monto = montos[c.id];
      if (monto == null || !monto.esPositivo) {
        // Si regresó y la desmarcó, la que ya se había guardado se archiva
        // en vez de quedar activa con el monto de la primera vuelta.
        final previa = await widget.categoriaRepositorio.buscarPorId(c.id);
        if (previa != null && previa.activa) {
          await widget.categoriaRepositorio.guardar(conActiva(previa, false));
        }
        continue;
      }
      final esFija = _marcadasComoFijas.contains(c.id);
      final resultado = esFija
          ? crearCategoriaFija(
              id: c.id,
              nombre: c.nombre,
              emoji: c.emoji,
              montoFijoCentavos: monto,
              diaDelCiclo: 1,
            )
          : crearCategoriaVariable(
              id: c.id,
              nombre: c.nombre,
              emoji: c.emoji,
              presupuestoMensualCentavos: monto,
            );
      if (resultado case Exito<Categoria>(:final valor)) {
        await widget.categoriaRepositorio.guardar(valor);
      }
    }
    if (!mounted) return;
    setState(() => _guardando = false);
  }

  Future<void> _irAImportar() async {
    final perfil = _perfilGuardado;
    if (perfil == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaImportar(
          perfil: perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      const _PaginaBienvenida(),
      _paginaCiclo(),
      _paginaIngreso(),
      _paginaMeta(),
      _paginaCategorias(),
      _paginaRitmo(),
      _paginaGuia(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _totalPasos; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _paso ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: i == _paso ? ColoresApp.azul : ColoresApp.linea,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controlador,
                physics: const NeverScrollableScrollPhysics(),
                children: paginas,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (_paso == 6)
                    TextButton(onPressed: _guardando ? null : _omitirGuia, child: const Text('Omitir'))
                  else if (_paso > 0)
                    TextButton(onPressed: _guardando ? null : _retroceder, child: const Text('Atrás')),
                  if (_paso > 0) const SizedBox(width: 12),
                  // Ocupa todo el ancho que queda: antes compartía el espacio
                  // a la mitad con un Spacer y se veía angosto y corrido.
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _guardando ? null : (_paso == 6 ? _verGuia : _avanzar),
                      child: Text(_textoBoton(), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _textoBoton() {
    if (_guardando) return 'Guardando…';
    return switch (_paso) {
      0 => 'Empezar',
      6 => 'Ver la guía',
      _ => 'Siguiente',
    };
  }

  Widget _paginaCiclo() {
    void elegir(_TipoCiclo t) => setState(() => _tipoCiclo = t);
    void cambiarDia(int delta) => setState(() => _diaCorte = (_diaCorte + delta).clamp(1, 31));

    return _Paso(
      titulo: '¿Cuándo empieza tu mes?',
      subtitulo: 'Así sabemos de qué día a qué día va cada ciclo.',
      nota: 'Si cambias de tarjeta, podrás cambiarlo en Ajustes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_TipoCiclo>(
            segments: const [
              ButtonSegment(value: _TipoCiclo.corte, label: Text('Corte de tarjeta')),
              ButtonSegment(value: _TipoCiclo.mesNatural, label: Text('Mes natural')),
              ButtonSegment(value: _TipoCiclo.otroDia, label: Text('Otro día')),
            ],
            selected: {_tipoCiclo},
            onSelectionChanged: (s) => elegir(s.first),
          ),
          if (_tipoCiclo != _TipoCiclo.mesNatural) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () => cambiarDia(-1), icon: const Icon(Icons.remove_circle_outline)),
                Text('Día $_diaCorte', style: Theme.of(context).textTheme.titleMedium),
                IconButton(onPressed: () => cambiarDia(1), icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
            if (_diaCorte > 28)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'En meses cortos como febrero, tu ciclo se ajusta al último día '
                  'disponible. Las cifras siguen cuadrando.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _paginaIngreso() {
    return _Paso(
      titulo: 'Registra tu ingreso base al mes',
      subtitulo: 'Lo de un mes normal, sin extras.',
      nota: 'Después podrás cambiarlo y registrar ingresos extra.',
      child: Column(
        children: [
          TextField(
            controller: _ingresoControlador,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: formateadoresDeMonto,
            decoration: const InputDecoration(hintText: 'Ej. \$20,000'),
            onChanged: (_) {
              if (_errorIngreso != null) setState(() => _errorIngreso = null);
            },
          ),
          if (_errorIngreso != null) ...[
            const SizedBox(height: 8),
            Text(_errorIngreso!, style: const TextStyle(color: ColoresApp.coralTexto)),
          ],
        ],
      ),
    );
  }

  Widget _paginaMeta() {
    final ingreso = _ingreso ?? const Dinero.cero();
    return _Paso(
      titulo: '¿Cuánto quieres apartar?',
      subtitulo: 'Es solo un punto de partida.',
      nota: 'Podrás cambiar tu meta cuando quieras.',
      child: SelectorMeta(
        ingresoBase: ingreso,
        fijas: const [],
        variables: const [],
        metaInicial: _meta,
        onCambio: (meta) => setState(() => _meta = meta),
      ),
    );
  }

  Widget _paginaCategorias() {
    final montos = _montosCalculados();
    final disponible = _disponibleParaCategorias();
    final total = Dinero.suma(montos.values);
    final sobrepasado = total > disponible;

    for (final c in _categoriasSugeridas) {
      if (!_seleccionadas.contains(c.id)) continue;
      if (_montoFocos[c.id]!.hasFocus) continue;
      final texto = ((montos[c.id] ?? const Dinero.cero()).centavos ~/ 100).toString();
      if (_montoControladores[c.id]!.text != texto) _montoControladores[c.id]!.text = texto;
    }

    return _Paso(
      titulo: '¡Clasifiquemos tus gastos!',
      subtitulo: 'Te doy una sugerencia según tu ingreso; edítala si quieres.',
      nota: 'Después podrás agregar, editar o quitar categorías.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categoriasSugeridas.map((c) {
              final activa = _seleccionadas.contains(c.id);
              return FilterChip(
                label: Text('${c.emoji} ${c.nombre}'),
                selected: activa,
                onSelected: (v) => setState(() {
                  if (v) {
                    _seleccionadas.add(c.id);
                  } else {
                    _seleccionadas.remove(c.id);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          for (final c in _categoriasSugeridas)
            if (_seleccionadas.contains(c.id))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('${c.emoji} ${c.nombre}')),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      onPressed: () => setState(() {
                        if (_marcadasComoFijas.contains(c.id)) {
                          _marcadasComoFijas.remove(c.id);
                        } else {
                          _marcadasComoFijas.add(c.id);
                        }
                      }),
                      icon: const Icon(Icons.sync_alt, size: 16),
                      label: Text(_marcadasComoFijas.contains(c.id) ? 'Fijo' : 'Varía'),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 116,
                      child: TextField(
                        controller: _montoControladores[c.id],
                        focusNode: _montoFocos[c.id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: formateadoresDeMonto,
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(isDense: true, prefixText: r'$'),
                        onChanged: (texto) => setState(() {
                          _montosEditados[c.id] = Dinero.intentarDesdeTexto(texto) ?? const Dinero.cero();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
              Text(total.formateado(), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          Text('Disponible para categorías: ${disponible.formateado()}',
              style: Theme.of(context).textTheme.bodySmall),
          if (!sobrepasado)
            Text(
              '${_meta == null ? 'Te sobra para apartar' : 'Sin asignar'}: '
              '${(disponible - total).formateado()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (sobrepasado) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColoresApp.ambarSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tus categorías (${total.formateado()}) ya se pasan de lo disponible '
                    '(${disponible.formateado()}). Ajusta los montos arriba.',
                    style: const TextStyle(color: ColoresApp.ambarTexto),
                  ),
                  // Si cambió el ingreso después de escribir montos a mano,
                  // esto los regresa a la sugerencia por porcentaje (§2.5.1).
                  if (_montosEditados.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => setState(_montosEditados.clear),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Usar la sugerencia'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paginaRitmo() {
    return _Paso(
      titulo: 'Lo único que hay que aprender',
      subtitulo: 'Esta barra es toda la interfaz que necesitas entender.',
      child: Column(
        children: [
          const BarraRitmo(
            porcentajeUsado: 0.62,
            avanceCiclo: 0.5,
            estado: _estadoRitmoDeEjemplo,
            descripcion: 'este ejemplo',
          ),
          const SizedBox(height: 16),
          const Text(
            'La línea marca dónde deberías ir hoy. Si la barra no llega, vas bien. '
            'Si la rebasa, vas rápido y te avisamos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColoresApp.medio),
          ),
          const SizedBox(height: 24),
          const Text('¿Traes historial?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Si tienes tus gastos de meses pasados en un archivo, impórtalos. '
            'Si no, no pasa nada: también puedes hacerlo después desde Ajustes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColoresApp.medio),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _irAImportar, child: const Text('Importar mi historial')),
        ],
      ),
    );
  }

  Widget _paginaGuia() {
    final muestraTemas = temasEnOrden.take(3).toList();
    final restantes = temasEnOrden.length - muestraTemas.length;
    return _Paso(
      titulo: 'Lo que nadie lee... el instructivo',
      subtitulo: 'Siempre estará disponible en Ajustes → "Cómo funciona la app".',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final tema in muestraTemas) _RenglonTemaMuestra(tema),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'y $restantes temas más',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Estado neutral solo para dibujar el ejemplo de BarraRitmo del paso de la
// marca de ritmo — no representa ninguna categoría real.
const _estadoRitmoDeEjemplo = EstadoRitmo.justo;

class _PaginaBienvenida extends StatelessWidget {
  const _PaginaBienvenida();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _Paso(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: FondoMontanas(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 72),
                child: Column(
                  children: [
                    const EmblemaApp(tamano: 104),
                    const SizedBox(height: 12),
                    Text(nombreApp, style: textTheme.titleMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    const LemaApp(),
                    const SizedBox(height: 20),
                    Text(
                      '¡Te ayudaré a lograr tu meta de ahorro!',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tú registras en segundos. Yo te aviso a tiempo, para que llegues '
                      'a fin de ciclo con lo que querías apartar.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(color: const Color(0xFFC9D1E3)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: const [
                  _PromesaOnboarding(emoji: '⚡', texto: 'Dos toques por gasto. Monto y categoría, y ya.'),
                  SizedBox(height: 12),
                  _PromesaOnboarding(
                    emoji: '🎯',
                    texto: 'Te aviso a tiempo. Antes de que te pases, no en el estado de cuenta.',
                  ),
                  SizedBox(height: 12),
                  _PromesaOnboarding(emoji: '📱', texto: 'Todo vive en tu teléfono. No se conecta a tus bancos.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Toma 2 minutos.', textAlign: TextAlign.center, style: textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _PromesaOnboarding extends StatelessWidget {
  final String emoji;
  final String texto;

  const _PromesaOnboarding({required this.emoji, required this.texto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Text(emoji, style: theme.titleMedium)),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: theme.bodyMedium?.copyWith(color: ColoresApp.medio))),
      ],
    );
  }
}

class _RenglonTemaMuestra extends StatelessWidget {
  final TemaGuia tema;

  const _RenglonTemaMuestra(this.tema);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
        child: ExcludeSemantics(child: Text(tema.emoji, style: theme.titleMedium)),
      ),
      title: Text(tema.titulo, style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(tema.resumen),
    );
  }
}

class _Paso extends StatelessWidget {
  final String? titulo;
  final String? subtitulo;

  /// Recordatorio breve de que el dato se puede cambiar después, para que
  /// el onboarding no se sienta definitivo.
  final String? nota;
  final Widget child;

  const _Paso({this.titulo, this.subtitulo, this.nota, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          if (titulo != null) ...[
            Text(titulo!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
          ],
          if (subtitulo != null)
            Text(subtitulo!, textAlign: TextAlign.center, style: const TextStyle(color: ColoresApp.medio)),
          const SizedBox(height: 28),
          child,
          if (nota != null) ...[
            const SizedBox(height: 16),
            _NotaDespues(nota!),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NotaDespues extends StatelessWidget {
  final String texto;

  const _NotaDespues(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.azulSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 18, color: ColoresApp.azul),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ColoresApp.tinta),
            ),
          ),
        ],
      ),
    );
  }
}
