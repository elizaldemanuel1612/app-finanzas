import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/ia/clientes_ia.dart';
import '../../data/ia/configuracion_ia.dart';
import '../../data/ia/servicio_ia.dart';
import '../../domain/ia/proveedor_ia.dart';
import '../../plataforma/ia_apple.dart';
import '../comun/chip_estado.dart';
import '../comun/renglon_app.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';
import 'pantalla_asistente.dart';
import '../comun/hoja.dart';

/// Ajustes → Complementos de IA (spec §6.5): cada quien conecta la suya.
class PantallaComplementosIA extends StatefulWidget {
  final ServicioIA servicio;
  const PantallaComplementosIA({super.key, required this.servicio});

  @override
  State<PantallaComplementosIA> createState() => _PantallaComplementosIAState();
}

/// Color e ícono de cada complemento (fijos en los dos modos, ícono blanco).
(Color, IconData) apariencia(ProveedorIA p) => switch (p) {
      ProveedorIA.apple => (const Color(0xFF1C1C1E), Icons.apple),
      ProveedorIA.gemini => (const Color(0xFF1F6FE0), Icons.auto_awesome),
    };

class _PantallaComplementosIAState extends State<PantallaComplementosIA> {
  ConfiguracionIA? _config;
  EstadoApple _apple = EstadoApple.noSoportado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final config = await widget.servicio.configuracion();
    final apple = await IAApple.estado();
    if (mounted) {
      setState(() {
        _config = config;
        _apple = apple;
      });
    }
  }

  Future<void> _tocar(ProveedorIA p) async {
    final config = _config!;
    if (config.conectado(p)) {
      await _opcionesConectado(p, enUso: config.activo == p);
    } else if (p == ProveedorIA.apple) {
      if (_apple != EstadoApple.disponible) {
        _avisar(_apple.explicacion);
        return;
      }
      await widget.servicio.conectarApple();
      _avisar('Listo, la app usará Apple Intelligence');
    } else {
      final conectado = await mostrarHoja<bool>(
        context,
        builder: (_) => _HojaConectar(proveedor: p, servicio: widget.servicio),
      );
      if (conectado == true) _avisar('Listo, ${p.nombre} está conectado');
    }
    await _cargar();
  }

  Future<void> _opcionesConectado(ProveedorIA p, {required bool enUso}) async {
    final accion = await mostrarHoja<String>(
      context,
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.nombre, style: Theme.of(contexto).textTheme.seccion),
              const SizedBox(height: 4),
              Text(
                [
                  if (_config!.modelos[p] case final modelo?) 'Modelo: $modelo',
                  enUso ? 'Es la que usa la app.' : 'Conectado.',
                ].join(' · '),
                style: Theme.of(contexto).textTheme.etiqueta,
              ),
              const SizedBox(height: 16),
              if (!enUso) ...[
                ElevatedButton(onPressed: () => Navigator.of(contexto).pop('usar'), child: const Text('Usar esta')),
                const SizedBox(height: 8),
              ],
              OutlinedButton(onPressed: () => Navigator.of(contexto).pop('quitar'), child: const Text('Desconectar')),
            ],
          ),
        ),
      ),
    );
    if (accion == 'usar') await widget.servicio.usar(p);
    if (accion == 'quitar') {
      await widget.servicio.desconectar(p);
      _avisar('${p.nombre} desconectado${p.requiereClave ? '; su clave se borró de este teléfono' : ''}');
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final textos = Theme.of(context).textTheme;
    final p = ColoresApp.actual;
    final hayAlguna = config?.conectados.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Complementos de IA')),
      body: config == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Text(
                  'Conecta tu propia IA. La app no guarda ni paga ninguna: tu clave se queda solo en este teléfono '
                  'y la app le habla directo a tu IA.',
                  style: textos.cuerpo.copyWith(color: p.texto2),
                ),
                const EncabezadoSeccion(titulo: 'Tus complementos'),
                TarjetaApp.lista(renglones: [
                  for (final proveedor in ProveedorIA.values)
                    if (proveedor != ProveedorIA.apple || IAApple.posible || config.conectado(proveedor))
                      RenglonApp(
                        icono: apariencia(proveedor).$2,
                        iconoCuadrado: true,
                        fondoIcono: apariencia(proveedor).$1,
                        colorIcono: Colors.white,
                        titulo: proveedor.nombre,
                        subtitulo: proveedor == ProveedorIA.apple && !config.conectado(proveedor) && _apple != EstadoApple.disponible
                            ? _apple.explicacion
                            : proveedor.descripcion,
                        derecha: config.activo == proveedor
                            ? const ChipEstado(tono: TonoEstado.exito, texto: 'En uso')
                            : config.conectado(proveedor)
                                ? const ChipEstado(tono: TonoEstado.neutro, texto: 'Conectado')
                                : Text('Conectar', style: textos.cuerpoFuerte.copyWith(color: p.accion)),
                        onTap: () => _tocar(proveedor),
                      ),
                ]),
                if (!IAApple.posible)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Apple Intelligence aparece en la app del iPhone.', style: textos.etiqueta),
                  ),
                const EncabezadoSeccion(titulo: 'Qué hace tu IA'),
                TarjetaApp.lista(renglones: [
                  RenglonApp(
                    icono: Icons.forum_outlined,
                    titulo: 'Pregúntale a tu IA',
                    subtitulo: 'Cómo se hace algo o dónde está un botón, según la guía de la app',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PantallaAsistente(servicio: widget.servicio)),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text('Sugerir categorías', style: textos.cuerpoFuerte),
                    subtitle: Text(
                      hayAlguna
                          ? 'Al escribir la nota de un gasto que la app no reconoce. Solo manda la nota y los nombres de tus categorías.'
                          : 'Conecta una IA para encenderlo.',
                      style: textos.etiqueta,
                    ),
                    value: config.sugerirCategorias,
                    onChanged: hayAlguna
                        ? (v) async {
                            await widget.servicio.sugerirCategorias(v);
                            await _cargar();
                          }
                        : null,
                  ),
                  if (widget.servicio.datosDelUsuario != null)
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text('Dejar que tu IA vea tus números', style: textos.cuerpoFuerte),
                      subtitle: Text(
                        !hayAlguna
                            ? 'Conecta una IA para encenderlo.'
                            : config.activo == ProveedorIA.apple
                                ? 'Para preguntarle cuánto llevas o cuánto te queda. Con Apple Intelligence no sale de tu iPhone.'
                                : 'Para preguntarle cuánto llevas o cuánto te queda. Se manda a Google un resumen: totales '
                                    'por categoría, saldos y objetivos. Con la clave gratuita, Google puede usarlo para '
                                    'mejorar sus productos.',
                        style: textos.etiqueta,
                      ),
                      value: config.verMisNumeros,
                      onChanged: hayAlguna
                          ? (v) async {
                              await widget.servicio.verMisNumeros(v);
                              await _cargar();
                            }
                          : null,
                    ),
                ]),
                const SizedBox(height: 16),
                Text(
                  config.verMisNumeros
                      ? 'Tu IA solo ve el resumen que calcula la app, nunca cada gasto. La app no da asesoría financiera, y tu IA tampoco.'
                      : 'Tu IA no ve tus gastos ni tus saldos. La app no da asesoría financiera, y tu IA tampoco.',
                  style: textos.etiqueta,
                ),
              ],
            ),
    );
  }
}

/// Pegar la clave de API: dónde sacarla, probarla y conectar.
class _HojaConectar extends StatefulWidget {
  final ProveedorIA proveedor;
  final ServicioIA servicio;
  const _HojaConectar({required this.proveedor, required this.servicio});

  @override
  State<_HojaConectar> createState() => _HojaConectarState();
}

class _HojaConectarState extends State<_HojaConectar> {
  final _clave = TextEditingController();
  bool _probando = false;
  String? _error;

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  Future<void> _conectar() async {
    setState(() {
      _probando = true;
      _error = null;
    });
    try {
      await widget.servicio.conectarConClave(widget.proveedor, _clave.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ErrorIA catch (e) {
      if (mounted) {
        setState(() {
          _probando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  Future<void> _pegar() async {
    final datos = await Clipboard.getData(Clipboard.kTextPlain);
    final texto = datos?.text?.trim();
    if (texto != null && texto.isNotEmpty) setState(() => _clave.text = texto);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proveedor;
    final textos = Theme.of(context).textTheme;
    final colores = ColoresApp.actual;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Conectar ${p.nombre}', style: textos.seccion),
              const SizedBox(height: 4),
              Text(p.descripcion, style: textos.etiqueta),
              const SizedBox(height: 16),
              _Paso(numero: 1, texto: 'Entra a ${p.sitioClave} con tu cuenta y crea una clave de API.'),
              Padding(
                padding: const EdgeInsets.only(left: 34, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(p.urlClave!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text('Abrir ${p.sitioClave}'),
                  ),
                ),
              ),
              const _Paso(numero: 2, texto: 'Cópiala y pégala aquí. Se queda solo en este teléfono.'),
              const SizedBox(height: 8),
              TextField(
                controller: _clave,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Tu clave de ${p.nombre}',
                  suffixIcon: IconButton(
                    tooltip: 'Pegar',
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: _pegar,
                  ),
                ),
                onSubmitted: (_) => _conectar(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: textos.etiqueta.copyWith(color: colores.peligroTexto)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _probando ? null : _conectar,
                child: Text(_probando ? 'Probando tu clave…' : 'Conectar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final int numero;
  final String texto;
  const _Paso({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final p = ColoresApp.actual;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle),
            child: Text('$numero', style: textos.etiqueta.copyWith(color: p.texto, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: textos.cuerpo)),
        ],
      ),
    );
  }
}
