import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tema.dart';

/// Un paso de una guía rápida: qué tocar y para qué sirve.
final class PasoGuiaRapida {
  final IconData icono;
  final String titulo;
  final String texto;

  const PasoGuiaRapida(this.icono, this.titulo, this.texto);
}

/// Guías rápidas de cada apartado: lo básico en pocos pasos, la primera vez
/// que se entra (2026-11-04, addendum-v3 §3). La de registrar un gasto es
/// obligatoria al empezar porque es la base de todo lo demás; las otras se
/// pueden omitir. La guía por temas (Ajustes → Cómo funciona la app) sigue
/// siendo el manual completo.
enum GuiaRapida {
  registrarGasto('Cómo registrar un gasto', [
    PasoGuiaRapida(
      Icons.add_circle,
      'Toca el + dorado',
      'Está abajo, al centro de Inicio. Es lo que más vas a usar: cada gasto que registras alimenta '
          'tu presupuesto, tu ritmo y tus análisis.',
    ),
    PasoGuiaRapida(
      Icons.edit_outlined,
      'Escribe cuánto y elige la categoría',
      'Las categorías que más usas salen primero. Si escribes una descripción, como "Oxxo", la app '
          'intenta adivinar la categoría por ti.',
    ),
    PasoGuiaRapida(
      Icons.credit_card,
      'Elige con qué pagaste',
      'Efectivo, débito o tu tarjeta de crédito. Así el saldo de tus cuentas se actualiza solo.',
    ),
    PasoGuiaRapida(
      Icons.mic_none,
      'O díctalo',
      'Con el micrófono puedes decir "doscientos de gasolina" y la app llena el gasto. Revisa y guarda.',
    ),
    PasoGuiaRapida(
      Icons.check_circle_outline,
      'Guarda y listo',
      'Si te equivocas, en Gastos lo tocas para editarlo o lo deslizas a la izquierda para eliminarlo.',
    ),
  ]),
  gastos('Tus gastos', [
    PasoGuiaRapida(
      Icons.search,
      'Busca y filtra',
      'Escribe un comercio o un monto para encontrar un gasto. Con el botón de filtros ves solo las '
          'categorías o el medio de pago que elijas.',
    ),
    PasoGuiaRapida(Icons.touch_app_outlined, 'Toca para editar', 'Cambia el monto, la categoría, la fecha o la descripción.'),
    PasoGuiaRapida(
      Icons.swipe,
      'Desliza',
      'A la izquierda para eliminar (siempre te pregunta antes). A la derecha para duplicarlo con la '
          'fecha de hoy, útil para lo que se repite.',
    ),
  ]),
  analisis('Tu análisis', [
    PasoGuiaRapida(
      Icons.speed,
      'Básico',
      'Cómo vas en una frase, cuánto puedes gastar hoy y qué te recomendamos.',
    ),
    PasoGuiaRapida(
      Icons.insights,
      'Avanzado',
      'Tu plan contra lo real, en qué se te va, tu ritmo día a día y la comparación con ciclos pasados. '
          'Elige Variables, Fijos o Total para ver cada parte.',
    ),
    PasoGuiaRapida(
      Icons.account_balance_wallet_outlined,
      'Cuentas',
      'Cuánto salió de cada tarjeta y del efectivo en este ciclo.',
    ),
  ]),
  cuentas('Tus cuentas y tarjetas', [
    PasoGuiaRapida(
      Icons.add_card,
      'Agrega tus tarjetas',
      'Con el + das de alta tu débito, tu crédito o el efectivo. Al registrar un gasto eliges con cuál pagaste.',
    ),
    PasoGuiaRapida(
      Icons.account_balance_outlined,
      'El saldo se calcula solo',
      'En débito pones cuánto tienes hoy y cada gasto lo descuenta. Si el banco dice otra cifra, usa '
          '"Ajustar saldo".',
    ),
    PasoGuiaRapida(
      Icons.sync_alt,
      'Abonos y transferencias',
      'Registra lo que te depositan, pasa dinero entre cuentas o paga tu tarjeta. Nada de eso cuenta '
          'como gasto.',
    ),
  ]),
  categorias('Tus categorías', [
    PasoGuiaRapida(
      Icons.push_pin_outlined,
      'Fijas',
      'Lo que pagas igual cada ciclo, como la renta o el celular. Llevan monto y día de cobro.',
    ),
    PasoGuiaRapida(
      Icons.shopping_basket_outlined,
      'Variables',
      'Lo que cambia, como el súper o las salidas. Llevan un presupuesto y la app te dice si vas rápido.',
    ),
    PasoGuiaRapida(
      Icons.edit_outlined,
      'Edita o crea',
      'Toca una para cambiarla, usa el + para crear otra y deslízala a la izquierda para eliminarla.',
    ),
  ]);

  final String titulo;
  final List<PasoGuiaRapida> pasos;

  const GuiaRapida(this.titulo, this.pasos);

  String get _clave => 'guia_rapida_$name';
}

/// En las pruebas de pantalla se apagan para no tapar lo que se revisa
/// (`test/ui/flutter_test_config.dart`).
@visibleForTesting
bool guiasRapidasActivas = true;

/// Lo ya mostrado en esta sesión, por si no hay almacenamiento disponible.
final _yaMostradas = <GuiaRapida>{};

/// Muestra [guia] si es la primera vez en este dispositivo. Se guarda como
/// los avisos de gestos: es del dispositivo, no viaja en el respaldo.
/// [accionFinal] es el texto del botón del último paso que "lleva a
/// hacerlo"; devuelve `true` si el usuario lo tocó.
Future<bool> mostrarGuiaRapidaPrimeraVez(
  BuildContext context,
  GuiaRapida guia, {
  bool obligatoria = false,
  String? accionFinal,
}) async {
  if (!guiasRapidasActivas || !_yaMostradas.add(guia)) return false;
  try {
    final preferencias = SharedPreferencesAsync();
    if (await preferencias.getBool(guia._clave) == true) return false;
    await preferencias.setBool(guia._clave, true);
  } catch (_) {
    // Sin almacenamiento: al menos no se repite en esta sesión.
  }
  if (!context.mounted) return false;
  final hacerlo = await showDialog<bool>(
    context: context,
    barrierDismissible: !obligatoria,
    builder: (_) => PopScope(
      canPop: !obligatoria,
      child: _DialogoGuiaRapida(guia: guia, obligatoria: obligatoria, accionFinal: accionFinal),
    ),
  );
  return hacerlo ?? false;
}

/// Para "Ver de nuevo las guías rápidas" en Ajustes.
Future<void> reiniciarGuiasRapidas() async {
  _yaMostradas.clear();
  try {
    final preferencias = SharedPreferencesAsync();
    for (final g in GuiaRapida.values) {
      await preferencias.remove(g._clave);
    }
  } catch (_) {}
}

class _DialogoGuiaRapida extends StatefulWidget {
  final GuiaRapida guia;
  final bool obligatoria;
  final String? accionFinal;

  const _DialogoGuiaRapida({required this.guia, required this.obligatoria, this.accionFinal});

  @override
  State<_DialogoGuiaRapida> createState() => _DialogoGuiaRapidaState();
}

class _DialogoGuiaRapidaState extends State<_DialogoGuiaRapida> {
  var _indice = 0;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final pasos = widget.guia.pasos;
    final paso = pasos[_indice];
    final ultimo = _indice == pasos.length - 1;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.guia.titulo} · ${_indice + 1} de ${pasos.length}',
              textAlign: TextAlign.center,
              style: textos.labelSmall,
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                child: Icon(paso.icono, size: 36, color: ColoresApp.azul),
              ),
            ),
            const SizedBox(height: 20),
            Text(paso.titulo, textAlign: TextAlign.center, style: textos.titleMedium),
            const SizedBox(height: 8),
            Text(paso.texto, textAlign: TextAlign.center, style: textos.bodySmall),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pasos.length; i++)
                  Container(
                    width: i == _indice ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _indice ? ColoresApp.azul : ColoresApp.pista,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (ultimo && widget.accionFinal != null) ...[
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.accionFinal!)),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Lo haré después')),
            ] else
              Row(
                children: [
                  if (_indice > 0)
                    TextButton(onPressed: () => setState(() => _indice--), child: const Text('Atrás'))
                  else if (!widget.obligatoria)
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Omitir')),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => ultimo ? Navigator.pop(context, false) : setState(() => _indice++),
                    child: Text(ultimo ? 'Entendido' : 'Siguiente'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
