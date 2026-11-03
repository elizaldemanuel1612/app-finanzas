import '../../data/seguridad/candado.dart';

Future<List<int>> derivarClave(String secreto, List<int> sal, int iteraciones) async =>
    pbkdf2Sha256(secreto, sal, iteraciones);
