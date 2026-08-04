import '../../domain/modelos/perfil.dart';

abstract interface class PerfilRepositorio {
  Future<Perfil?> obtener();

  Future<void> guardar(Perfil perfil);
}
