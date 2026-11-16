import '../../data/ia/configuracion_ia.dart';
import '../../data/ia/reunir_datos_para_ia.dart';
import '../../data/ia/servicio_ia.dart';
import '../../domain/ia/datos_para_ia.dart';
import '../../data/repositorios/local/almacen_local.dart';
import '../../plataforma/ia_apple.dart';

/// El servicio de complementos de IA de esta cuenta (spec §6.5): la
/// configuración en su `ia.json` y, en el iPhone, Apple Intelligence.
ServicioIA servicioIADe(AlmacenLocal almacen) => ServicioIA(
      AlmacenConfiguracionIA(almacen.ia),
      apple: clienteAppleSiAplica(),
      datosDelUsuario: () async {
        final datos = await reunirDatosParaIA(almacen, DateTime.now());
        return datos == null ? null : textoParaIA(datos);
      },
    );
