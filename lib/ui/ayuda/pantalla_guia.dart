import '../../data/ia/servicio_ia.dart';
import '../comun/boton_burbuja.dart';
import '../ia/pantalla_asistente.dart';
import 'package:flutter/material.dart';

import '../comun/nota_destacada.dart';
import '../comun/seccion_lista.dart';
import '../comun/tema.dart';
import 'contenido_guia.dart';
import 'modelo_guia.dart';
import 'pantalla_tema_guia.dart';

/// Índice de la guía por temas — manual de consulta permanente, alcanzable
/// desde Ajustes → "Cómo funciona la app" y ofrecido al terminar el
/// onboarding. Constructor `const` y cero repositorios: funciona igual con
/// la cuenta vacía o con años de historial.
class PantallaGuia extends StatelessWidget {
  /// Para ofrecer "Pregúntale a tu IA" (spec §6.5); sin él no aparece.
  final ServicioIA? servicioIA;

  const PantallaGuia({super.key, this.servicioIA});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cómo funciona la app'),
        actions: [
          if (servicioIA case final servicio?) ...[
            BotonBurbuja(
              icono: Icons.forum_outlined,
              tooltip: 'Pregúntale a tu IA',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PantallaAsistente(servicio: servicio)),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NotaDestacada(
            etiqueta: 'CÓMO LEERLA',
            texto: 'Son temas cortos y sueltos. Empieza por el que te haga '
                'falta; no hace falta leerlos en orden.',
          ),
          const SizedBox(height: 20),
          for (final seccion in guiaDeLaApp) ...[
            SeccionLista(
              titulo: seccion.titulo,
              hijos: [for (final tema in seccion.temas) _RenglonTema(tema)],
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _RenglonTema extends StatelessWidget {
  final TemaGuia tema;

  const _RenglonTema(this.tema);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
        child: ExcludeSemantics(child: Text(tema.emoji, style: theme.titleMedium)),
      ),
      title: Text(tema.titulo, style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(tema.resumen),
      trailing: Icon(Icons.chevron_right, color: ColoresApp.medio),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PantallaTemaGuia(tema: tema)),
      ),
    );
  }
}
