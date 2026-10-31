// test/unitarias/comandas/nueva_comanda_test.dart — captura de comandas
// (#130) sin red: el catálogo, las cuentas en centavos, las fotos de
// referencia (con reintento), la validación con los mensajes de la web y lo
// que se manda a POST /comandas.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository_remote.dart';
import 'package:pier_reposteria/domain/models/nueva_comanda.dart';
import 'package:pier_reposteria/ui/comandas/view_model/nueva_comanda_view_model.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';

/// Lunes 12 de octubre de 2026, 10:00.
DateTime _ahora() => DateTime(2026, 10, 12, 10);

(NuevaComandaViewModel, FakeApiClient) _armar({int pct = 50}) {
  final api = FakeApiClient()
    ..responder(ApiConstants.comandasCatalogo, catalogoJson(pct: pct));
  final vm = NuevaComandaViewModel(
    repo: ComandasRepositoryRemote(api: api),
    ahora: _ahora,
  );
  return (vm, api);
}

/// Una comanda válida: un pastel de $450 y 2 gelatinas grandes ($240).
Future<NuevaComandaViewModel> _llena(FakeApiClient api,
    NuevaComandaViewModel vm) async {
  await vm.cargar();
  vm
    ..nombre = 'María López'
    ..telefono = '771 123-4567'
    ..fecha = DateTime(2026, 10, 20)
    ..hora = '16:30'
    ..anticipo = '345';
  vm.agregarPastel()
    ..sabor = 'Chocolate'
    ..tamano = '20 personas'
    ..forma = 'Redondo'
    ..decoracion = 'Flores'
    ..pisos = 2
    ..precio = '450'
    ..leyenda = 'Feliz cumple';
  vm.agregarProducto(vm.catalogo!.productos.first);
  (vm.renglones.last as ProductoBorrador)
    ..grande = true
    ..cantidad = '2';
  return vm;
}

void main() {
  group('Catálogo', () {
    test('lee opciones, ajustes y productos (precios en centavos)', () async {
      final (vm, _) = _armar();
      await vm.cargar();
      final c = vm.catalogo!;

      expect(c.opciones.sabores, ['Chocolate', 'Vainilla']);
      expect(c.opciones.decoraciones, ['Flores']);
      expect(c.ajustes.anticipoMinimoPct, 50);
      expect(c.ajustes.diasAnticipacion, 3);
      // Sin precio chico, el producto se omite.
      expect(c.productos.map((p) => p.nombre), ['Gelatina', 'Galleta']);
      expect(c.productos.first.precioChico, 4550);
      expect(c.productos.first.precioGrande, 12000);
      expect(c.productos.last.precioGrande, isNull);
      expect(vm.cargando, isFalse);
    });

    test('si falla expone el motivo; si la sesión ya no vale, lo dice',
        () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.comandasCatalogo, 'Sin conexión');
      final vm = NuevaComandaViewModel(
          repo: ComandasRepositoryRemote(api: api), ahora: _ahora);
      await vm.cargar();
      expect(vm.errorCarga, 'Sin conexión');
      expect(vm.sesionInvalida, isFalse);

      api.responder(ApiConstants.comandasCatalogo, {
        'success': false,
        'codigo': 'SESION_INVALIDA',
        'message': 'Tu cuenta cambió',
      });
      await vm.cargar();
      expect(vm.sesionInvalida, isTrue);
    });
  });

  group('Cuentas', () {
    test('leerCentavos acepta miles con coma y rechaza la coma decimal', () {
      expect(leerCentavos('450'), 45000);
      expect(leerCentavos('450.5'), 45050);
      expect(leerCentavos('1,250.50'), 125050);
      expect(leerCentavos(' 12.05 '), 1205);
      expect(leerCentavos('450,50'), isNull);
      expect(leerCentavos('-5'), isNull);
      expect(leerCentavos(''), isNull);
      expect(centavosDe('99.99'), 9999);
      expect(centavosDe('x'), isNull);
    });

    test('suma pasteles y productos, descuento, mínimo y saldo', () async {
      final (vm, api) = _armar();
      await _llena(api, vm);

      expect(vm.importe(vm.renglones.first), 45000);
      expect(vm.importe(vm.renglones.last), 24000);
      expect(vm.subtotal, 69000);
      vm.descuento = '90';
      expect(vm.total, 60000);
      expect(vm.anticipoMinimo, 30000);
      expect(vm.textoMinimo, r'Mínimo $300.00 (50 % del total)');
      vm.anticipo = '345';
      expect(vm.saldo, 25500);
      vm.descuento = '1,000';
      expect(vm.total, 0);
      expect(vm.saldo, 0);
    });

    test('el mínimo se redondea hacia arriba y sin porcentaje no hay',
        () async {
      final (vm, _) = _armar(pct: 33);
      await vm.cargar();
      vm.agregarPastel().precio = '100.01';
      expect(vm.anticipoMinimo, 3301); // 33 % de 10,001 = 3,300.33
      final (sin, _) = _armar(pct: 0);
      await sin.cargar();
      expect(sin.textoMinimo, isNull);
    });

    test('avisa si la entrega llega antes de la anticipación', () async {
      final (vm, _) = _armar();
      await vm.cargar();
      expect(vm.advertencia, isNull);
      vm.fecha = DateTime(2026, 10, 13);
      expect(vm.advertencia, contains('menos de 3 días'));
      vm.fecha = DateTime(2026, 10, 15);
      expect(vm.advertencia, isNull);
    });
  });

  group('Validación', () {
    test('sin nada capturado dice todo lo que falta', () async {
      final (vm, _) = _armar();
      await vm.cargar();

      expect(await vm.guardar(), isNull);
      expect(vm.errores, [
        'Escribe el nombre del cliente',
        'Escribe el teléfono del cliente',
        'Elige la fecha de entrega',
        'Elige la hora de entrega',
        'Agrega al menos un pastel o un producto',
        'Escribe un anticipo válido, por ejemplo 200 o 200.50',
      ]);
    });

    test('cliente, teléfono, fecha y textos largos', () async {
      final (vm, _) = _armar();
      await vm.cargar();
      vm
        ..nombre = 'A'
        ..telefono = '771-12'
        ..fecha = DateTime(2026, 10, 11)
        ..notas = 'x' * 1001;
      var e = vm.validar();
      expect(e, contains('El nombre debe tener al menos 2 letras'));
      expect(e, contains('El teléfono debe tener 10 dígitos (llevas 5)'));
      expect(e, contains('Esa fecha ya pasó; elige hoy o una fecha posterior'));
      expect(e, contains('Notas: máximo 1000 caracteres (llevas 1001)'));

      vm
        ..nombre = 'x' * 121
        ..telefono = '771abc'
        ..fecha = DateTime(2027, 11, 17);
      e = vm.validar();
      expect(e, contains('Nombre: máximo 120 caracteres (llevas 121)'));
      expect(e, contains(
          'Usa solo números (puedes separarlos con espacios o guiones)'));
      expect(e, contains('La entrega no puede ser a más de 400 días'));
    });

    test('pasteles: opciones, pisos, cantidad y precio', () async {
      final (vm, _) = _armar();
      await vm.cargar();
      vm.agregarPastel();
      vm.agregarPastel()
        ..sabor = 'Fresa'
        ..tamano = 'Gigante'
        ..forma = 'Hexagonal'
        ..decoracion = 'Fondant'
        ..pisos = 7
        ..cantidad = '21'
        ..precio = '450,50'
        ..leyenda = 'x' * 201;
      final e = vm.validar();

      expect(e, containsAll([
        'Pastel 1 · Elige el sabor',
        'Pastel 1 · Elige el tamaño',
        'Pastel 1 · Elige la forma',
        'Pastel 1 · Elige la decoración',
        'Pastel 1 · Escribe el precio del pastel',
        'Pastel 2 · Ese sabor ya no se ofrece; elige otro',
        'Pastel 2 · Ese tamaño ya no se ofrece; elige otro',
        'Pastel 2 · Esa forma ya no se ofrece; elige otra',
        'Pastel 2 · Esa decoración ya no se ofrece; elige otra',
        'Pastel 2 · Elige de 1 a 6 pisos',
        'Pastel 2 · La cantidad va de 1 a 20 pasteles',
        'Pastel 2 · Escribe un precio válido, por ejemplo 450 o 450.50',
        'Pastel 2 · Leyenda: máximo 200 caracteres (llevas 201)',
      ]));

      (vm.renglones.last as PastelBorrador).precio = '100000.01';
      expect(vm.validar(),
          contains(r'Pastel 2 · El precio no puede pasar de $100,000'));
    });

    test('productos: tamaño grande que no existe y cantidad', () async {
      final (vm, _) = _armar();
      await vm.cargar();
      vm.agregarProducto(vm.catalogo!.productos.last);
      (vm.renglones.last as ProductoBorrador)
        ..grande = true
        ..cantidad = '1000';
      final e = vm.validar();
      expect(e, contains('Galleta · Este producto solo se vende en tamaño chico'));
      expect(e, contains('Galleta · La cantidad va de 1 a 999 piezas'));
    });

    test('descuento y anticipo fuera de las reglas', () async {
      final (vm, api) = _armar();
      await _llena(api, vm);
      vm
        ..descuento = '50,5'
        ..anticipo = '100';
      var e = vm.validar();
      expect(e, contains('Escribe un descuento válido, por ejemplo 50 o 50.00'));
      expect(e, contains(r'El anticipo mínimo es $345.00 (50 % del total)'));

      vm
        ..descuento = '700'
        ..anticipo = '700';
      e = vm.validar();
      expect(e, contains(
          r'El descuento no puede ser mayor que el subtotal ($690.00)'));

      vm
        ..descuento = ''
        ..anticipo = '700';
      expect(vm.validar(),
          contains(r'El anticipo no puede ser mayor que el total ($690.00)'));
    });

    test('a 30 renglones ya no se puede agregar', () async {
      final (vm, _) = _armar();
      await vm.cargar();
      for (var i = 0; i < NuevaComandaViewModel.maxRenglones; i++) {
        vm.agregarPastel();
      }
      expect(vm.puedeAgregar, isFalse);
      vm.renglones.add(PastelBorrador(99));
      expect(vm.validar(), contains(
          'Una comanda admite hasta 30 renglones (llevas 31); divide el '
          'pedido en dos comandas'));
    });
  });

  group('Fotos de referencia', () {
    test('se suben una por una y se mandan con la comanda', () async {
      final (vm, api) = _armar();
      api.responder(ApiConstants.comandasImagenes, {
        'success': true,
        'imagen': {
          'url': 'https://res.cloudinary.com/demo/image/upload/a.jpg',
          'public_id': 'pier-reposteria/comandas/a',
        },
      });
      await _llena(api, vm);

      await vm.agregarFoto('/fotos/pastel.jpg');

      expect(vm.fotos.single.estado, EstadoFoto.lista);
      expect(api.ultima(ApiConstants.comandasImagenes)!.body,
          {'filePath': '/fotos/pastel.jpg'});
      expect(vm.cuerpo()['imagenes'], [
        {
          'url': 'https://res.cloudinary.com/demo/image/upload/a.jpg',
          'public_id': 'pier-reposteria/comandas/a',
        },
      ]);
    });

    test('si falla se puede reintentar o quitar sin perder lo capturado',
        () async {
      final (vm, api) = _armar();
      api.fallar(ApiConstants.comandasImagenes, 'La imagen pesa más de 10 MB');
      await _llena(api, vm);

      await vm.agregarFoto('/fotos/grande.jpg');
      final foto = vm.fotos.single;
      expect(foto.estado, EstadoFoto.fallo);
      expect(foto.error, 'La imagen pesa más de 10 MB');
      expect(vm.validar(), contains(
          'Hay imágenes que no se subieron: reinténtalas o quítalas'));
      expect(vm.nombre, 'María López');

      api.responder(ApiConstants.comandasImagenes, {
        'success': true,
        'imagen': {'url': 'https://res.cloudinary.com/x.jpg', 'public_id': 'p'},
      });
      await vm.reintentarFoto(foto);
      expect(foto.estado, EstadoFoto.lista);

      vm.quitarFoto(foto);
      expect(vm.fotos, isEmpty);
    });

    test('sin url o public_id cuenta como falla; máximo 10', () async {
      final (vm, api) = _armar();
      api.responder(ApiConstants.comandasImagenes, {
        'success': true,
        'imagen': {'url': 'https://res.cloudinary.com/x.jpg'},
      });
      await vm.cargar();
      await vm.agregarFoto('/a.jpg');
      expect(vm.fotos.single.error, 'No se pudo subir la foto');

      for (var i = 0; i < 12; i++) {
        await vm.agregarFoto('/$i.jpg');
      }
      expect(vm.fotos, hasLength(NuevaComandaViewModel.maxFotos));
      expect(vm.puedeAgregarFoto, isFalse);
    });

    test('mientras sube no deja guardar', () async {
      final (vm, api) = _armar();
      await _llena(api, vm);
      vm.fotos.add(FotoBorrador(50, '/b.jpg'));
      expect(vm.validar(),
          contains('Espera a que terminen de subir las imágenes'));
    });
  });

  group('Guardar', () {
    test('manda el cuerpo de la web y devuelve folio y advertencias',
        () async {
      final (vm, api) = _armar();
      api.responder(ApiConstants.comandas, {
        'success': true,
        'comanda': {'id': 31, 'folio': 5120},
        'advertencias': ['La entrega es en menos de 3 días'],
        'message': 'Comanda #5120 creada',
      });
      await _llena(api, vm);
      vm
        ..notas = '  '
        ..descuento = '10.50';

      final creada = await vm.guardar();

      expect(creada!.id, 31);
      expect(creada.folio, 5120);
      expect(creada.mensaje, 'Comanda #5120 creada');
      expect(creada.advertencias, ['La entrega es en menos de 3 días']);
      expect(vm.errores, isEmpty);
      expect(api.ultima(ApiConstants.comandas)!.body, {
        'cliente_nombre': 'María López',
        'cliente_telefono': '7711234567',
        'fecha_entrega': '2026-10-20',
        'hora_entrega': '16:30',
        'notas': null,
        'descuento': 10.5,
        'anticipo': 345.0,
        'items': [
          {
            'tipo': 'pastel',
            'cantidad': 1,
            'sabor': 'Chocolate',
            'tamano': '20 personas',
            'forma': 'Redondo',
            'decoracion': 'Flores',
            'num_pisos': 2,
            'leyenda': 'Feliz cumple',
            'descripcion': null,
            'precio_unitario': 450.0,
          },
          {
            'tipo': 'producto',
            'producto_id': 10,
            'tamano_catalogo': 'grande',
            'cantidad': 2,
          },
        ],
        'imagenes': <Object>[],
      });
    });

    test('si el backend la rechaza muestra todos sus motivos', () async {
      final (vm, api) = _armar();
      api.responder(ApiConstants.comandas, {
        'success': false,
        'message': 'Pastel 1 · Sabor: ya no se ofrece',
        'errores': [
          'Pastel 1 · Sabor: ya no se ofrece',
          'Gelatina · Cantidad: no válida',
        ],
      });
      await _llena(api, vm);

      expect(await vm.guardar(), isNull);
      expect(vm.errores, [
        'Pastel 1 · Sabor: ya no se ofrece',
        'Gelatina · Cantidad: no válida',
      ]);
      expect(vm.guardando, isFalse);
    });

    test('un error sin lista, sin comanda o de sesión', () async {
      final (vm, api) = _armar();
      api.fallar(ApiConstants.comandas, 'Error al crear la comanda');
      await _llena(api, vm);
      expect(await vm.guardar(), isNull);
      expect(vm.errores, ['Error al crear la comanda']);

      api.responder(ApiConstants.comandas, {'success': true});
      expect(await vm.guardar(), isNull);
      expect(vm.errores, ['No se pudo crear la comanda']);

      api.responder(ApiConstants.comandas, {
        'success': false,
        'codigo': 'SESION_INVALIDA',
        'message': 'Tu cuenta cambió',
      });
      expect(await vm.guardar(), isNull);
      expect(vm.sesionInvalida, isTrue);
    });

    test('el repositorio lanza ApiException con los motivos unidos', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.comandas, {
          'success': false,
          'errores': ['Uno', 'Dos'],
        });
      await expectLater(
        ComandasRepositoryRemote(api: api).crear(const {}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Uno\nDos')),
      );
    });
  });

  group('Editar (#228)', () {
    (NuevaComandaViewModel, FakeApiClient) editar({int productoId = 10}) {
      final api = FakeApiClient()
        ..responder(ApiConstants.comandasCatalogo, catalogoJson())
        ..responder(ApiConstants.comandaDetalle(7),
            comandaEditableJson(productoId: productoId));
      return (
        NuevaComandaViewModel(
          repo: ComandasRepositoryRemote(api: api),
          editarId: 7,
          ahora: _ahora,
        ),
        api,
      );
    }

    test('carga la comanda en el formulario', () async {
      final (vm, _) = editar();
      expect(vm.editando, isTrue);
      await vm.cargar();

      expect(vm.folio, 5003);
      expect(vm.nombre, 'María López');
      expect(vm.telefono, '7711234567');
      expect(vm.fecha, DateTime(2026, 10, 20));
      expect(vm.hora, '16:30');
      expect(vm.notas, 'Sin nuez');
      expect(vm.descuento, '');
      expect(vm.anticipo, '400.00');
      final pastel = vm.renglones.first as PastelBorrador;
      expect([pastel.sabor, pastel.tamano, pastel.forma, pastel.decoracion],
          ['Chocolate', '20 personas', 'Redondo', 'Flores']);
      expect(pastel.pisos, 2);
      expect(pastel.precio, '450.00');
      expect(pastel.leyenda, 'Feliz cumple');
      final producto = vm.renglones.last as ProductoBorrador;
      expect(producto.producto.precioGrande, 12000);
      expect(producto.grande, isTrue);
      expect(producto.cantidad, '2');
      expect(vm.fotos.single.estado, EstadoFoto.lista);
      expect(vm.subtotal, 69000);
      expect(vm.validar(), isEmpty);
    });

    test('guarda con la versión y conserva lo que el formulario no edita',
        () async {
      final (vm, api) = editar();
      await vm.cargar();
      api.responder(ApiConstants.comandaDetalle(7), {
        'success': true,
        'comanda': {'id': 7, 'folio': 5003, 'version': 2},
        'advertencias': <String>[],
        'message': 'Comanda #5003 actualizada',
      });
      vm.notas = 'Con nuez';

      final r = await vm.guardar();

      expect(r!.folio, 5003);
      expect(r.mensaje, 'Comanda #5003 actualizada');
      final body = api.ultima(ApiConstants.comandaDetalle(7))!.body!;
      expect(api.ultima(ApiConstants.comandaDetalle(7))!.metodo, 'PUT-Auth');
      expect(body['actualizada_en'], '2026-10-12T15:00:00.123Z');
      expect(body['notas'], 'Con nuez');
      expect(body['mesa_color_capacillos'], 'Dorado');
      expect(body['mesa_color_betun'], isNull);
      final items = body['items'] as List;
      expect(items.first, containsPair('color_fondo', 'Rosa'));
      expect(items.first, containsPair('insumos', 'Velas'));
      expect(items.last, containsPair('indicaciones', 'Sin fresa'));
      expect(body['imagenes'], [
        {
          'url': 'https://res.cloudinary.com/demo/image/upload/a.jpg',
          'public_id': 'pier-reposteria/comandas/a',
        },
      ]);
    });

    test('si otra persona la guardó antes, lo dice y deja recargarla',
        () async {
      final (vm, api) = editar();
      await vm.cargar();
      api.responder(ApiConstants.comandaDetalle(7), {
        'success': false,
        'codigo': 'COMANDA_DESACTUALIZADA',
        'message': 'Alguien más modificó esta comanda mientras la editabas. '
            'Recárgala para ver la versión actual.',
      });
      vm.notas = 'Mi cambio';

      expect(await vm.guardar(), isNull);
      expect(vm.desactualizada, isTrue);
      expect(vm.errores.single, startsWith('Alguien más modificó'));

      api.responder(ApiConstants.comandaDetalle(7),
          comandaEditableJson(actualizada: '2026-10-12T16:00:00.000Z'));
      await vm.recargarComanda();

      expect(vm.desactualizada, isFalse);
      expect(vm.errores, isEmpty);
      expect(vm.notas, 'Sin nuez');
    });

    test('un producto que ya no está en el catálogo pide quitarlo', () async {
      final (vm, _) = editar(productoId: 99);
      await vm.cargar();

      final producto = vm.renglones.last as ProductoBorrador;
      expect(producto.descontinuado, isTrue);
      expect(producto.precio, 12000);
      expect(vm.validar(), contains(
          'Gelatina · Este producto ya no está disponible; quítalo de la '
          'comanda'));
    });

    test('si la comanda no carga se ve el motivo', () async {
      final (vm, api) = editar();
      api.fallar(ApiConstants.comandaDetalle(7), 'Comanda no encontrada');
      await vm.cargar();
      expect(vm.catalogo, isNull);
      expect(vm.errorCarga, 'Comanda no encontrada');
    });
  });
}
