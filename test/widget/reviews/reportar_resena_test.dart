// test/widget/reviews/reportar_resena_test.dart — «Reportar» en las reseñas
// de otros clientes (#328): en «Opiniones» y en las opiniones destacadas del
// detalle; abre el correo ya escrito y, sin app de correo, dice a dónde
// escribir.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/domain/models/resena_producto.dart';
import 'package:pier_reposteria/ui/products/widgets/detalle_resenas.dart';
import 'package:pier_reposteria/ui/reviews/view_model/product_reviews_view_model.dart';
import 'package:pier_reposteria/ui/reviews/view_model/reporte_resena.dart';
import 'package:pier_reposteria/ui/reviews/widgets/product_reviews_screen.dart';
import 'package:pier_reposteria/ui/reviews/widgets/reportar_resena.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_comandas.dart' show capturarUrls;
import '../../helpers/pump_app.dart';

final _producto = Product(
  id: '36',
  nombre: 'Fresa Matcha Bliss',
  precio: 320,
  imagenUrl: '',
  descripcion: '',
  categoria: 'Pasteles',
);

/// Dos opiniones: la 1 es del cliente con sesión y la 2 de otro.
FakeApiClient _api() => FakeApiClient(respuestas: {
      ApiConstants.resenasPorProducto('36'): {
        'success': true,
        'resenas': [
          {'id': 1, 'rating': 5, 'comentario': 'La mía', 'autor_nombre': 'Ana'},
          {
            'id': 2,
            'rating': 1,
            'comentario': 'Texto ofensivo',
            'autor_nombre': 'Luis',
            'autor_apellido': 'Pérez',
          },
        ],
      },
      ApiConstants.misResenas: {
        'success': true,
        'resenas': [
          {'id': 1, 'estado': 'aprobada', 'producto_nombre': 'Fresa'},
        ],
      },
    });

/// Monta «Opiniones»; con [conSesion] vuelve a cargar como lo haría con la
/// sesión abierta (la del montaje es sin sesión).
Future<ProductReviewsViewModel> _montar(
  WidgetTester tester, {
  bool conSesion = false,
}) async {
  final api = _api();
  final vm = ProductReviewsViewModel(
    repo: ResenasRepositoryRemote(api: api),
    productoId: _producto.id,
  );
  await tester.pumpApp(
    ProductReviewsScreen(product: _producto, viewModel: vm),
    api: api,
  );
  await tester.pumpAndSettle();
  if (conSesion) {
    await vm.cargar(conSesion: true);
    await tester.pumpAndSettle();
  }
  return vm;
}

Future<void> _reportarLaDeOtro(WidgetTester tester) async {
  final boton = find.text(ReportarResena.etiqueta);
  await tester.ensureVisible(boton.last);
  await tester.tap(boton.last);
  await tester.pumpAndSettle();
}

void main() {
  group('«Opiniones»', () {
    testWidgets('sin sesión se ofrece en todas', (tester) async {
      await _montar(tester);

      expect(find.text(ReportarResena.etiqueta), findsNWidgets(2));
    });

    testWidgets('con sesión no aparece en la propia', (tester) async {
      await _montar(tester, conSesion: true);

      expect(find.text(ReportarResena.etiqueta), findsOneWidget);
    });

    testWidgets('al tocarlo abre el correo ya escrito', (tester) async {
      final urls = capturarUrls(tester);
      await _montar(tester, conSesion: true);

      await _reportarLaDeOtro(tester);

      final correo = Uri.parse(urls.single! as String);
      expect(correo.scheme, 'mailto');
      expect(correo.path, BusinessInfo.email);
      expect(correo.queryParameters['subject'],
          'Reportar reseña #2 de Fresa Matcha Bliss');
      expect(correo.queryParameters['body'], contains('Texto: Texto ofensivo'));
      expect(find.text(ReporteResena.sinAppDeCorreo(BusinessInfo.email)),
          findsNothing);
    });

    testWidgets('sin app de correo dice a dónde escribir', (tester) async {
      const canal = MethodChannel('plugins.flutter.io/url_launcher');
      final mensajero = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(canal, (_) async => false);
      addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
      await _montar(tester);

      await _reportarLaDeOtro(tester);

      expect(find.text(ReporteResena.sinAppDeCorreo(BusinessInfo.email)),
          findsOneWidget);
    });
  });

  group('Opiniones destacadas del detalle', () {
    final resena = ResenaProducto.fromJson({
      'id': 4,
      'rating': 2,
      'comentario': 'No me gustó',
      'autor_nombre': 'Luis',
      'usuario_id': 8,
    });

    testWidgets('sin correo de reporte no aparece «Reportar»',
        (tester) async {
      await tester.pumpApp(Scaffold(
          body: ResenaDestacadaItem(resena: resena, onUtil: () {})));

      expect(find.text(ReportarResena.etiqueta), findsNothing);
    });

    testWidgets('con él, al tocarlo abre el correo', (tester) async {
      final urls = capturarUrls(tester);
      await tester.pumpApp(Scaffold(
        body: ResenaDestacadaItem(
          resena: resena,
          onUtil: () {},
          correoReporte: () async => ReporteResena.correo(
            resena: resena,
            productoId: '36',
            productoNombre: 'Fresa Matcha Bliss',
          ),
        ),
      ));

      await tester.tap(find.text(ReportarResena.etiqueta));
      await tester.pumpAndSettle();

      expect(Uri.parse(urls.single! as String).queryParameters['subject'],
          'Reportar reseña #4 de Fresa Matcha Bliss');
    });
  });
}
