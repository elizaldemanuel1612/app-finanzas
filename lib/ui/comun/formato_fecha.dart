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

const _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// El mes en palabras ("marzo"), con el año solo si no es el de [hoy]
/// ("marzo de 2027").
String mesEnPalabras(DateTime f, {required DateTime hoy}) =>
    f.year == hoy.year ? _mesesLargos[f.month - 1] : '${_mesesLargos[f.month - 1]} de ${f.year}';
