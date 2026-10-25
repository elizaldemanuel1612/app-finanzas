/// El contenido de la guía por temas (Ajustes → "Cómo funciona la app").
///
/// Igual que `modelo_guia.dart`, este archivo **no importa Flutter** a
/// propósito, para que `test/ayuda/contenido_guia_test.dart` valide el
/// contenido con `dart test`, sin dispositivo.
///
/// **Si cambias una etiqueta visible de la app, busca esa cadena aquí: la
/// guía la cita literal.** El vocabulario sigue `docs/addendum-v3-ajuste-y-ux.md`
/// §3.3 — nunca "variación", "% del presupuesto", "avance efectivo" ni
/// "registrado con éxito" — y el tono ante errores de §4.4: en
/// `salirse-de-control`, nada de regaño.
library;

import 'modelo_guia.dart';

const _temaRitmo = TemaGuia(
  id: 'ritmo',
  emoji: '📊',
  titulo: 'La marca de ritmo',
  resumen: 'La barra que resume todo: ¿vas bien o vas rápido?',
  bloques: [
    Parrafo(
      'Es el único elemento de interfaz que hay que aprender: una barra de '
      'color con una línea vertical encima. Se ve igual en Inicio, en cada '
      'categoría y en el onboarding.',
    ),
    Subtitulo('Cómo leerla'),
    Vinetas([
      'La barra de color muestra cuánto llevas gastado del presupuesto.',
      'La línea vertical marca dónde deberías ir hoy, según qué tan '
          'avanzado está el ciclo.',
      'Si la barra no llega a la línea, vas bien.',
      'Si la barra rebasa la línea, vas más rápido de lo esperado.',
    ]),
    Ejemplo(EjemploGuia.barraVasBien, pie: 'Vas bien: la barra no llega a la línea.'),
    Ejemplo(EjemploGuia.barraProyeccion, pie: 'Justo, y avisando: a este paso, no te va a alcanzar.'),
    Ejemplo(EjemploGuia.barraExcedido, pie: 'Excedido: ya gastaste más de lo presupuestado.'),
    Nota(
      tono: TonoNota.tip,
      etiqueta: 'POR QUÉ IMPORTA',
      texto: 'Con solo mirar el color y si la barra pasó la línea sabes si '
          'una categoría necesita tu atención, sin hacer cuentas.',
    ),
  ],
);

const _temaInicio = TemaGuia(
  id: 'inicio',
  emoji: '🏠',
  titulo: 'Tu pantalla de inicio',
  resumen: 'Lo primero que ves: cuánto entró, cuánto llevas y qué atender.',
  bloques: [
    Parrafo(
      'La tarjeta de arriba resume el ciclo actual: **Este ciclo entró** '
      'muestra tu ingreso del periodo, **Gastado** lo que ya registraste y '
      '**Para invertir** lo que te queda disponible.',
    ),
    Parrafo(
      'Debajo está tu tarjeta de meta, con el porcentaje de alcance de lo '
      'que quieres apartar este ciclo.',
    ),
    Subtitulo('Gastos Variables'),
    Parrafo(
      'La lista de categorías variables se ordena sola: las que van '
      'excedidas aparecen primero, para que sepas dónde mirar sin '
      'recorrer toda la lista. El encabezado siempre muestra cuánto llevas '
      'gastado de lo presupuestado para toda la sección, y puedes tocarlo '
      'para contraer o desplegar la lista.',
    ),
    Ejemplo(EjemploGuia.tarjetaAtencion, pie: 'Cada renglón trae su propia marca de ritmo.'),
    Subtitulo('Gastos fijos'),
    Parrafo(
      'Igual que Gastos Variables, el encabezado se puede contraer y '
      'siempre muestra el total pagado contra el total presupuestado. Cada '
      'categoría fija trae su estado — **Pagado**, **Pendiente** o '
      '**Excedido** — y una barra que muestra qué tanto del monto ya '
      'cubriste.',
    ),
    Parrafo(
      'El AppBar trae tres accesos directos y un botón + al centro abajo '
      'para registrar un gasto nuevo desde cualquier pantalla.',
    ),
  ],
);

const _temaRegistrarGasto = TemaGuia(
  id: 'registrar-gasto',
  emoji: '✍️',
  titulo: 'Registrar un gasto',
  resumen: 'Monto, categoría y ya — dos toques y queda guardado.',
  bloques: [
    Parrafo(
      'Escribes el monto, eliges cuándo pasó con los chips **Hoy**, '
      '**Ayer** o **📅 Otro día**, y eliges la categoría.',
    ),
    Ejemplo(EjemploGuia.chipsDeFecha, pie: 'El chip activo se marca en azul.'),
    Subtitulo('La categoría se sugiere sola'),
    Parrafo(
      'Debajo del selector de categoría puede aparecer una etiqueta '
      '**Sugerida por tus gastos anteriores**: la app aprende de las '
      'correcciones que le haces y con el tiempo acierta más seguido.',
    ),
    Vinetas([
      'Medio de pago: **Tarjeta** o **Efectivo**.',
      '**Descripción (opcional)** para anotar algo más, si quieres.',
    ]),
    Nota(
      tono: TonoNota.info,
      etiqueta: 'SIN CONEXIÓN',
      texto: 'El pie de la pantalla dice "Sin internet · se guarda y '
          'sincroniza sola": puedes registrar gastos sin señal y no se '
          'pierden.',
    ),
  ],
);

const _temaVozYTickets = TemaGuia(
  id: 'voz-y-tickets',
  emoji: '🎙️',
  titulo: 'Voz y tickets',
  resumen: 'Dicta el gasto o toma una foto del ticket.',
  bloques: [
    Parrafo(
      'Con el micrófono puedes dictar el gasto completo, por ejemplo '
      '"480 de súper con tarjeta", y la app entiende monto, categoría y '
      'medio de pago de un jalón.',
    ),
    Parrafo(
      'Antes de guardar, la pantalla **Lo que entendí** te muestra cómo se '
      'interpretó lo que dijiste, para que confirmes o corrijas.',
    ),
    Subtitulo('Fotografiar el ticket'),
    Parrafo(
      'También puedes tomarle foto a un ticket y, si el gasto se reparte '
      'entre varias categorías, usar **Dividir en varias categorías**. '
      'Las partes tienen que cuadrar exactamente con el total o la app no '
      'deja registrar el gasto.',
    ),
  ],
);

const _temaMovimientos = TemaGuia(
  id: 'movimientos',
  emoji: '📋',
  titulo: 'Movimientos',
  resumen: 'Todos los gastos del ciclo actual, para buscar y corregir.',
  bloques: [
    Parrafo(
      'Movimientos lista únicamente los gastos del ciclo en curso, '
      'agrupados por día. El buscador de arriba dice '
      '**Buscar gasto o comercio**: filtra por lo que hayas escrito en la '
      'descripción o el nombre de la categoría.',
    ),
    Parrafo(
      'Los filtros por categoría y por medio de pago muestran el total de '
      'lo filtrado, para que compares subconjuntos sin salir de la '
      'pantalla.',
    ),
    Subtitulo('Corregir un gasto'),
    Vinetas([
      'Deslizar un renglón a la izquierda lo elimina — en realidad lo '
          'anula, nada se borra de verdad.',
      'Deslizarlo a la derecha lo duplica, con la fecha de hoy.',
    ]),
    Ejemplo(EjemploGuia.deslizarMovimiento, pie: 'Izquierda elimina, derecha duplica.'),
  ],
);

const _temaCategorias = TemaGuia(
  id: 'categorias',
  emoji: '🗂️',
  titulo: 'Categorías',
  resumen: 'Fijas y variables: cómo crearlas, archivarlas y borrarlas.',
  bloques: [
    Parrafo(
      'Una categoría es **fija** (renta, suscripciones — el mismo monto '
      'cada ciclo) o **variable** (súper, salidas — con presupuesto pero '
      'el gasto real cambia). Tú declaras cuál es cada una al crearla: la '
      'app nunca lo adivina por el nombre.',
    ),
    Parrafo(
      'Desde Categorías puedes crear una nueva o editar una existente en '
      'cualquier momento.',
    ),
    Subtitulo('Archivar y eliminar'),
    Vinetas([
      'El switch de archivar la saca de las pantallas activas sin '
          'perder su historial.',
      'Eliminar una categoría con movimientos te pide reasignarlos a otra '
          'categoría antes de poder borrarla.',
    ]),
    Nota(
      tono: TonoNota.info,
      etiqueta: 'REGLA DE ORO',
      texto: 'Nada se borra de verdad en la app: se anula. Es la misma '
          'idea detrás de "eliminar" un movimiento en Movimientos.',
    ),
  ],
);

const _temaSalirseDeControl = TemaGuia(
  id: 'salirse-de-control',
  emoji: '🧭',
  titulo: 'Si algo se te sale de control',
  resumen: 'El pronóstico del cierre y cómo reacomodar el presupuesto.',
  bloques: [
    Parrafo(
      'Dentro del detalle de una categoría, **Cierre estimado** te dice '
      'cómo va a terminar el ciclo si sigues al ritmo actual, con un '
      'rango y qué tan segura está la app de esa cifra.',
    ),
    Parrafo(
      'Cuando el cierre estimado se ve apretado, la pantalla ofrece un '
      '**Plan de ajuste**: en qué categorías podrías recortar para que el '
      'ciclo cuadre.',
    ),
    Subtitulo('Mover presupuesto entre categorías'),
    Parrafo(
      'El **Rebalanceo sugerido** propone tomar presupuesto de una '
      'categoría con espacio y dárselo a la que lo necesita. Al aceptarlo '
      'con **Mover presupuesto**, el cambio es temporal — solo aplica a '
      'este ciclo, no reescribe tu presupuesto de siempre.',
    ),
  ],
);

const _temaIngresosYMeta = TemaGuia(
  id: 'ingresos-y-meta',
  emoji: '💵',
  titulo: 'Ingresos y meta de apartado',
  resumen: 'Tu ingreso base, los extras y cuánto quieres ahorrar.',
  bloques: [
    Parrafo(
      'Tu ingreso base es lo que declaraste al configurar la app. Los '
      'ingresos extra del ciclo (un bono, una venta) se registran aparte, '
      'cuando llegan.',
    ),
    Parrafo(
      'Cada ingreso extra te deja elegir a dónde va: **Todo al apartado** '
      'sube tu meta de ahorro del ciclo, **Todo a gasto** sube el '
      'presupuesto disponible para categorías.',
    ),
    Subtitulo('La meta de apartado'),
    Parrafo(
      'Puedes fijarla como un porcentaje de tu ingreso, un monto fijo, o '
      'dejarla en "lo que sobre" de tus presupuestos — la opción por '
      'defecto si no configuras nada distinto.',
    ),
  ],
);

const _temaCiclos = TemaGuia(
  id: 'ciclos',
  emoji: '🔁',
  titulo: 'Ciclos',
  resumen: 'Cerrar, reabrir y ver cómo te fue en meses pasados.',
  bloques: [
    Parrafo(
      'Cerrar un ciclo congela sus cifras: el pronóstico y el reparto ya '
      'no cambian con el tiempo, quedan fijos como quedó ese mes. Un '
      'ciclo cerrado se puede reabrir si necesitas corregir algo.',
    ),
    Subtitulo('Ciclos anteriores'),
    Parrafo(
      'La pantalla **Ciclos anteriores** trae la gráfica '
      '**Cuánto has apartado por ciclo**, con tu acumulado y el promedio '
      'de alcance de tu meta a lo largo del tiempo.',
    ),
    Parrafo(
      'Ahí también comparas tu tasa de ahorro contra tu alcance de meta, '
      'ciclo por ciclo.',
    ),
  ],
);

const _temaTusDatos = TemaGuia(
  id: 'tus-datos',
  emoji: '🔒',
  titulo: 'Tus datos',
  resumen: 'Exportar, importar y qué pasa si eliminas tu cuenta.',
  bloques: [
    Parrafo(
      '**Exportar mis gastos** genera un CSV con todo tu historial, listo '
      'para compartir o guardar aparte.',
    ),
    Subtitulo('Importar desde CSV'),
    Pasos([
      'Descarga la plantilla de ejemplo, si no tienes tu propio archivo.',
      'Elige tu CSV desde Ajustes → Importar gastos.',
      'Revisa la vista previa antes de confirmar — no se guarda nada '
          'hasta que aceptas.',
    ]),
    Nota(
      tono: TonoNota.tip,
      etiqueta: 'SIN DUPLICADOS',
      texto: 'Si vuelves a importar el mismo archivo, la app reconoce que '
          'ya lo tenía y no te duplica los movimientos.',
    ),
    Subtitulo('Eliminar cuenta'),
    Parrafo(
      'Todo lo que registras vive en tu teléfono, no en un servidor. '
      'Eliminar tu cuenta borra ese historial de este dispositivo — la '
      'app te ofrece exportar antes, por si acaso.',
    ),
  ],
);

/// Los 10 temas de la guía, agrupados en 4 secciones — el índice de
/// `PantallaGuia` recorre esta lista tal cual.
const guiaDeLaApp = <SeccionGuia>[
  SeccionGuia(titulo: 'Lo básico', temas: [_temaRitmo, _temaInicio]),
  SeccionGuia(
    titulo: 'Registrar gastos',
    temas: [_temaRegistrarGasto, _temaVozYTickets, _temaMovimientos],
  ),
  SeccionGuia(
    titulo: 'Tu plan',
    temas: [_temaCategorias, _temaSalirseDeControl, _temaIngresosYMeta],
  ),
  SeccionGuia(titulo: 'Ciclos y datos', temas: [_temaCiclos, _temaTusDatos]),
];

/// Los 10 temas en orden de lectura de corrido, para la navegación
/// ← Anterior / Siguiente → de `PantallaTemaGuia`.
List<TemaGuia> get temasEnOrden => [
  for (final seccion in guiaDeLaApp) ...seccion.temas,
];
