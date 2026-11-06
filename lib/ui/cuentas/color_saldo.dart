import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/cuentas/saldos.dart';
import '../comun/tema.dart';

/// Lo que tienes en verde y lo que debes en rojo, en tonos apagados
/// (2026-11-06): son cifras que se ven todo el tiempo, no alarmas.
Color colorDeDinero(Dinero monto, {bool enContra = false}) {
  if (enContra || monto.esNegativo) return ColoresApp.enContra;
  return monto.esPositivo ? ColoresApp.aFavor : ColoresApp.tinta;
}

/// El color de una cuenta según [lecturaDeSaldo]: "Debes" o pasada de su
/// límite, en rojo; lo que tienes (o a tu favor), en verde.
Color colorDeLectura(LecturaSaldo lectura) =>
    colorDeDinero(lectura.monto, enContra: lectura.alerta || (lectura.etiqueta == 'Debes' && lectura.monto.esPositivo));
