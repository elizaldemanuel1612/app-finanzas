# Qué valoran los usuarios en las apps de finanzas (octubre 2026)

Investigación rápida para decidir qué llevar a App Finanzas. Fuentes: reseñas y comparativas de 2026 (NerdWallet, Forbes, The Penny Hoarder, College Investor, reseñas de tiendas) y artículos sobre apps populares en México. Muchas comparativas son de sitios con afiliados: se toman como dirección, no como ranking exacto.

## Las referencias

| App | Por qué la eligen | Lo que más se critica |
|---|---|---|
| **Copilot** | El diseño más elogiado; la "única app de finanzas que abren a diario". Detecta cargos recurrentes y los separa en pagado/pendiente; aprende de cada categoría corregida; comparaciones mes contra mes y año contra año con gráficas limpias. | Solo Apple; sin versión gratis. |
| **Monarch** | Pulida, metas, patrimonio, presupuesto compartido en pareja. | Cara para uso individual. |
| **YNAB** | Método: cada peso tiene un trabajo; mucha educación. | Curva de aprendizaje, precio. |
| **Rocket Money** | Encuentra suscripciones y ahorros. | Automatización con bancos de EE. UU. |
| **Spendee / Monefy** (populares en México) | Registro manual rápido, en pesos y en español, sin conectar bancos; carteras compartidas. | Reportes básicos. |
| **Fintonic** | Conecta bancos mexicanos, panorama general. | Requiere dar acceso bancario. |

## Lo que se repite en lo que los usuarios elogian

1. **Registrar rapidísimo.** Es lo más elogiado en apps manuales: monto, categoría y listo.
2. **Reportes visuales claros:** en qué se va el dinero (dona o barras) y cómo cambia contra el mes pasado.
3. **Avisos accionables antes de pasarse,** no el resumen cuando ya pasó.
4. **Cargos fijos/recurrentes separados** en pagado y pendiente.
5. **"Cuánto me queda"** a la vista sin hacer cuentas.
6. **Diseño limpio y fácil de navegar.**
7. **Privacidad y sin sorpresas:** cobros inesperados y muros de pago son la queja más frecuente.

## Cómo queda App Finanzas

| Lo que valoran | En la app |
|---|---|
| Captura rápida | Ya: dos toques, voz, foto, widget y Siri. |
| Reportes visuales | **Nuevo:** pestaña Análisis (spec §5.7). |
| Comparar con el mes pasado | **Nuevo:** a los mismos días transcurridos (comparación honesta). |
| Avisos accionables | Ya: marca de ritmo y plan de ajuste. **Nuevo:** recomendaciones con salida concreta. |
| Fijas pagado/pendiente | Ya, en Inicio. |
| Cuánto queda hoy | Ya en el widget. **Nuevo:** también en Inicio. |
| Diseño limpio | Ya: dirección visual premium. |
| Privacidad | Ya: todo vive en el teléfono, no se conecta a bancos. |

## Pendientes que vale la pena considerar después
- Modo oscuro.
- Recordatorios (fijas por vencer, "no has registrado hoy").
- Búsqueda por texto en Gastos.
- Presupuesto compartido en pareja (requiere la nube).

## Revisión general del 2026-11-14

Segunda vuelta al mercado (comparativas 2026 de NerdWallet, CNBC Select, Experian, Rob Berger y resúmenes de hilos de Reddit; casi todas con afiliados o de blogs de otras apps: sirven de dirección, no de ranking). Lo que se repite:

- **Lo más elogiado:** seguimiento de metas, patrimonio en un solo tablero (Empower, Monarch), "cuánto puedo gastar sin riesgo" (PocketGuard), detectar suscripciones (Rocket Money).
- **Lo más criticado:** la sincronización con bancos que se rompe (la queja número uno), el precio, categorías rígidas, que el efectivo no se registre y que todo asuma un solo usuario.
- **Lo que piden y falta en varias:** metas de ahorro con nombre, calendario de pagos, reportes por rango de fechas, sobres que pasan lo que sobra al siguiente mes.

MAVfin ya evita las tres quejas grandes (no depende de bancos, no cobra, las categorías son del usuario) y ya tiene lo de "cuánto puedo gastar hoy". Lo que faltaba, en orden de valor:

| # | Qué | Estado |
|---|---|---|
| 1 | **Ahorro, inversiones y patrimonio:** dónde vive lo que se aparta y cuánto vale todo | **Hecho 2026-11-14** (spec §7.3.2) |
| 2 | **Metas con nombre** ("Fondo de emergencia $100,000", "Viaje en junio"): progreso contra una cuenta de ahorro y cuánto apartar por ciclo para llegar a la fecha | Pendiente |
| 3 | **Patrimonio en el tiempo:** gráfica por ciclo (el saldo ya se calcula desde los movimientos; falta poder calcularlo a una fecha) | Pendiente |
| 4 | **Tarjeta de crédito: corte y fecha de pago,** con "paga antes del día X" en Inicio | Pendiente (segunda etapa de §7.3.1) |
| 5 | **Resumen del año y rango de fechas** en Análisis | Pendiente |
| 6 | **Gastos que se repiten** (suscripciones): detectarlos por descripción y monto, y cuánto suman al año | Pendiente |
| 7 | **Tema "Cuentas y patrimonio" en la guía por temas** (hoy la guía no habla de cuentas) | Pendiente |
| 8 | **Lo que sobra pasa al siguiente ciclo** por categoría (sobres) | Por decidir: cambia cómo se entiende el presupuesto |
| 9 | Recordatorios y presupuesto en pareja | En pausa: piden notificaciones nativas y nube |

## Fuentes
- https://www.nerdwallet.com/finance/learn/best-budget-apps
- https://www.forbes.com/advisor/banking/best-budgeting-apps/
- https://thecollegeinvestor.com/32672/best-budgeting-apps/
- https://www.thepennyhoarder.com/budgeting/budgeting-copilot-money-review/
- https://moneywithkatie.com/copilot-review-a-budgeting-app-that-finally-gets-it-right/
- https://walletgrower.com/compare/ynab-vs-monarch-vs-copilot
- https://www.nerdwallet.com/p/best/finance/expense-tracker-apps
- https://www.pluxee.mx/blog/las-5-mejores-apps-para-finanzas-personales-y-control-de-gastos/
- https://www.elimparcial.com/dinero/2025/02/20/las-mejores-aplicaciones-financieras-para-organizar-tu-dinero-en-mexico/
- https://uxplanet.org/case-study-home-budget-app-ui-for-finance-7b0fb9780da3
- https://www.cnbc.com/select/best-budgeting-apps
- https://www.experian.com/blogs/ask-experian/best-budgeting-apps
- https://robberger.com/personal-finance-software/
- https://getfinny.app/blog/best-budget-apps-reddit-recommends-2026
- https://marketing4ecommerce.mx/apps-de-finanzas-personales-y-ahorro-mexico/
