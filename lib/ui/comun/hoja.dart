import 'package:flutter/material.dart';

/// La única forma de abrir una hoja inferior en la app (2026-11-15).
///
/// `showModalBottomSheet` a secas limita la hoja a 9/16 de la pantalla y
/// recorta lo que no cabe — en un iPhone con letra grande se perdía la
/// mitad del botón "Ver ingresos del ciclo". Aquí la hoja puede crecer
/// hasta debajo de la barra de estado (`useSafeArea`) y, si aun así no
/// cabe, se desplaza: nunca se corta.
///
/// [desplazable] en `false` es solo para hojas que ya manejan su propio
/// desplazamiento (un `ListView` dentro de un `Flexible`, por ejemplo), que
/// dentro de otro desplazamiento no tendrían altura.
///
/// El teclado se descuenta aquí, **fuera** del desplazamiento: así la zona
/// visible de la hoja termina arriba del teclado y el campo que se enfoca
/// se desplaza solo a la vista. Si cada hoja sumaba el teclado como relleno
/// dentro de su contenido, el campo "se veía" para Flutter aunque estuviera
/// tapado (la nota de "Aportar a tu ahorro" quedaba bajo el teclado). Al
/// contenido le llega `viewInsets` en cero, para que nadie lo sume dos veces.
///
/// `test/estilos_ui_test.dart` vigila que nadie llame a
/// `showModalBottomSheet` fuera de este archivo.
Future<T?> mostrarHoja<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool desplazable = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (contexto) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(contexto).bottom),
        child: MediaQuery.removeViewInsets(
          context: contexto,
          removeBottom: true,
          child: Builder(
            builder: (contenido) => desplazable ? SingleChildScrollView(child: builder(contenido)) : builder(contenido),
          ),
        ),
      ),
    );
