import 'package:app_finanzas/domain/clasificacion/historial_comercios.dart';
import 'package:test/test.dart';

void main() {
  test('un comercio visto una sola vez se asigna a esa categoría', () {
    final historial = construirHistorialComercios([
      const ObservacionComercio('Oxxo Insurgentes', 'super'),
    ]);
    expect(historial['oxxo insurgentes'], 'super');
  });

  test('mismo comercio normalizado con mayúsculas/acentos distintos se agrupa junto', () {
    final historial = construirHistorialComercios([
      const ObservacionComercio('Café Starbucks', 'salidas'),
      const ObservacionComercio('café starbucks', 'salidas'),
      const ObservacionComercio('CAFE STARBUCKS', 'salidas'),
    ]);
    expect(historial, hasLength(1));
    expect(historial['cafe starbucks'], 'salidas');
  });

  test('cuando un comercio tuvo categorías distintas, gana la más frecuente', () {
    final historial = construirHistorialComercios([
      const ObservacionComercio('Farmacia Guadalajara', 'salud'),
      const ObservacionComercio('Farmacia Guadalajara', 'salud'),
      const ObservacionComercio('Farmacia Guadalajara', 'salud'),
      const ObservacionComercio('Farmacia Guadalajara', 'super'), // una corrección aislada
    ]);
    expect(historial['farmacia guadalajara'], 'salud');
  });

  test('descripción vacía se ignora', () {
    final historial = construirHistorialComercios([
      const ObservacionComercio('', 'super'),
      const ObservacionComercio('   ', 'super'),
    ]);
    expect(historial, isEmpty);
  });

  test('lista vacía da historial vacío', () {
    expect(construirHistorialComercios([]), isEmpty);
  });
}
