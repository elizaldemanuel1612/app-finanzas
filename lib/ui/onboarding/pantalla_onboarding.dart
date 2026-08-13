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
import '../comun/barra_ritmo.dart';
import '../comun/tema.dart';
import '../importacion/pantalla_importar.dart';
import '../meta/selector_meta.dart';

enum _TipoCiclo { corte, mesNatural, otroDia }

/// Una de las 8 categorías sugeridas del prototipo interactivo
/// (`app-finanzas-onboarding-INTERACTIVO.html`, arreglo `CATS`).
final class _CategoriaSugerida {
  final String id;
  final String emoji;
  final String nombre;
  final int peso;
  final bool fijaSugerida;
  final int montoSugeridoPesos;

  const _CategoriaSugerida({
    required this.id,
    required this.emoji,
    required this.nombre,
    required this.peso,
    this.fijaSugerida = false,
    this.montoSugeridoPesos = 0,
  });
}

const _categoriasSugeridas = [
  _CategoriaSugerida(id: 'vivienda', emoji: '🏠', nombre: 'Vivienda', peso: 30, fijaSugerida: true, montoSugeridoPesos: 15700),
  _CategoriaSugerida(id: 'super', emoji: '🛒', nombre: 'Súper', peso: 25),
  _CategoriaSugerida(id: 'salidas', emoji: '🍿', nombre: 'Salidas', peso: 20),
  _CategoriaSugerida(id: 'auto', emoji: '🚗', nombre: 'Auto', peso: 15),
  _CategoriaSugerida(id: 'salud', emoji: '💊', nombre: 'Salud', peso: 10),
  _CategoriaSugerida(id: 'hijos', emoji: '👶', nombre: 'Hijos', peso: 14),
  _CategoriaSugerida(id: 'gimnasio', emoji: '🏋️', nombre: 'Gimnasio', peso: 4, fijaSugerida: true, montoSugeridoPesos: 700),
  _CategoriaSugerida(id: 'suscripciones', emoji: '🎵', nombre: 'Suscripciones', peso: 3, fijaSugerida: true, montoSugeridoPesos: 500),
];

const _seleccionInicial = {'vivienda', 'super', 'salidas', 'auto', 'salud'};

/// Inducción de primer uso (Bloque C): la promesa, el ciclo, el ingreso, la
/// meta y las primeras categorías en 6 pasos de `PageView`, más la marca de
/// ritmo explicada al final. Sustituye a `PantallaConfiguracionInicial`
/// (que pedía dos datos y soltaba al usuario) como paso obligatorio para
/// cuentas nuevas.
///
/// Con [soloRepaso] en `true` (Ajustes → "Cómo funciona la app") solo se
/// muestran los pasos explicativos (Bienvenida y la marca de ritmo), sin
/// volver a pedir ningún dato — [alTerminar] simplemente cierra la
/// pantalla en vez de continuar hacia el resto de la app.
class PantallaOnboarding extends StatefulWidget {
  final PerfilRepositorio perfilRepositorio;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final VoidCallback alTerminar;
  final bool soloRepaso;

  const PantallaOnboarding({
    super.key,
    required this.perfilRepositorio,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.alTerminar,
    this.soloRepaso = false,
  });

  @override
  State<PantallaOnboarding> createState() => _PantallaOnboardingState();
}

class _PantallaOnboardingState extends State<PantallaOnboarding> {
  final _controlador = PageController();
  int _paso = 0;

  // Paso 2 — ¿Cuándo empieza tu mes?
  _TipoCiclo _tipoCiclo = _TipoCiclo.corte;
  int _diaCorte = 12;

  // Paso 3 — ¿Cuánto entra al mes?
  final _ingresoControlador = TextEditingController();
  String? _errorIngreso;

  // Paso 4 — ¿Cuánto quieres apartar?
  MetaApartado? _meta = const MetaPorPorcentaje(10);

  // Paso 5 — ¿En qué se te va?
  final Set<String> _seleccionadas = {..._seleccionInicial};
  final Set<String> _marcadasComoFijas =
      {for (final c in _categoriasSugeridas) if (c.fijaSugerida) c.id};

  bool _guardando = false;
  Perfil? _perfilGuardado;

  int get _totalPasos => widget.soloRepaso ? 2 : 6;

  @override
  void dispose() {
    _controlador.dispose();
    _ingresoControlador.dispose();
    super.dispose();
  }

  Dinero? get _ingreso => Dinero.intentarDesdeTexto(_ingresoControlador.text);

  Future<void> _avanzar() async {
    if (widget.soloRepaso) {
      if (_paso == 0) {
        setState(() => _paso = 1);
        await _controlador.animateToPage(1, duration: const Duration(milliseconds: 250), curve: Curves.ease);
        return;
      }
      widget.alTerminar();
      return;
    }

    if (_paso == 2) {
      final ingreso = _ingreso;
      if (ingreso == null || !ingreso.esPositivo) {
        setState(() => _errorIngreso = 'Escribe cuánto entra en un mes normal, ej. 87000.');
        return;
      }
      setState(() => _errorIngreso = null);
    } else if (_paso == 3) {
      await _guardarPerfil();
    } else if (_paso == 4) {
      await _guardarCategoriasSeleccionadas();
    } else if (_paso == 5) {
      widget.alTerminar();
      return;
    }

    if (!mounted) return;
    setState(() => _paso += 1);
    await _controlador.animateToPage(_paso, duration: const Duration(milliseconds: 250), curve: Curves.ease);
  }

  Future<void> _retroceder() async {
    if (_paso == 0) return;
    final destino = widget.soloRepaso ? 0 : _paso - 1;
    setState(() => _paso = destino);
    await _controlador.animateToPage(destino, duration: const Duration(milliseconds: 250), curve: Curves.ease);
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

  /// Regla no negociable #10: las fijas se respetan tal cual, solo el
  /// sobrante se reparte entre las variables con [repartirPorPesos].
  Dinero _disponibleParaCategorias() {
    final ingreso = _ingreso ?? const Dinero.cero();
    final meta = _meta?.montoPara(ingreso) ?? const Dinero.cero();
    final disponible = ingreso - meta;
    return disponible.esNegativo ? const Dinero.cero() : disponible;
  }

  Dinero _totalFijasSeleccionadas() => Dinero.suma([
        for (final c in _categoriasSugeridas)
          if (_seleccionadas.contains(c.id) && _marcadasComoFijas.contains(c.id))
            Dinero.pesos(c.montoSugeridoPesos),
      ]);

  Map<String, Dinero> _montosCalculados() {
    final variables = [
      for (final c in _categoriasSugeridas)
        if (_seleccionadas.contains(c.id) && !_marcadasComoFijas.contains(c.id)) c,
    ];
    final disponible = _disponibleParaCategorias();
    final totalFijas = _totalFijasSeleccionadas();
    final disponibleParaVariables = disponible - totalFijas;
    final repartido = repartirPorPesos(
      disponibleParaVariables.esNegativo ? const Dinero.cero() : disponibleParaVariables,
      variables.map((c) => c.peso).toList(),
    );

    final montos = <String, Dinero>{};
    for (final c in _categoriasSugeridas) {
      if (!_seleccionadas.contains(c.id)) continue;
      if (_marcadasComoFijas.contains(c.id)) {
        montos[c.id] = Dinero.pesos(c.montoSugeridoPesos);
      }
    }
    for (var i = 0; i < variables.length; i++) {
      montos[variables[i].id] = repartido[i];
    }
    return montos;
  }

  Future<void> _guardarCategoriasSeleccionadas() async {
    setState(() => _guardando = true);
    final montos = _montosCalculados();
    for (final c in _categoriasSugeridas) {
      final monto = montos[c.id];
      if (monto == null || !monto.esPositivo) continue;
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
    final paginas = widget.soloRepaso
        ? [_PaginaBienvenida(soloRepaso: true), _paginaRitmo()]
        : [
            _PaginaBienvenida(soloRepaso: false),
            _paginaCiclo(),
            _paginaIngreso(),
            _paginaMeta(),
            _paginaCategorias(),
            _paginaRitmo(),
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
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _paso ? ColoresApp.violeta : ColoresApp.linea,
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
                  if (_paso > 0)
                    TextButton(onPressed: _guardando ? null : _retroceder, child: const Text('Atrás')),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _guardando ? null : _avanzar,
                    child: Text(_textoBoton()),
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
    if (widget.soloRepaso) return _paso == 0 ? 'Siguiente' : 'Cerrar';
    return switch (_paso) {
      5 => 'Empezar',
      _ => 'Siguiente',
    };
  }

  Widget _paginaCiclo() {
    void elegir(_TipoCiclo t) => setState(() => _tipoCiclo = t);
    void cambiarDia(int delta) => setState(() => _diaCorte = (_diaCorte + delta).clamp(1, 31));

    return _Paso(
      titulo: '¿Cuándo empieza tu mes?',
      subtitulo: 'Así sabemos de qué día a qué día va cada ciclo.',
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
      titulo: '¿Cuánto entra al mes?',
      subtitulo: 'Pon lo de un mes normal — los ingresos extra se registran aparte, '
          'cuando lleguen.',
      child: Column(
        children: [
          TextField(
            controller: _ingresoControlador,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Ej. 87000'),
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
      subtitulo: 'Lo puedes cambiar cuando quieras — esto solo te da un punto de partida.',
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
    final totalFijas = _totalFijasSeleccionadas();
    final total = Dinero.suma(montos.values);
    final fijasSeComenElDisponible = totalFijas > disponible;

    return _Paso(
      titulo: '¿En qué se te va?',
      subtitulo: 'Elige las que apliquen — reparto lo disponible entre ellas.',
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
                    TextButton(
                      onPressed: () => setState(() {
                        if (_marcadasComoFijas.contains(c.id)) {
                          _marcadasComoFijas.remove(c.id);
                        } else {
                          _marcadasComoFijas.add(c.id);
                        }
                      }),
                      child: Text(_marcadasComoFijas.contains(c.id) ? 'Fijo' : 'Varía'),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        (montos[c.id] ?? const Dinero.cero()).formateado(),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
          if (fijasSeComenElDisponible) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColoresApp.ambarSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Tus categorías fijas (${totalFijas.formateado()}) ya se pasan de lo '
                'disponible (${disponible.formateado()}). Puedes ajustar montos después, '
                'en Categorías.',
                style: const TextStyle(color: ColoresApp.ambarTexto),
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
            descripcion: 'ejemplo',
          ),
          const SizedBox(height: 16),
          const Text(
            'La línea marca dónde deberías ir hoy. Si la barra no llega, vas bien. '
            'Si la rebasa, vas rápido y te avisamos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColoresApp.medio),
          ),
          if (!widget.soloRepaso) ...[
            const SizedBox(height: 24),
            const Text('¿Traes historial?', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _irAImportar, child: const Text('Importar mi historial')),
          ],
        ],
      ),
    );
  }
}

// Estado neutral solo para dibujar el ejemplo de BarraRitmo del paso 6 —
// no representa ninguna categoría real.
const _estadoRitmoDeEjemplo = EstadoRitmo.justo;

class _PaginaBienvenida extends StatelessWidget {
  final bool soloRepaso;

  const _PaginaBienvenida({required this.soloRepaso});

  @override
  Widget build(BuildContext context) {
    return _Paso(
      titulo: 'Sabe si vas a pasarte antes de que pase',
      subtitulo: soloRepaso ? 'Un repaso rápido de cómo funciona.' : 'Toma 2 minutos.',
      child: const SizedBox.shrink(),
    );
  }
}

class _Paso extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget child;

  const _Paso({required this.titulo, required this.subtitulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ColoresApp.medio),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}
