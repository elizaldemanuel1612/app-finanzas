import 'package:flutter/material.dart';

import '../../data/ia/clientes_ia.dart';
import '../../data/ia/servicio_ia.dart';
import '../../domain/ia/proveedor_ia.dart';
import '../../plataforma/ia_apple.dart';
import '../ayuda/instructivo_ia.dart';
import '../comun/boton_burbuja.dart';
import '../comun/tema.dart';
import 'pantalla_complementos_ia.dart';

/// "Pregúntale a tu IA" (spec §6.5): contesta cómo usar la app con base en
/// la guía por temas. No ve los datos del usuario.
class PantallaAsistente extends StatefulWidget {
  final ServicioIA servicio;
  const PantallaAsistente({super.key, required this.servicio});

  @override
  State<PantallaAsistente> createState() => _PantallaAsistenteState();
}

const _sugerencias = [
  '¿Cómo registro un gasto?',
  '¿Dónde cambio mi día de corte?',
  '¿Cómo pago mi tarjeta de crédito?',
  '¿Qué pasa si me paso en una categoría?',
  '¿Cómo creo un objetivo de ahorro?',
];

class _Burbuja {
  final MensajeIA mensaje;
  final bool error;
  const _Burbuja(this.mensaje, {this.error = false});
}

class _PantallaAsistenteState extends State<PantallaAsistente> {
  final _texto = TextEditingController();
  final _desplazamiento = ScrollController();
  final List<_Burbuja> _conversacion = [];
  ProveedorIA? _activo;
  bool _cargando = true;
  bool _pensando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _texto.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final config = await widget.servicio.configuracion();
    if (mounted) {
      setState(() {
        _activo = config.conectado(config.activo ?? ProveedorIA.gemini) ? config.activo : null;
        _cargando = false;
      });
    }
  }

  Future<void> _preguntar([String? sugerida]) async {
    final pregunta = (sugerida ?? _texto.text).trim();
    if (pregunta.isEmpty || _pensando) return;
    _texto.clear();
    setState(() {
      _conversacion.add(_Burbuja(MensajeIA.usuario(pregunta)));
      _pensando = true;
    });
    _bajar();
    try {
      final cliente = await widget.servicio.clienteActivo();
      if (cliente == null) throw const ErrorIA('Conecta tu IA en Complementos de IA.');
      final esApple = _activo == ProveedorIA.apple;
      final respuesta = await cliente.responder(
        sistema: instructivoDelAsistente(
          pregunta: pregunta,
          maxCaracteres: esApple ? IAApple.maxCaracteresInstructivo : null,
        ),
        // Las últimas vueltas bastan para seguir el hilo.
        mensajes: [
          for (final b in _conversacion.where((b) => !b.error).toList().reversed.take(8).toList().reversed) b.mensaje,
        ],
      );
      if (mounted) setState(() => _conversacion.add(_Burbuja(MensajeIA.asistente(respuesta))));
    } on ErrorIA catch (e) {
      if (mounted) setState(() => _conversacion.add(_Burbuja(MensajeIA.asistente(e.mensaje), error: true)));
    } finally {
      if (mounted) setState(() => _pensando = false);
      _bajar();
    }
  }

  void _bajar() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_desplazamiento.hasClients) {
          _desplazamiento.animateTo(
            _desplazamiento.position.maxScrollExtent,
            duration: Duracion.rapida,
            curve: Curves.easeOut,
          );
        }
      });

  Future<void> _irAComplementos() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaComplementosIA(servicio: widget.servicio)),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final p = ColoresApp.actual;
    final activo = _activo;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pregúntale a tu IA'),
            if (activo != null) Text('Con ${activo.nombre}', style: textos.etiqueta),
          ],
        ),
        actions: [
          BotonBurbuja(icono: Icons.tune_rounded, tooltip: 'Complementos de IA', onPressed: _irAComplementos),
          const SizedBox(width: 8),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : activo == null
              ? _sinIA(textos, p)
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          controller: _desplazamiento,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          children: [
                            if (_conversacion.isEmpty) ...[
                              _BurbujaIA(
                                texto: 'Hola. Pregúntame cómo se hace algo en la app o dónde está un botón. '
                                    'Contesto con base en la guía de la app; no veo tus gastos.',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final s in _sugerencias)
                                    ActionChip(label: Text(s), onPressed: () => _preguntar(s)),
                                ],
                              ),
                            ],
                            for (final b in _conversacion)
                              b.mensaje.delUsuario
                                  ? _BurbujaUsuario(texto: b.mensaje.texto)
                                  : _BurbujaIA(texto: b.mensaje.texto, error: b.error),
                            if (_pensando) const _BurbujaIA(texto: 'Pensando…', pensando: true),
                          ],
                        ),
                      ),
                      _Entrada(controlador: _texto, ocupado: _pensando, alEnviar: _preguntar),
                    ],
                  ),
                ),
    );
  }

  Widget _sinIA(TextTheme textos, Paleta p) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle),
              child: Icon(Icons.forum_outlined, size: 40, color: p.accion),
            ),
          ),
          const SizedBox(height: 20),
          Text('Conecta tu IA', textAlign: TextAlign.center, style: textos.titulo),
          const SizedBox(height: 8),
          Text(
            'Usa la tuya: Apple Intelligence en el iPhone, o tu clave de Gemini. '
            'Te contesta cómo hacer cualquier cosa en la app.',
            textAlign: TextAlign.center,
            style: textos.cuerpo,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _irAComplementos, child: const Text('Conectar mi IA')),
        ],
      );
}

/// Texto con **negritas** de la respuesta.
List<TextSpan> _conNegritas(String texto, TextStyle base) {
  final partes = texto.split('**');
  return [
    for (final (i, parte) in partes.indexed)
      TextSpan(text: parte, style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : base),
  ];
}

class _BurbujaUsuario extends StatelessWidget {
  final String texto;
  const _BurbujaUsuario({required this.texto});

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.only(top: 8, left: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: p.accion,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(texto, style: Theme.of(context).textTheme.cuerpo.copyWith(color: p.sobreAccion)),
      ),
    );
  }
}

class _BurbujaIA extends StatelessWidget {
  final String texto;
  final bool error;
  final bool pensando;
  const _BurbujaIA({required this.texto, this.error = false, this.pensando = false});

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final base = Theme.of(context).textTheme.cuerpo.copyWith(color: error ? p.peligroTexto : (pensando ? p.texto2 : p.texto));
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        margin: const EdgeInsets.only(top: 8, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: error ? p.peligroFondo : p.superficie,
          border: Border.all(color: p.borde),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: SelectableText.rich(TextSpan(children: _conNegritas(texto, base))),
      ),
    );
  }
}

class _Entrada extends StatelessWidget {
  final TextEditingController controlador;
  final bool ocupado;
  final void Function([String?]) alEnviar;
  const _Entrada({required this.controlador, required this.ocupado, required this.alEnviar});

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: p.superficie, border: Border(top: BorderSide(color: p.borde))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controlador,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => alEnviar(),
              decoration: InputDecoration(
                hintText: 'Escribe tu pregunta',
                filled: true,
                fillColor: p.superficieHundida,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radios.pill), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radios.pill), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radios.pill),
                  borderSide: BorderSide(color: p.accion),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Enviar',
            child: Material(
              color: ocupado ? p.superficieHundida : p.accion,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: ocupado ? null : () => alEnviar(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.arrow_upward_rounded, color: ocupado ? p.texto2 : p.sobreAccion),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
