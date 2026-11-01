// test/unitarias/catalogo/consulta_catalogo_test.dart — consulta del catálogo (#37):
// qué parámetros manda a GET /productos, qué órdenes se piden por páginas del
// servidor y cómo se arma la URL. Sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/domain/models/consulta_catalogo.dart';

/// Una consulta con valores que no son constantes, para tener dos instancias
/// distintas con los mismos criterios.
ConsultaCatalogo _consulta({
  String categoria = 'Pays',
  String busqueda = 'limón',
  String? sabor,
  String? tamano,
  String? tipo,
  SortOption orden = SortOption.rating,
}) =>
    ConsultaCatalogo(
      categoria: categoria,
      busqueda: busqueda,
      sabor: sabor,
      tamano: tamano,
      tipo: tipo,
      orden: orden,
    );

void main() {
  group('ConsultaCatalogo', () {
    test('por omisión no manda parámetros y es la consulta por omisión', () {
      const consulta = ConsultaCatalogo();

      expect(consulta.parametros, isEmpty);
      expect(consulta.esPorOmision, isTrue);
      expect(consulta.pideTodo, isFalse);
    });

    test('categoría, búsqueda recortada y filtros', () {
      const consulta = ConsultaCatalogo(
        categoria: 'Pays',
        busqueda: '  limón ',
        sabor: 'Limón',
        tamano: 'Grande',
        tipo: 'Frío',
      );

      expect(consulta.parametros, {
        'categoria': 'Pays',
        'busqueda': 'limón',
        'sabor': 'Limón',
        'tamano': 'Grande',
        'tipo': 'Frío',
      });
      expect(consulta.esPorOmision, isFalse);

      // «Todos» y una búsqueda vacía (o de puros espacios) no se mandan.
      for (final busqueda in ['', '   ']) {
        final sinFiltro = _consulta(
          categoria: ConsultaCatalogo.todas,
          busqueda: busqueda,
          orden: SortOption.popular,
        );
        expect(sinFiltro.parametros, isEmpty, reason: '"$busqueda"');
        expect(sinFiltro.esPorOmision, isTrue, reason: '"$busqueda"');
      }
    });

    test('cada orden y su valor del servidor', () {
      const esperado = <SortOption, String?>{
        SortOption.popular: null,
        SortOption.priceAsc: 'precio-asc',
        SortOption.priceDesc: 'precio-desc',
        SortOption.nameAsc: 'nombre',
        SortOption.rating: 'rating',
      };
      // Si se agrega un orden, esta prueba obliga a decidir su valor.
      expect(esperado.keys, unorderedEquals(SortOption.values));

      for (final caso in esperado.entries) {
        final parametros = ConsultaCatalogo(orden: caso.key).parametros;
        expect(parametros['ordenar'], caso.value, reason: caso.key.name);
        // El orden por omisión del servidor es el popular: no se manda.
        expect(
          parametros.containsKey('ordenar'),
          caso.value != null,
          reason: caso.key.name,
        );
      }
    });

    test('precio y calificación piden todo; populares y nombre por páginas',
        () {
      const piden = {
        SortOption.priceAsc,
        SortOption.priceDesc,
        SortOption.rating,
      };

      for (final orden in SortOption.values) {
        expect(
          ConsultaCatalogo(orden: orden).pideTodo,
          piden.contains(orden),
          reason: orden.name,
        );
      }
      expect(ConsultaCatalogo.ordenesConPaginasDelServidor,
          {SortOption.popular, SortOption.nameAsc});
    });

    test('dos consultas con los mismos criterios son iguales', () {
      final consulta = _consulta(sabor: 'Limón');

      expect(consulta, _consulta(sabor: 'Limón'));
      expect(consulta.hashCode, _consulta(sabor: 'Limón').hashCode);
      expect(consulta, isNot(equals(1)));

      // Cambiar cualquier criterio la hace otra consulta.
      final distintas = [
        _consulta(sabor: 'Limón', categoria: 'Roscas'),
        _consulta(sabor: 'Limón', busqueda: 'fresa'),
        _consulta(),
        _consulta(sabor: 'Limón', tamano: 'Grande'),
        _consulta(sabor: 'Limón', tipo: 'Frío'),
        _consulta(sabor: 'Limón', orden: SortOption.nameAsc),
      ];
      for (final otra in distintas) {
        expect(otra, isNot(consulta));
      }
    });
  });

  group('ApiConstants.consultaProductos', () {
    test('sin parámetros es el catálogo completo', () {
      expect(ApiConstants.consultaProductos(const {}), '/productos');
    });

    test('con parámetros los codifica en la query', () {
      expect(
        ApiConstants.consultaProductos(
          const {'categoria': 'Pays', 'busqueda': 'pay de limón'},
        ),
        '/productos?categoria=Pays&busqueda=pay+de+lim%C3%B3n',
      );
    });

    test('la búsqueda no puede colarse otros parámetros', () {
      expect(
        ApiConstants.consultaProductos(const {'busqueda': 'a&limite=1#x=y'}),
        '/productos?busqueda=a%26limite%3D1%23x%3Dy',
      );
    });
  });
}
