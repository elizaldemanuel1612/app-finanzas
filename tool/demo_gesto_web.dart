// Demo SIN login ni Firebase para reproducir en Safari (simulador) el gesto
// de regresar. No se publica: `flutter build web -t tool/demo_gesto_web.dart`.
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/firebase/servicio_auth.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
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
  await almacen.categorias.guardar(const CategoriaFija(
    id: 'vivienda', nombre: 'Vivienda', emoji: '🏠', activa: true, esNecesaria: true,
    montoFijoCentavos: Dinero.pesos(11550), diaDelCiclo: 1,
  ));
  await almacen.categorias.guardar(const CategoriaVariable(
    id: 'super', nombre: 'Súper', emoji: '🛒', activa: true, esNecesaria: true,
    presupuestoMensualCentavos: Dinero.pesos(7700),
  ));
  runApp(MaterialApp(
    theme: construirTema(),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('es', 'MX')],
    locale: const Locale('es', 'MX'),
    home: PantallaInicio(
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
  ));
}
