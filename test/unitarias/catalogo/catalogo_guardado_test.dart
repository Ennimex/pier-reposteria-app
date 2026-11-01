// test/unitarias/catalogo/catalogo_guardado_test.dart — la copia de la primera
// página del catálogo en el teléfono (#265): Product.toJson devuelve lo que
// Product.fromJson lee y CatalogoGuardadoService guarda y lee esa página en
// SharedPreferences con su fecha. Sin copia, con un valor ilegible o sin
// productos no hay copia que mostrar, y guardar nunca lanza. Sin red.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/data/services/catalogo_guardado_service.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _llave = 'pierreposteria_catalogo_v1';

/// Un producto con todos los campos distintos de su valor por omisión.
Product _completo() => Product(
      id: '42',
      nombre: 'Pay de limón',
      descripcion: 'Con merengue y galleta',
      precio: 180.5,
      precioGrande: 320,
      categoria: 'Pays',
      imagenUrl: 'https://res.cloudinary.com/pier/image/upload/v1/pay.jpg',
      imagenes: const [
        'https://res.cloudinary.com/pier/image/upload/v1/pay.jpg',
        'https://res.cloudinary.com/pier/image/upload/v1/pay-corte.jpg',
      ],
      ingredientes: const ['Limón', 'Galleta', 'Merengue'],
      sabor: 'Limón',
      tamano: 'Grande',
      tipo: 'Frío',
      popular: true,
      esNuevo: true,
      stockOnline: 7,
      rating: 4.5,
      totalResenas: 12,
    );

/// Un producto agotado y ya no activo.
Product _agotado() => Product(
      id: '7',
      nombre: 'Rosca de reyes',
      descripcion: '',
      precio: 99,
      categoria: 'Roscas',
      imagenUrl: '',
      stockOnline: 0,
      disponible: false,
    );

/// Un producto con solo lo obligatorio: lo demás queda en su valor por
/// omisión (sin stock conocido, sin precio grande, sin fotos).
Product _minimo() => Product(
      id: '1',
      nombre: 'Concha',
      descripcion: 'De vainilla',
      precio: 25,
      categoria: 'Panes',
      imagenUrl: '',
    );

/// Todos los campos de [p], para compararlos de un golpe y ver cuál difiere.
Map<String, Object?> _campos(Product p) => {
      'id': p.id,
      'nombre': p.nombre,
      'descripcion': p.descripcion,
      'precio': p.precio,
      'precioGrande': p.precioGrande,
      'categoria': p.categoria,
      'imagenUrl': p.imagenUrl,
      'imagenes': p.imagenes,
      'ingredientes': p.ingredientes,
      'sabor': p.sabor,
      'tamano': p.tamano,
      'tipo': p.tipo,
      'popular': p.popular,
      'esNuevo': p.esNuevo,
      'stockOnline': p.stockOnline,
      'disponible': p.disponible,
      'rating': p.rating,
      'totalResenas': p.totalResenas,
    };

/// Un producto cuyo toJson falla, como si no se pudiera convertir.
class _ProductoQueFalla extends Product {
  _ProductoQueFalla()
      : super(
          id: '0',
          nombre: 'Falla',
          descripcion: '',
          precio: 1,
          categoria: '',
          imagenUrl: '',
        );

  @override
  Map<String, dynamic> toJson() => throw StateError('no se puede convertir');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Product.toJson', () {
    test('toJson y fromJson dan el mismo producto', () {
      for (final original in [_completo(), _agotado(), _minimo()]) {
        // Pasa por el texto JSON, como cuando se guarda en el teléfono.
        final texto = jsonEncode(original.toJson());
        final leido =
            Product.fromJson(jsonDecode(texto) as Map<String, dynamic>);

        expect(_campos(leido), _campos(original), reason: original.nombre);
      }
    });
  });

  group('CatalogoGuardadoService', () {
    test('guarda y lee la primera página', () async {
      final pagina = [_completo(), _agotado(), _minimo()];

      await CatalogoGuardadoService().guardar(pagina);
      // Otra instancia la lee: la copia queda en el teléfono, no en el objeto.
      final copia = await CatalogoGuardadoService().leer();

      expect(copia, isNotNull);
      expect(
        [for (final p in copia!) _campos(p)],
        [for (final p in pagina) _campos(p)],
      );
    });

    test('guarda la fecha en UTC con formato ISO 8601', () async {
      // Hora local, para comprobar que se guarda en UTC sea cual sea la zona.
      final ahora = DateTime(2026, 10, 31, 9, 30);

      await CatalogoGuardadoService(ahora: () => ahora).guardar([_minimo()]);

      final prefs = await SharedPreferences.getInstance();
      final guardado =
          jsonDecode(prefs.getString(_llave)!) as Map<String, dynamic>;
      final fecha = guardado['guardado'] as String;
      expect(fecha, endsWith('Z'));
      expect(DateTime.parse(fecha).isAtSameMomentAs(ahora), isTrue);
      expect(guardado['productos'], hasLength(1));
    });

    test('guardar de nuevo reemplaza la copia anterior', () async {
      final servicio = CatalogoGuardadoService();
      await servicio.guardar([_completo(), _agotado()]);

      await servicio.guardar([_minimo()]);

      final copia = await servicio.leer();
      expect([for (final p in copia!) p.id], ['1']);
    });

    test('sin copia o con JSON dañado devuelve null', () async {
      final servicio = CatalogoGuardadoService();
      expect(await servicio.leer(), isNull, reason: 'sin copia');

      for (final danado in [
        'no es json',
        '[]',
        '{"guardado": "2026-10-31T00:00:00.000Z"}',
        '{"productos": 3}',
        '{"productos": [1]}',
        '{"productos": [{"id": 1, "nombre": 5}]}',
        // Sin productos tampoco hay copia que mostrar.
        '{"guardado": "2026-10-31T00:00:00.000Z", "productos": []}',
      ]) {
        SharedPreferences.setMockInitialValues({_llave: danado});
        expect(await servicio.leer(), isNull, reason: danado);
      }
    });

    test('una página vacía no es una copia: se queda la anterior', () async {
      final servicio = CatalogoGuardadoService();
      await servicio.guardar([_completo()]);

      await servicio.guardar(const []);

      final copia = await servicio.leer();
      expect([for (final p in copia!) p.id], ['42']);
    });

    test('guardar no lanza aunque un producto no se pueda convertir', () async {
      final servicio = CatalogoGuardadoService();
      await servicio.guardar([_completo()]);

      await servicio.guardar([_ProductoQueFalla()]);

      // La copia anterior sigue ahí.
      final copia = await servicio.leer();
      expect([for (final p in copia!) p.id], ['42']);
    });
  });
}
