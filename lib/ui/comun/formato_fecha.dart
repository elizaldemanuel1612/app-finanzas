/// Fecha corta de presentación ("15 ago"), compartida por las pantallas
/// que muestran rangos de ciclo (Inicio, cierre de ciclo, ciclos
/// anteriores) para no repetir la misma tabla de meses en cada una.
String fechaCorta(DateTime f) {
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${f.day} ${meses[f.month - 1]}';
}
