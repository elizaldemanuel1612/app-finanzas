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
      builder: (contexto) => desplazable ? SingleChildScrollView(child: builder(contexto)) : builder(contexto),
    );
