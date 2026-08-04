# ¿Cómo usa la app la inteligencia artificial?

Explicación sin tecnicismos, porque es una parte que conviene que entiendas bien: define costos, privacidad y qué pasa cuando no hay internet.

---

## Lo primero: la app casi nunca necesita IA

Cuando escribes *"compré un refresco en la tienda"*, la app intenta resolverlo en cuatro niveles, en orden. **Solo llega al cuarto si los tres primeros fallaron.**

### Nivel 0 — Diccionario que viene dentro de la app
Al instalarse, la app trae un catálogo de unas 300 palabras del español de México ya clasificadas:

```
refresco, agua, cerveza, tortillas, carne, verdura → Súper
gasolina, caseta, estacionamiento, verificación   → Auto
restaurante, cine, bar, café, antro               → Salidas
pañales, fórmula, pediatra                        → Hijos
```

**Tu ejemplo del refresco se resuelve aquí.** Sin internet, sin IA, sin costo, instantáneo. Este catálogo lo trae la app de fábrica y se actualiza con las versiones.

### Nivel 1 — Tus propias reglas
Las que tú definiste explícitamente. Ejemplo real tuyo: *carnicería → Súper*. Estas mandan sobre todo lo demás.

### Nivel 2 — Tu historial
¿Ya clasificaste antes algo de "Súper del Valle"? Se aplica la misma categoría. Este nivel es el que hace que la app se sienta cada vez más lista: no aprende de nadie más, aprende de ti.

### Nivel 3 — La IA
Solo si los anteriores no resolvieron. Ejemplos que llegarían aquí:
- *"pagué la membresía de Costco"* — no está en el catálogo, no tienes regla, no hay historial
- *"le di dinero a Lupita"* — ambiguo hasta para una persona
- *"compré cosas para el proyecto"* — sin información suficiente

**En la práctica, después de dos o tres meses de uso la IA se usa en menos del 5% de tus capturas.**

---

## Qué es exactamente "la IA" de la app

No soy yo. Esta conversación se acaba cuando cierras el chat; la app es un programa independiente.

Lo que hace la app es **llamar por internet a un modelo de lenguaje** a través de una API — el mismo tipo de tecnología, pero contratado aparte, con tu propia cuenta y tu propio recibo. Las opciones realistas:

| Opción | Costo aproximado | Nota |
|---|---|---|
| **API de Claude (Anthropic)** | centavos por cada mil clasificaciones | Buena comprensión del español de México |
| **API de OpenAI** | similar | Alternativa equivalente |
| **Modelo pequeño en el dispositivo** | gratis | Menos preciso, pesa más la app. Viable a futuro |

La llamada la hace **el servidor de tu app** (una Cloud Function de Firebase), no el teléfono. Así la llave de acceso nunca vive en el celular de nadie.

---

## Qué se manda y qué no

Esto es lo importante de la privacidad. En una clasificación se envía:

```
Texto: "pagué la membresía de Costco"
Categorías disponibles: Vivienda, Súper, Salidas, Auto, Salud, Hijos...
Pregunta: ¿a cuál corresponde, y qué tan seguro estás?
```

**Nunca se manda:** tu nombre, tu correo, tus montos, tu historial completo, tus ingresos, tus saldos, ni nada que identifique quién eres. Solo el texto de esa descripción y la lista de nombres de tus categorías.

La respuesta que regresa es corta:
```
Categoría: Otros · Confianza: 0.62 · Motivo: membresía de tienda, no es despensa
```

---

## Cómo "adivina" sin que le hayas enseñado

No hay un catálogo escondido con todas las respuestas. El modelo entiende el idioma: sabe qué es un refresco, sabe que se compra en una tienda, y sabe que entre tus categorías la más cercana es Súper. Es el mismo razonamiento que haría un asistente humano que ve tu lista de categorías por primera vez.

Por eso **la primera vez puede preguntarte**, y por eso importa la regla que definimos:

> Con confianza ≥ 0.90 aplica la categoría y la marca como sugerida.
> Entre 0.60 y 0.89 pregunta.
> Abajo de 0.60 la manda a "Otros" y te avisa.

Y en cuanto tú confirmas o corriges, **eso se guarda como regla tuya (Nivel 1) y no vuelve a preguntar nunca por lo mismo.**

---

## Costo real, con tus números

Tu ciclo Jul tiene 52 movimientos. Suponiendo el peor caso al arrancar (la IA se usa en 30% de ellos, unas 16 llamadas), el costo sería de **fracciones de peso al mes**. Cuando el historial madure y baje a 5%, es prácticamente cero.

Aun así, la app lleva un **tope mensual configurable**. Si se alcanza, sigue funcionando con los niveles 0, 1 y 2 y te avisa. Nunca hay una sorpresa en el recibo.

---

## Y si no hay internet, o si la apagas

| Situación | Qué pasa |
|---|---|
| Sin señal | Niveles 0, 1 y 2 funcionan igual. Lo que necesitaba IA queda como "Otros" y se reclasifica sola cuando vuelva la conexión. |
| Apagas la IA en Ajustes | La app funciona completa. Lo que no se resuelva te lo pregunta a ti. |
| Se cae el servicio | Igual que sin señal. Nunca se bloquea una captura por esto. |

**La IA es una comodidad, no un requisito.** Ninguna función esencial —registrar, presupuestar, pronosticar, alertar— depende de ella. El pronóstico, en particular, es matemática pura corriendo en tu propio servidor: ahí no hay IA de por medio.

---

## El resumen en tres líneas

1. Tu refresco lo resuelve un diccionario que viene dentro de la app, sin internet y sin costo.
2. La IA solo entra en los casos raros, cuesta centavos, y va desapareciendo conforme la app aprende de ti.
3. Nunca sale de tu teléfono nada que diga quién eres ni cuánto tienes.
