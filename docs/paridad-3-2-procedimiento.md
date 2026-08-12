# Procedimiento de la prueba de paridad §3.2

Reformulación ejecutable del criterio de aceptación de la Fase 6
(`paquete-construccion-final.md` §3.2 y §9: "la prueba de paridad del §3.2
pasa en ambos sistemas"). Este documento dice qué automatiza
`test/paridad/` y `test/ui/paridad_pantallas_test.dart`, qué queda manual,
y por qué.

## Qué automatiza

| Pieza | Dónde | Cómo |
|---|---|---|
| Cierre del ciclo (ingreso total, meta apartado, total gastado, renglones) | `test/paridad/paridad_3_2_test.dart` (prueba 1) | `calcularSnapshotCierre` contra la semilla |
| Cierre estimado del MPC (P50/P10/P90, tipo, confianza, nivel de madurez) por categoría variable | prueba 2 | `pronosticoDeCategoria` (`lib/domain/pronostico/historico_desde_movimientos.dart`) |
| Plan de ajuste — monto y **las tres piezas de texto**, incluido el caso `null` | prueba 2 | `calcularPlanDeAjuste` |
| Lista de gastos (conteo y total) | prueba 3 | mismo camino que `pantalla_gastos.dart:224-225` |
| Formato de `Dinero` (positivo, negativo, cero, millones) | prueba 4 | `Dinero.formateado()` |
| `cicloId` estable tras serializar/reparsear un movimiento en cualquier huso horario | prueba 5 | `CalculadoraCiclo.calcularPara` |
| Que `PantallaGastos` muestre las mismas cifras congeladas que `domain/` | `test/ui/paridad_pantallas_test.dart` | monta el widget con la semilla, verifica el texto en pantalla |

Todo lo anterior corre sobre `test/paridad/datos/semilla_paridad_v1.json`
(versionada, nunca editada a mano tras congelar) y compara contra
`test/paridad/esperado/valores_congelados_v1.json`. Regenerar con:

```
dart run test/paridad/herramientas/regenerar_esperado.dart > salida.json
```

y revisar el diff a mano antes de reemplazar el archivo congelado — nunca
copiar sin verificar (eso congela el bug, no lo previene). Al congelar por
primera vez se verificaron a mano tres cifras (documentado en el
`_comentario` de `valores_congelados_v1.json`): el total gastado del
ciclo, el `sugeridoPromedioPorDia` de la categoría que dispara el plan de
ajuste, y el conteo de movimientos de la lista de gastos.

## Por qué domain/ es suficiente para "paridad de plataforma"

> Todo lo que puede divergir entre iOS y Android vive en `domain/`, que es
> Dart puro y determinista. El binario puede cambiar — cómo se pinta, qué
> widgets usa cada plataforma — pero el cálculo no, porque es el mismo
> código Dart compilado a ambos binarios. Si esas cifras están congeladas
> contra un juego de datos versionado, cualquier regresión de cálculo se
> detecta sin necesitar los dos dispositivos.

`test/ui/paridad_pantallas_test.dart` cierra el hueco restante — que el
dominio calcule bien pero la pantalla muestre otra cosa — para las
pantallas que pueden probarse de forma determinista.

### Por qué solo `PantallaGastos`, no `PantallaInicio`

`PantallaGastos` recibe `cicloId` explícito por constructor: es
determinista sin importar el reloj real de la máquina que corre la prueba.

`PantallaInicio` no. Calcula su ciclo con
`CalculadoraCiclo(...).calcularPara(DateTime.now())` dentro de
`initState()` (`lib/ui/inicio/pantalla_inicio.dart:64-66`), sin forma de
inyectar "hoy" desde afuera — a diferencia de `calcularRollups`, que sí
acepta `ahora` opcional. Fijarla a la semilla de fecha congelada (ciclo
`2026-07`) produciría una prueba que pasa hoy y falla sola el día en que el
reloj real de quien la corra salga de esa ventana — peor que no tenerla.
Queda como deuda técnica documentada: inyectar `hoy`/`ahora` en
`PantallaInicio` (y en `PantallaDetalleCategoria`, que tiene el mismo
patrón) antes de poder pinearla a una semilla congelada.

## Sustitución documentada: Android-vs-Android, no iPhone-vs-Android

No hay Mac ni cuenta Apple Developer en este entorno (`lib/firebase_options.dart:5`,
`lib/ui/comun/pantalla_login.dart:8`). El §3.2 exige correr la comparación
"en un iPhone y en un Android"; aquí se sustituye por **dos dispositivos
Android con la misma semilla**, verificando en pantalla las mismas cifras
que `valores_congelados_v1.json`.

**Criterio de salida de la sustitución:** el §3.2 completo, con iPhone real,
se corre antes de la primera publicación en App Store — no antes.

## Diferimiento del punto 4 del §3.2

El punto 4 ("un gasto registrado en uno aparece en el otro en menos de
5 s") exige sincronización real entre dispositivos, es decir, Firestore.
La persistencia real de la Fase 6 sigue siendo JSON en disco
(`AlmacenJsonLista`); no hay servidor que sincronice nada. `cloud_firestore`
salió de `pubspec.yaml` (Bloque 0) por tener cero usos. No hay sincronía
que medir todavía — este punto queda fuera de alcance hasta que exista una
implementación Firestore de los repositorios (que las interfaces de
`data/repositorios/` ya dejan lista para recibir sin tocar `domain/` ni
`ui/`).

## Guion del pase manual en dispositivo

Antes de subir a la pista de pruebas internas de Play (y, cuando exista
Mac, antes de la primera build de iOS):

1. Instalar el `.aab`/APK de release en el dispositivo.
2. Cargar la semilla `semilla_paridad_v1.json` (importarla manualmente o
   sembrar el mismo JSON en el almacenamiento local de la app — ver
   `AlmacenLocal` en `lib/data/repositorios/local/almacen_local.dart`).
3. Abrir Gastos del ciclo `2026-07` y comparar contra `valores_congelados_v1.json`:
   - Conteo y total de la lista de gastos.
   - Cierre estimado (P50) de "Súper/Comida" en el detalle de esa categoría.
   - El plan de ajuste de "Súper/Comida" — las tres piezas de texto, no
     solo el monto.
4. Repetir el paso 3 en un **segundo** dispositivo Android — la
   sustitución documentada de arriba.
5. Cuando exista Mac: repetir en iPhone y comparar contra el mismo
   `valores_congelados_v1.json`. Si todo cuadra, el §3.2 completo (incluido
   el punto 4, una vez que haya Firestore) queda satisfecho y este
   documento se actualiza para quitar la nota de sustitución.

## Lo que este documento no cubre

- Accesibilidad y escalado de texto en pantalla real (ver
  `docs/tiendas/checklist-publicacion.md`).
- Que el `.aab` esté firmado con la *upload key* correcta y que el login de
  Google funcione desde la pista de pruebas internas (Fase 6, Bloque 5) —
  un problema de identidad de firma, no de paridad de cálculo.
