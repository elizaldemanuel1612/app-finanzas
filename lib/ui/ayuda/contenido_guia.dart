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
  resumen: 'Lo primero que ves: cuánto llevas gastado y qué atender.',
  bloques: [
    Parrafo(
      'La tarjeta de arriba dice cuánto **Llevas gastado** en tus categorías '
      'variables este ciclo y de cuánto, con la barra y cuánto te queda. Arriba '
      'trae cómo vas (**Vas bien**, **Vas rápido** o **Te pasaste**) y abajo tu '
      'meta del ciclo.',
    ),
    Parrafo(
      'Si alguna categoría va a pasarse, aparece un solo aviso con la '
      'categoría de donde puedes cubrirlo.',
    ),
    Subtitulo('Presupuesto'),
    Parrafo(
      'Tus categorías variables, primero las que necesitan tu atención. '
      'Cada renglón dice cuánto te queda y trae su marca de ritmo. Al final, '
      'el renglón **Fijos** dice si tus pagos fijos están al día.',
    ),
    Ejemplo(EjemploGuia.tarjetaAtencion, pie: 'Cada renglón trae su propia marca de ritmo.'),
    Parrafo(
      'Abajo está la barra con **Inicio**, **Gastos**, el **+** dorado para '
      'registrar, **Análisis** y **Patrimonio** (tus cuentas y tus objetivos '
      'de ahorro). Ajustes se abre con el círculo de arriba a la derecha.',
    ),
  ],
);

const _temaRegistrarGasto = TemaGuia(
  id: 'registrar-gasto',
  emoji: '✍️',
  titulo: 'Registrar un gasto',
  resumen: 'Monto y categoría: dos toques y queda guardado.',
  bloques: [
    Pasos([
      'Toca el + dorado y escribe el monto con el teclado.',
      'Toca la categoría: el gasto se guarda y la pantalla se cierra.',
    ]),
    Parrafo(
      'Arriba de las categorías están los chips de **fecha**, **cuenta** y '
      '**nota**. Si el gasto no fue hoy o lo pagaste con otra cuenta, '
      'cámbialos antes de tocar la categoría.',
    ),
    Ejemplo(EjemploGuia.chipsDeFecha, pie: 'Al tocar la fecha eliges hoy, ayer u otro día.'),
    Subtitulo('La categoría se sugiere sola'),
    Parrafo(
      'Si escribes una nota, como "Oxxo", la app resalta la categoría que '
      'cree que es; si no, la que más usas. Aprende de lo que corriges y '
      'con el tiempo acierta más seguido.',
    ),
    Nota(
      tono: TonoNota.info,
      etiqueta: 'SIN CONEXIÓN',
      texto: 'Los gastos se guardan en tu teléfono: puedes registrarlos sin '
          'señal y no se pierden.',
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
      '"480 de súper con la BBVA ayer", y la app entiende monto, categoría, '
      'cuenta y fecha de un jalón. Si no dices la cuenta o el día, usa la '
      'de siempre y hoy.',
    ),
    Parrafo(
      'Antes de guardar, la pantalla **Lo que entendí** te muestra cómo se '
      'interpretó lo que dijiste, para que confirmes o corrijas.',
    ),
    Subtitulo('Con Siri, sin abrir la app'),
    Parrafo(
      'En el iPhone di "Oye Siri, registra un gasto en MAVfin". Siri te '
      'pregunta qué gastaste; contesta como lo dictarías, por ejemplo '
      '"230 en el súper con la BBVA". Si falta el monto o la categoría, te '
      'la pregunta; luego te dice lo que entendió y lo registra cuando le '
      'dices que sí. Al final te dice cuánto te queda en esa categoría.',
    ),
    Parrafo(
      'También puedes preguntarle "¿Cuánto llevo gastado en MAVfin?". Para '
      'registrar, el iPhone tiene que estar desbloqueado.',
    ),
    Parrafo(
      'Si tienes Apple Intelligence, la app la usa para elegir la categoría '
      'cuando no la dices; corre dentro de tu iPhone, así que lo que dices '
      'no sale de él. El monto, la cuenta y la fecha siempre los toma de lo '
      'que dijiste.',
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
  titulo: 'Gastos',
  resumen: 'Todos los gastos del ciclo, para buscar y corregir.',
  bloques: [
    Parrafo(
      'La pestaña Gastos lista los gastos del ciclo agrupados por día. '
      'Arriba eliges otro ciclo para ver los anteriores. El buscador dice '
      '**Buscar gasto o monto**: encuentra por descripción, categoría o cantidad.',
    ),
    Parrafo(
      'Los chips de abajo del buscador filtran por categoría o por cuenta, '
      'y se combinan. El total de arriba es el de lo filtrado.',
    ),
    Subtitulo('Corregir un gasto'),
    Vinetas([
      'Tócalo para editarlo.',
      'Deslízalo a la izquierda para eliminarlo — en realidad se anula, '
          'nada se borra de verdad — y si te equivocaste, toca **Deshacer**.',
      'Deslízalo a la derecha para duplicarlo con la fecha de hoy.',
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
      'En Ajustes → **Categorías y presupuestos** puedes crear una nueva '
      'o editar una existente en cualquier momento.',
    ),
    Subtitulo('Sin presupuesto'),
    Parrafo(
      'Si no quieres presupuestar, deja una variable en \$0: la app solo te '
      'dice cuánto llevas en ella, sin barra ni "te pasaste". Si todas '
      'están en \$0, Inicio te muestra lo que llevas gastado y lo que te '
      'entró. Al empezar puedes elegir **Solo quiero registrar mis gastos**.',
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
          'idea detrás de "eliminar" un gasto en Gastos.',
    ),
  ],
);

const _temaSalirseDeControl = TemaGuia(
  id: 'salirse-de-control',
  emoji: '🧭',
  titulo: 'Si algo se te sale de control',
  resumen: 'El cierre estimado y cómo cubrir lo que te pasaste.',
  bloques: [
    Parrafo(
      'Al tocar una categoría ves cuánto te queda, lo gastado y, en **Al '
      'cierre**, cuánto se estima que gastarás al terminar el ciclo según '
      'cómo has gastado en ciclos pasados. Con poca historia la cifra lleva '
      'una tilde (~): es un estimado preliminar.',
    ),
    Subtitulo('Cubrir lo que te pasaste'),
    Parrafo(
      'Si una categoría se pasó, la app te propone de cuál otra cubrirlo: '
      'la que más espacio tiene. Con el botón **Mover** pasas ese dinero de '
      'una vez; con **Elegir otra categoría** escoges tú de dónde, en la '
      'pantalla **Mover presupuesto**.',
    ),
    Nota(
      tono: TonoNota.info,
      etiqueta: 'SOLO ESTE CICLO',
      texto: 'Mover presupuesto no cambia tu presupuesto de siempre: solo '
          'aplica al ciclo en curso.',
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
    Subtitulo('Categorías de ingreso'),
    Parrafo(
      'Además de las categorías de gasto hay categorías de **ingreso**: de '
      'dónde te entra dinero (Nómina, Rentas, Inversiones…). Están en la '
      'misma pantalla de Categorías: arriba cambias entre **Gastos** e '
      '**Ingresos**, y el + crea del tipo que estés viendo.',
    ),
    Parrafo(
      'Al registrar un abono en una cuenta (Patrimonio → tu cuenta → '
      '**Registrar abono**) eliges en **¿De dónde viene?** una categoría de '
      'ingreso y, si quieres, escribes una nota. Al registrar un gasto solo '
      'ves categorías de gasto. En Análisis → **Ingresos**, bajo **Te entraron**, '
      'ves cuánto entró por cada categoría, contra lo que gastaste, mes por mes '
      'y a qué cuenta.',
    ),
  ],
);

const _temaCiclos = TemaGuia(
  id: 'ciclos',
  emoji: '🔁',
  titulo: 'Ciclos',
  resumen: 'Cerrar, reabrir y ver cómo te fue en meses pasados o en el año.',
  bloques: [
    Parrafo(
      'Cerrar un ciclo congela sus cifras: el pronóstico y el reparto ya '
      'no cambian con el tiempo, quedan fijos como quedó ese mes. Un '
      'ciclo cerrado se puede reabrir desde Gastos si necesitas corregir algo.',
    ),
    Subtitulo('Historial'),
    Parrafo(
      'En Análisis → **Historial** está la gráfica '
      '**Cuánto has apartado por ciclo**, con tu acumulado y el promedio '
      'de alcance de tu meta a lo largo del tiempo.',
    ),
    Subtitulo('Más allá de un ciclo'),
    Parrafo(
      'En Análisis → **Periodo** ves cuánto gastaste en **Este año**, los '
      '**Últimos 12 meses**, el **Año pasado** o entre las fechas que elijas: '
      'el total, cuánto al mes en promedio, mes por mes, por categoría y, si '
      'ya registrabas entonces, contra las mismas fechas del año anterior.',
    ),
    Parrafo(
      'Y en Análisis → Detalle, **Lo que se repite** junta lo que pagas cada '
      'semana, quincena, mes o año con la misma descripción —Netflix, el '
      'gimnasio, la colegiatura—, cuándo toca el próximo y cuánto suma al año.',
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
      '**Exportar mis gastos** genera un CSV con todo tu historial —incluido '
      'lo anulado, y el emoji y presupuesto de cada categoría—, listo para compartir, '
      'guardar aparte o volver a importar sin perder nada.',
    ),
    Subtitulo('Importar desde CSV'),
    Pasos([
      'Descarga la plantilla de ejemplo, si no tienes tu propio archivo. '
          'Solo fecha y monto son obligatorios; las demás columnas pueden ir vacías.',
      'Elige tu CSV desde Ajustes → Importar gastos.',
      'Revisa la vista previa antes de confirmar — no se guarda nada '
          'hasta que aceptas.',
    ]),
    Nota(
      tono: TonoNota.tip,
      etiqueta: 'REEMPLAZA TUS DATOS',
      texto: 'Al importar, tus gastos y categorías quedan iguales al archivo: '
          'lo que no venga en él se elimina. La vista previa te dice cuánto '
          'antes de confirmar. Si quieres conservarlo, exporta primero.',
    ),
    Subtitulo('Eliminar cuenta'),
    Parrafo(
      'Todo lo que registras vive en tu teléfono, no en un servidor. '
      'Eliminar tu cuenta borra ese historial de este dispositivo — la '
      'app te ofrece exportar antes, por si acaso.',
    ),
    Subtitulo('Complementos de IA'),
    Parrafo(
      'En Ajustes → **Complementos de IA** conectas tu propia IA: Apple '
      'Intelligence en el iPhone (gratis, sin clave) o una clave gratuita de '
      'Gemini. La clave se queda solo en tu teléfono y la app le habla '
      'directo a tu IA; nunca ve tus gastos ni tus saldos.',
    ),
    Vinetas([
      '**Pregúntale a tu IA** (en Ajustes → Ayuda y arriba en esta guía) te '
          'contesta cómo hacer algo o dónde está un botón, con base en esta guía.',
      '**Sugerir categorías**: al escribir la nota de un gasto que la app no '
          'reconoce, tu IA resalta la categoría que cree; tú decides al tocarla.',
      '**Dejar que tu IA vea tus números** (apagado de fábrica): con él '
          'encendido puedes preguntarle cuánto llevas, cuánto te queda en una '
          'categoría o cómo van tus objetivos. La app le pasa un resumen ya '
          'calculado, nunca cada gasto. Con Apple Intelligence no sale de tu '
          'iPhone; con Gemini ese resumen se manda a Google.',
    ]),
  ],
);

const _temaCuentasYTarjetas = TemaGuia(
  id: 'cuentas-y-tarjetas',
  emoji: '💳',
  titulo: 'Cuentas y tarjetas',
  resumen: 'Con qué pagas, cuánto tienes y cuánto debes en cada tarjeta.',
  bloques: [
    Parrafo(
      'En **Patrimonio** → Cuentas das de alta con **Agregar cuenta** tu '
      'efectivo, tus tarjetas de débito y de crédito, y tu ahorro o '
      'inversiones. Al registrar un gasto eliges con cuál pagaste; la app '
      'propone la última que usaste.',
    ),
    Vinetas([
      '**Débito:** cada gasto se descuenta de su saldo. Los depósitos se '
          'registran con **Registrar abono** y, si cuadras contra tu banco, '
          'con **Ajustar saldo**.',
      '**Efectivo:** si quieres, llevas cuánto traes.',
      '**Crédito:** activa **Llevar lo que debes** para que cada gasto sume '
          'a tu deuda y cada pago la baje. Si tu banco dice otra cifra, '
          'corrígela con **Ajustar deuda** (sirve escribir lo que debes o tu '
          'crédito disponible).',
    ]),
    Subtitulo('Corte y fecha de pago'),
    Parrafo(
      'En una tarjeta de crédito puedes poner su **Día de corte** y su **Día '
      'límite de pago** (vienen en tu estado de cuenta). Con ellos, en Inicio '
      'te avisamos unos días antes cuánto pagar para no generar intereses y '
      'antes de qué fecha; el aviso te lleva a la tarjeta, donde **Pagar '
      'esta tarjeta** registra el pago desde tu débito.',
    ),
    Nota(
      tono: TonoNota.tip,
      etiqueta: 'PAGAR NO ES GASTAR',
      texto: 'Un pago a la tarjeta o una transferencia entre tus cuentas no '
          'es un gasto: lo gastado ya se registró al usar la tarjeta, así que '
          'no toca tus categorías ni tu presupuesto.',
    ),
  ],
);

const _temaPatrimonioYObjetivos = TemaGuia(
  id: 'patrimonio-y-objetivos',
  emoji: '🌱',
  titulo: 'Patrimonio y objetivos',
  resumen: 'Cuánto vale todo lo tuyo y para qué estás ahorrando.',
  bloques: [
    Parrafo(
      'Tu patrimonio es **Lo que tienes menos lo que debes**: tus cuentas '
      'para gastar más tu ahorro e inversiones, menos lo que debes en '
      'tarjetas. Arriba de Cuentas ves cuánto cambió contra el ciclo pasado '
      'y una barra por ciclo.',
    ),
    Parrafo(
      'Una cuenta de ahorro no se usa para pagar: le transfieres lo que '
      'apartas y, cuando cambia su valor (rendimientos de CETES, un fondo), '
      'lo corriges con **Actualizar valor**. Al cerrar un ciclo, la app te '
      'ofrece pasar lo apartado a tu ahorro.',
    ),
    Subtitulo('Apartados'),
    Parrafo(
      'Como en tu banco o en CETES, puedes separar dinero dentro de una '
      'cuenta de débito o de ahorro: entra a la cuenta y toca **Nuevo '
      'apartado**. Lo que guardas deja de estar disponible en la cuenta pero '
      'sigue siendo tuyo; desde el apartado usas **Guardar** y **Sacar** para '
      'moverlo. Tu patrimonio no cambia. Si ya no lo necesitas, **Eliminar '
      'apartado** regresa lo que tenga a su cuenta.',
    ),
    Subtitulo('Objetivos'),
    Parrafo(
      'En Patrimonio → Objetivos creas un **Nuevo objetivo** ("Viaje", '
      '"Fondo de emergencias") con su monto, su fecha y la cuenta de ahorro '
      'o el apartado donde vive. Su avance es el saldo de esa cuenta: no hay que '
      'registrarlo aparte. Arriba ves **Llevas ahorrado** de todos juntos.',
    ),
    Parrafo(
      'Cada objetivo te dice si vas a tiempo o lento para llegar a su fecha y '
      'cuánto apartar en cada ciclo, según los días que quedan de cada uno. Si ya pasó la fecha, **Cambiar fecha** lo '
      'pone al día. Desde la edición de un objetivo puedes **Archivar objetivo** '
      'o eliminarlo; el dinero de su cuenta no se toca.',
    ),
  ],
);

/// Los temas de la guía, agrupados en 5 secciones — el índice de
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
  SeccionGuia(titulo: 'Tu dinero', temas: [_temaCuentasYTarjetas, _temaPatrimonioYObjetivos]),
  SeccionGuia(titulo: 'Ciclos y datos', temas: [_temaCiclos, _temaTusDatos]),
];

/// Los temas en orden de lectura de corrido, para la navegación
/// ← Anterior / Siguiente → de `PantallaTemaGuia`.
List<TemaGuia> get temasEnOrden => [
  for (final seccion in guiaDeLaApp) ...seccion.temas,
];
