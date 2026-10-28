// Demo SIN login ni Firebase, con datos de ejemplo en memoria, para revisar
// la web en Safari del simulador (gestos, modo oscuro). No se publica:
//   flutter build web --wasm -t tool/demo_web.dart -o <carpeta>
// `?modo=oscuro` o `?modo=claro` en la URL fija la apariencia;
// `?pantalla=importar` abre directo la importación de CSV.
import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/firebase/servicio_auth.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
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
  const perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(38500));
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
