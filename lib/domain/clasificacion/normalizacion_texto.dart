const _mapaAcentos = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
};

/// Minúsculas, sin acentos, sin espacios sobrantes — para comparar
/// patrones y comercios sin que "Oxxo" vs "OXXO" o "café" vs "cafe"
/// cuenten como cosas distintas.
String normalizarTexto(String texto) {
  var resultado = texto.trim().toLowerCase();
  _mapaAcentos.forEach((con, sin) {
    resultado = resultado.replaceAll(con, sin);
  });
  return resultado;
}
