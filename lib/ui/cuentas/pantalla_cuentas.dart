import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/repositorios/categoria_ingreso_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/cuentas/fechas_tarjeta.dart';
import '../../domain/cuentas/saldos.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/perfil.dart';
import '../comun/guia_rapida.dart';
import '../../domain/voz/monto_hablado.dart';
import '../comun/esqueleto.dart';
import '../comun/formato_dinero.dart';
import '../comun/renglon_app.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';
import 'color_saldo.dart';
import 'frase_pago.dart';
import 'hoja_transferencia.dart';
import 'pantalla_detalle_cuenta.dart';
import 'pantalla_editar_cuenta.dart';

/// Ajustes → Tus cuentas (spec-app-finanzas-v2.md §7.3.1): tarjetas y
/// efectivo, con el saldo de las que lo llevan.
class PantallaCuentas extends StatefulWidget {
  final Perfil perfil;
  final CuentaRepositorio cuentaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final MovimientoCuentaRepositorio movimientoCuentaRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;

  /// Dentro de la pestaña Patrimonio, sin barra ni botón flotante propios.
  final bool embebida;

  /// Categorías de ingreso para los abonos (spec §7.3.4); sin él, el abono
  /// no pide categoría.
  final CategoriaIngresoRepositorio? categoriaIngresoRepositorio;

  const PantallaCuentas({
    super.key,
    this.embebida = false,
    required this.perfil,
    required this.cuentaRepositorio,
    required this.movimientoRepositorio,
    required this.movimientoCuentaRepositorio,
    required this.ingresoExtraRepositorio,
    this.categoriaIngresoRepositorio,
  });

  @override
  State<PantallaCuentas> createState() => _PantallaCuentasState();
}

class _PantallaCuentasState extends State<PantallaCuentas> {
  List<(Cuenta, Dinero?)>? _cuentas;
  Patrimonio _patrimonio = const Patrimonio(
    disponible: Dinero.cero(),
    ahorros: Dinero.cero(),
    deudas: Dinero.cero(),
  );
  bool _verArchivadas = false;

  /// El pago que toca de cada tarjeta con corte y fecha de pago.
  Map<String, PagoTarjeta> _pagos = const {};

  /// Un punto por ciclo (spec §7.3.3); con menos de dos no hay gráfica.
  List<PatrimonioDeCiclo> _porCiclo = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) => mostrarGuiaRapidaPrimeraVez(context, GuiaRapida.cuentas));
  }

  Future<void> _cargar() async {
    final cuentas = await widget.cuentaRepositorio.listarTodas();
    final gastos = await widget.movimientoRepositorio.listarTodos();
    final abonos = await widget.movimientoCuentaRepositorio.listarTodos();
    if (!mounted) return;
    setState(() {
      _cuentas = [for (final c in cuentas) (c, saldoDe(c, gastos, abonos))];
      final hoy = DateTime.now();
      _pagos = {
        for (final c in cuentas) c.id: ?pagoDeTarjeta(c, gastos, abonos, hoy: hoy),
      };
      _patrimonio = calcularPatrimonio(cuentas, gastos, abonos);
      _porCiclo = patrimonioPorCiclo(
        cuentas: cuentas,
        gastos: gastos,
        movimientosCuenta: abonos,
        hoy: DateTime.now(),
        calculadora: widget.perfil.calculadoraCiclo,
        maximo: 6,
      );
    });
  }

  Future<void> _transferir() async {
    final hecha = await mostrarHojaTransferencia(
      context,
      cuentas: [for (final (c, _) in _cuentas ?? const <(Cuenta, Dinero?)>[]) c],
      repositorio: widget.movimientoCuentaRepositorio,
    );
    if (hecha == true) await _cargar();
  }

  Future<void> _nueva() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PantallaEditarCuenta(cuentaRepositorio: widget.cuentaRepositorio)),
    );
    if (creada == true) await _cargar();
  }

  Future<void> _abrir(Cuenta cuenta) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaDetalleCuenta(
          cuenta: cuenta,
          perfil: widget.perfil,
          cuentaRepositorio: widget.cuentaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          movimientoCuentaRepositorio: widget.movimientoCuentaRepositorio,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
          categoriaIngresoRepositorio: widget.categoriaIngresoRepositorio,
        ),
      ),
    );
    await _cargar();
  }

  Widget _seccion(String titulo, String? dato, List<(Cuenta, Dinero?)> cuentas) {
    if (cuentas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoSeccion(titulo: titulo, dato: dato),
        TarjetaApp.lista(renglones: [
          for (final (c, saldo) in cuentas) _FilaCuenta(cuenta: c, saldo: saldo, pago: _pagos[c.id], alTocar: () => _abrir(c)),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = _cuentas;
    final textos = Theme.of(context).textTheme;
    final todas = cuentas ?? const <(Cuenta, Dinero?)>[];
    final activas = [for (final c in todas) if (c.$1.activa) c];
    final archivadas = [for (final c in todas) if (!c.$1.activa) c];
    List<(Cuenta, Dinero?)> deTipo(Set<TipoCuenta> tipos) => [for (final c in activas) if (tipos.contains(c.$1.tipo)) c];
    final paraGastar = deTipo({TipoCuenta.efectivo, TipoCuenta.debito});
    final ahorro = deTipo({TipoCuenta.ahorro});
    final tarjetas = deTipo({TipoCuenta.credito});

    final cuerpo = cuentas == null
        ? const CargandoPantalla(formas: [Esqueleto.tarjeta(alto: 190), SizedBox(height: 12), Esqueleto.tarjeta(alto: 140)])
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              _HeroePatrimonio(total: _patrimonio.total, puntos: _porCiclo),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: activas.length < 2 ? null : _transferir,
                      child: const Text('Transferir', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _nueva,
                      child: const Text('Agregar cuenta', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
              if (activas.isEmpty) ...[
                const SizedBox(height: 24),
                Text('¿Dónde tienes tu dinero?', style: textos.seccion),
                const SizedBox(height: 4),
                Text('Agrega tus cuentas y aquí verás cómo crece.', style: textos.etiqueta),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in TipoCuenta.values)
                      ActionChip(label: Text(t.etiqueta), onPressed: _nueva),
                  ],
                ),
              ],
              _seccion('Para gastar', enPesos(_patrimonio.disponible), paraGastar),
              _seccion('Ahorro', enPesos(_patrimonio.ahorros), ahorro),
              _seccion(
                'Tarjetas',
                _patrimonio.deudas.esPositivo ? 'Debes ${enPesos(_patrimonio.deudas)}' : null,
                tarjetas,
              ),
              if (archivadas.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _verArchivadas = !_verArchivadas),
                  child: Text('${_verArchivadas ? 'Ocultar' : 'Ver'} archivadas (${archivadas.length})'),
                ),
                if (_verArchivadas)
                  TarjetaApp.lista(renglones: [
                    for (final (c, saldo) in archivadas) _FilaCuenta(cuenta: c, saldo: saldo, pago: _pagos[c.id], alTocar: () => _abrir(c)),
                  ]),
              ],
            ],
          );
    if (!widget.embebida) {
      return Scaffold(appBar: AppBar(title: const Text('Tus cuentas')), body: cuerpo);
    }
    return cuerpo;
  }
}

/// La cifra de Patrimonio (`docs/rediseno/pantallas/Patrimonio.dc.html`):
/// lo que tienes menos lo que debes, cuánto cambió contra el cierre del
/// ciclo pasado y una barra por ciclo (spec §7.3.3).
class _HeroePatrimonio extends StatelessWidget {
  final Dinero total;
  final List<PatrimonioDeCiclo> puntos;

  const _HeroePatrimonio({required this.total, required this.puntos});

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final (pesos, centavos) = partesDeMonto(total);
    final anterior = puntos.length > 1 ? puntos[puntos.length - 2] : null;
    final cambio = anterior == null ? null : total - anterior.patrimonio.total;
    // Entre el mínimo y el máximo, no desde cero: el patrimonio cambia
    // poco de un ciclo a otro y desde cero todas las barras se ven iguales.
    final valores = [for (final x in puntos) x.patrimonio.total.centavos];
    final maximo = valores.isEmpty ? 0 : valores.reduce((a, b) => a > b ? a : b);
    final minimo = valores.isEmpty ? 0 : valores.reduce((a, b) => a < b ? a : b);
    double alto(int v) => maximo == minimo ? 36 : 10 + 34 * (v - minimo) / (maximo - minimo);
    return TarjetaApp.heroe(
      etiquetaSemantica: 'Tu patrimonio: ${montoEnPalabras(total)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lo que tienes menos lo que debes', style: textos.etiqueta.copyWith(color: p.heroeTexto2)),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: pesos),
              TextSpan(text: centavos, style: textos.seccion.copyWith(color: p.heroeTexto2)),
            ]),
            style: textos.cifraHeroe.copyWith(color: total.esNegativo ? p.heroePeligro : p.heroeTexto),
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
          ),
          if (cambio != null && !cambio.esCero)
            Text(
              '${enPesos(cambio.absoluto)} ${cambio.esPositivo ? 'más' : 'menos'} que en ${anterior!.ciclo.etiqueta}',
              style: textos.cuerpoFuerte.copyWith(color: cambio.esPositivo ? p.heroeExito : p.heroeAtencion),
            ),
          if (puntos.length > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, x) in puntos.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: alto(x.patrimonio.total.centavos),
                            decoration: BoxDecoration(
                              color: x.enCurso ? p.heroeTexto : p.heroePista,
                              borderRadius: BorderRadius.circular(Radios.s),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            x.enCurso ? 'Hoy' : x.ciclo.etiqueta,
                            style: textos.etiqueta.copyWith(color: p.heroeTexto2),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaCuenta extends StatelessWidget {
  final Cuenta cuenta;
  final Dinero? saldo;
  final PagoTarjeta? pago;
  final VoidCallback alTocar;

  const _FilaCuenta({required this.cuenta, required this.saldo, required this.alTocar, this.pago});

  @override
  Widget build(BuildContext context) {
    final s = saldo;
    final lectura = s == null ? null : lecturaDeSaldo(cuenta, s);
    final disponible = lectura?.disponible;
    final p = pago;
    final linea = p == null ? null : lineaDePago(p);
    final base = cuenta.tipo == TipoCuenta.debito && !cuenta.llevaSaldo
        ? 'Débito · define su saldo'
        : cuenta.tipo == TipoCuenta.credito && disponible != null
            ? (disponible.esNegativo
                ? 'Te pasaste del límite por ${enPesos(disponible.absoluto)}'
                : 'Te quedan ${enPesos(disponible)} de crédito')
            : cuenta.tipo.etiqueta == cuenta.nombre
                ? null
                : cuenta.tipo.etiqueta;
    return RenglonApp(
      emoji: cuenta.emoji,
      titulo: cuenta.nombre,
      // La fecha de pago va primero: es lo que hay que hacer.
      subtitulo: linea == null ? base : (base == null || base == cuenta.tipo.etiqueta ? linea : '$linea · $base'),
      monto: lectura == null
          ? null
          : cuenta.tipo == TipoCuenta.credito
              ? '${lectura.etiqueta} ${lectura.monto.formateado()}'
              : lectura.monto.formateado(),
      colorMonto: lectura == null ? null : colorDeLectura(lectura),
      onTap: alTocar,
    );
  }
}
