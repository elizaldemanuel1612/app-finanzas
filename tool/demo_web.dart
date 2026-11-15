// Demo SIN login ni Firebase, con datos de ejemplo en memoria, para revisar
// la web en Safari del simulador (gestos, modo oscuro). No se publica:
//   flutter build web --wasm -t tool/demo_web.dart -o <carpeta>
// `?modo=oscuro` o `?modo=claro` en la URL fija la apariencia;
// `?pantalla=importar` abre directo la importación de CSV;
// `?corte=15` cambia el día de corte (para ver un ciclo a la mitad).
import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/firebase/servicio_auth.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:app_finanzas/domain/modelos/objetivo.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/comun/apariencia.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:app_finanzas/ui/importacion/pantalla_importar.dart';
import 'package:app_finanzas/ui/inicio/pantalla_inicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final almacen = AlmacenLocal.sobre({
    for (final n in AlmacenLocal.nombresDeArchivo) n: ArchivoTextoMemoria(),
  });
  final perfil = Perfil(
    diaCorte: int.tryParse(Uri.base.queryParameters['corte'] ?? '') ?? 1,
    ingresoBaseMensual: const Dinero.pesos(38500),
  );
  await almacen.perfil.guardar(perfil);
  const categorias = [
    CategoriaFija(
      id: 'vivienda', nombre: 'Vivienda', emoji: '🏠', activa: true, esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(11550), diaDelCiclo: 1,
    ),
    CategoriaVariable(
      id: 'super', nombre: 'Súper', emoji: '🛒', activa: true, esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(7700),
    ),
    CategoriaVariable(
      id: 'salidas', nombre: 'Salidas', emoji: '🍿', activa: true, esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(3850),
    ),
    CategoriaVariable(
      id: 'auto', nombre: 'Auto', emoji: '🚗', activa: true, esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(3850),
    ),
  ];
  for (final c in categorias) {
    await almacen.categorias.guardar(c);
  }
  final inicioCiclo = perfil.calculadoraCiclo.calcularPara(DateTime.now()).fechaInicio;
  await almacen.cuentas.listarTodas(); // crea Tarjeta y Efectivo
  await almacen.cuentas.guardar(Cuenta(
    id: 'bbva',
    nombre: 'BBVA débito',
    emoji: '🏦',
    tipo: TipoCuenta.debito,
    llevaSaldo: true,
    saldoInicial: const Dinero.pesos(15000),
    fechaSaldoInicial: inicioCiclo,
  ));
  await almacen.cuentas.guardar(Cuenta(
    id: 'oro',
    nombre: 'Tarjeta oro',
    emoji: '💳',
    tipo: TipoCuenta.credito,
    llevaSaldo: true,
    saldoInicial: const Dinero.pesos(-4500),
    fechaSaldoInicial: inicioCiclo,
    limite: const Dinero.pesos(20000),
    // Para ver el aviso de pago: cortó hace unos días y vence en tres.
    diaCorte: DateTime.now().subtract(const Duration(days: 4)).day,
    diaPago: DateTime.now().add(const Duration(days: 3)).day,
  ));
  await almacen.cuentas.guardar(Cuenta(
    id: 'cetes',
    nombre: 'Cetes',
    emoji: '🌱',
    tipo: TipoCuenta.ahorro,
    llevaSaldo: true,
    saldoInicial: const Dinero.pesos(30000),
    fechaSaldoInicial: DateTime(inicioCiclo.year, inicioCiclo.month - 3, 5),
  ));
  // Un aporte por ciclo, para que el patrimonio por ciclo tenga historia.
  for (final (i, pesos) in const [3500, 4000, 4500].indexed) {
    await almacen.movimientosCuenta.guardar(MovimientoCuenta(
      clientId: 'demo-aporte-$i',
      cuentaId: 'cetes',
      fecha: DateTime(inicioCiclo.year, inicioCiclo.month - 2 + i, 2),
      monto: Dinero.pesos(pesos),
      tipo: TipoMovimientoCuenta.abono,
      entra: true,
      estado: EstadoMovimientoCuenta.activo,
    ));
  }
  await almacen.objetivos.guardar(Objetivo(
    id: 'fondo',
    nombre: 'Fondo de emergencia',
    emoji: '🛟',
    monto: const Dinero.pesos(35000),
    cuentaId: 'cetes',
    creado: inicioCiclo,
  ));
  await almacen.objetivos.guardar(Objetivo(
    id: 'viaje',
    nombre: 'Viaje a Japón',
    emoji: '🗾',
    monto: const Dinero.pesos(60000),
    cuentaId: 'cetes',
    creado: inicioCiclo,
    fechaLimite: DateTime(inicioCiclo.year, inicioCiclo.month + 8, 15),
  ));
  final hoy = DateTime.now();
  final calculadora = perfil.calculadoraCiclo;
  var n = 0;
  Future<void> gasto(int diasAtras, String categoria, int pesos, String descripcion) async {
    final fecha = hoy.subtract(Duration(days: diasAtras));
    await almacen.movimientos.guardar(Movimiento(
      clientId: 'demo-${n++}',
      fecha: fecha,
      cicloId: calculadora.calcularPara(fecha).id,
      periodoNatural: periodoNatural(fecha),
      monto: Dinero.pesos(pesos),
      categoriaId: categoria,
      medio: n.isEven ? MedioPago.tarjeta : MedioPago.efectivo,
      descripcion: descripcion,
      estado: EstadoMovimiento.activo,
      origenCaptura: OrigenCaptura.manual,
      cuentaId: n % 3 == 0 ? 'bbva' : null,
    ));
  }

  await gasto(0, 'super', 640, 'Súper de la semana');
  await gasto(0, 'salidas', 280, 'Café y pan');
  await gasto(1, 'auto', 900, 'Gasolina');
  await gasto(2, 'salidas', 1150, 'Cena');
  await gasto(3, 'super', 1890, 'Despensa');
  await gasto(5, 'vivienda', 11550, 'Renta');
  await gasto(6, 'auto', 350, 'Estacionamiento');
  await gasto(8, 'super', 760, 'Frutas y verduras');
  await gasto(12, 'salidas', 540, 'Cine');
  await gasto(35, 'super', 2100, 'Súper del mes pasado');
  await gasto(40, 'salidas', 900, 'Salida del mes pasado');
  // Pagos que se repiten, para ver "Lo que se repite" en Análisis → Detalle.
  for (final dias in [4, 34, 65, 95]) {
    await gasto(dias, 'salidas', 219, 'Netflix');
  }
  for (final dias in [10, 40, 71]) {
    await gasto(dias, 'salidas', 129, 'Spotify');
  }
  // El ciclo pasado, cerrado: para ver en Gastos cómo se consulta uno.
  final pasado = calculadora.calcularPara(hoy.subtract(const Duration(days: 40)));
  await almacen.ciclos.guardar(CicloGuardado(
    ciclo: Ciclo(
      id: pasado.id,
      fechaInicio: pasado.fechaInicio,
      fechaFin: pasado.fechaFin,
      etiqueta: pasado.etiqueta,
      estado: EstadoCiclo.cerrado,
    ),
  ));

  final modo = Uri.base.queryParameters['modo'];
  if (modo == 'oscuro') AparienciaApp.actual.value = Apariencia.oscuro;
  if (modo == 'claro') AparienciaApp.actual.value = Apariencia.claro;

  runApp(ValueListenableBuilder<Apariencia>(
    valueListenable: AparienciaApp.actual,
    builder: (context, apariencia, _) => MaterialApp(
      theme: construirTema(Paleta.clara),
      darkTheme: construirTema(Paleta.oscura),
      themeMode: apariencia.modo,
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es', 'MX')],
      locale: const Locale('es', 'MX'),
      builder: (context, child) => SincronizarPaleta(child: child!),
      home: Uri.base.queryParameters['pantalla'] == 'importar'
          ? PantallaImportar(
              perfil: perfil,
              categoriaRepositorio: almacen.categorias,
              movimientoRepositorio: almacen.movimientos,
              reglasAprendidasRepositorio: almacen.reglasAprendidas,
            )
          : PantallaInicio(
        perfil: perfil,
        categoriaRepositorio: almacen.categorias,
        movimientoRepositorio: almacen.movimientos,
        reglasAprendidasRepositorio: almacen.reglasAprendidas,
        cicloRepositorio: almacen.ciclos,
        ingresoExtraRepositorio: almacen.ingresosExtra,
        ajustePresupuestoCicloRepositorio: almacen.ajustesPresupuestoCiclo,
        perfilRepositorio: almacen.perfil,
        servicioAuth: ServicioAuth(),
        almacenLocal: almacen,
      ),
    ),
  ));
}
