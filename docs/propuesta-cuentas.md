# Propuesta: cuentas y tarjetas (2026-11-02)

> Estado: **aprobada el 2026-11-02** (fase A, con las recomendaciones; efectivo con saldo opcional, abono puede contar como ingreso, análisis por cuenta en su propia vista, transferencias en la segunda etapa). Lo que rige está en `spec-app-finanzas-v2.md` §7.3.1.

## Qué pidió el usuario

- Dar de alta varias tarjetas, de crédito o de débito.
- En débito, capturar cuánto dinero hay; cada gasto con esa tarjeta lo descuenta y se pueden registrar abonos.
- Al registrar un gasto, elegir con qué tarjeta se pagó.
- Que todo cuadre con lo que ya existe.

## Hoy

`Movimiento.medio` es un `enum MedioPago { tarjeta, efectivo }`. Lo usan:

- La captura: el selector Tarjeta / Efectivo, más voz y ticket.
- Análisis: el bloque "Tarjeta y efectivo".
- El CSV: la columna "Medio de pago".
- El respaldo en Drive, como un campo más del movimiento.

## La propuesta

### 1. Un concepto nuevo: **Cuenta**

```
Cuenta {
  id, nombre ("BBVA débito", "Amex"), emoji,
  tipo: efectivo | debito | credito,
  saldoInicial: Dinero?      // solo débito (y efectivo, si se quiere)
  fechaSaldoInicial: DateTime // desde cuándo cuenta ese saldo
  activa, orden
}
```

- **Dónde se guarda:** en `cuentas.json`, un archivo nuevo de `AlmacenLocal` que se respalda en Drive como los demás. Usa los mismos nombres de campo que Firestore (§4).
- **Efectivo siempre existe:** se crea solo, igual que hoy existe el "medio efectivo".
- **Las cuentas no se borran, se archivan:** igual que las categorías, porque tienen historial.

### 2. El gasto dice de qué cuenta salió

- **Campo nuevo:** `Movimiento.cuentaId`.
- **Se conserva `medio`,** derivado del tipo de cuenta (débito o crédito = tarjeta, efectivo = efectivo). Así Análisis, el CSV viejo y los datos ya guardados siguen funcionando sin tocarse.
- **Migración automática** al actualizar:
  - Lo que hoy es "tarjeta" queda en una cuenta "Tarjeta" de tipo crédito.
  - Lo que es "efectivo" queda en "Efectivo".
  - El usuario después puede reasignar gastos a sus tarjetas reales desde la edición.

### 3. El saldo se calcula, nunca se guarda

```
saldo(débito) = saldoInicial
              + abonos
              − gastos activos con esa cuenta (desde fechaSaldoInicial)
```

- **Por qué calculado:**
  - Un saldo guardado se descuadra con cualquier edición, anulación o sincronización.
  - Calculado, siempre es la suma exacta en centavos: regla #1, y es idempotente (regla #2).
- **Editar o anular un gasto** corrige el saldo solo.
- **"Ajustar saldo"** (cuando el banco dice otra cifra) registra un **ajuste** con la diferencia, en vez de reescribir el saldo inicial. Así queda el rastro.
- **Saldo negativo:** se permite y se avisa en coral. Nunca bloquea la captura (regla #17).

### 4. Abonos

Entidad nueva `MovimientoCuenta`:

```
MovimientoCuenta {
  clientId, cuentaId, fecha, monto (> 0), nota,
  tipo: abono | ajuste | transferencia
}
```

- **No es un gasto:** no entra a categorías, ritmo ni presupuesto.
- **Se anula, no se borra:** como cualquier registro de dinero.
- **Abono e ingreso del ciclo son cosas distintas:** si el abono es la quincena, ¿también cuenta como "lo que entra"? (ver decisión 2).

### 5. Dónde se ve

| Lugar | Qué cambia |
|---|---|
| **Registrar gasto** | La fila Tarjeta / Efectivo se vuelve una fila de cuentas, la más usada primero (igual que las categorías). Por omisión, la última que usaste. Voz: "…con la BBVA" la reconoce por nombre. |
| **Ajustes → Tus cuentas** | Alta y edición, con el saldo de cada débito. Al tocar una cuenta: sus movimientos, "Registrar abono" y "Ajustar saldo". |
| **Inicio** | Una tarjeta pequeña "Tus cuentas" con los saldos de débito, plegable. |
| **Análisis** | "Tarjeta y efectivo" pasa a **"Por cuenta"**: cuánto salió de cada una en el ciclo. |
| **CSV** | Columna nueva **Cuenta** (nombre). Si no existe, se crea como crédito y aparece un aviso. "Medio de pago" se sigue leyendo en archivos viejos. Las cuentas también van al archivo, como las categorías sin gastos. |
| **Guía** | Un tema nuevo: "Tus cuentas". |

### 6. Fases

- **Fase A (esta entrega):**
  - Cuentas y migración.
  - Elegir la cuenta al registrar un gasto.
  - Saldo de débito, abonos y ajustes.
  - Pantalla de cuentas, el bloque de Análisis, el CSV y Drive.
- **Fase B (después):**
  - Transferencias: retirar efectivo del débito, o pagar la tarjeta de crédito desde el débito. **No son gastos**; si se registraran como gasto, se contaría dos veces.
  - Crédito: fecha de corte y de pago, límite, y recordatorio de pago.
  - Aviso de saldo bajo.

## Decisiones que necesito del usuario

1. **¿El efectivo también lleva saldo?** Por ejemplo, "traigo $800 en la cartera". Mi propuesta: opcional, apagado por omisión.
2. **¿Un abono también cuenta como ingreso del ciclo?** Mi propuesta: al registrar el abono, una casilla "También es ingreso de este ciclo", apagada por omisión, que crea el `IngresoExtra` ligado. Así no se cuenta dos veces.
3. **Tarjetas de crédito en la Fase A:** ¿solo elegirlas al pagar o también ver cuánto llevas gastado en ellas? Mi propuesta: elegir y ver "gastado este ciclo"; corte, pago y límite van en la Fase B.
4. **¿Las transferencias (pagar la tarjeta desde el débito) son urgentes?** Si las usarás desde el primer día, conviene subirlas a la Fase A.
