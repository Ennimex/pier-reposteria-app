// test/widget/more/foto_perfil_editable_test.dart — el avatar de «Mi perfil»
// (#345): la hoja de opciones, subir una foto de la galería, quitarla, el
// mensaje si falla y la explicación antes de abrir la cámara. La foto llega de
// un selector falso (sin image_picker).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/ui/explicacion_permiso.dart';
import 'package:pier_reposteria/ui/more/widgets/foto_perfil_editable.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

const _url = 'https://res.cloudinary.com/pier/image/upload/perfil/ana.webp';

/// Backend con la cuenta de Ana ([avatar]: su foto actual).
FakeApiClient _backend({String? avatar}) => FakeApiClient(respuestas: {
      ApiConstants.login: {
        'success': true,
        'token': 'jwt',
        'user': {
          'id': 9,
          'nombre': 'Ana',
          'apellido': 'García',
          'email': 'ana@pier.mx',
          'rol': 'cliente',
          'avatar_url': avatar,
        },
      },
      ApiConstants.uploadImagen: {
        'success': true,
        'imagen': {'url': _url, 'public_id': 'perfil/ana'},
      },
      ApiConstants.updateProfileData: (LlamadaApi llamada) => <String, dynamic>{
            'success': true,
            'user': {
              'id': 9,
              'nombre': 'Ana',
              'apellido': 'García',
              'avatar_url': llamada.body?['avatar_url'],
            },
          },
    });

/// Monta el avatar con la sesión de Ana. Devuelve de dónde se pidió cada
/// foto; el selector falso entrega [foto] (null = se canceló).
Future<List<ImageSource>> _montar(
  WidgetTester tester,
  FakeApiClient api, {
  String? foto = '/fotos/ana.jpg',
}) async {
  final pedidas = <ImageSource>[];
  await tester.pumpApp(
    Scaffold(
      body: Center(
        child: FotoPerfilEditable(
          elegirFoto: (fuente) async {
            pedidas.add(fuente);
            return foto;
          },
        ),
      ),
    ),
    api: api,
  );
  await tester.iniciarSesion(find.byType(FotoPerfilEditable));
  await tester.pump();
  return pedidas;
}

Map<String, dynamic>? _sesion(WidgetTester tester) => tester
    .element(find.byType(FotoPerfilEditable))
    .read<AuthProvider>()
    .currentUser;

Future<void> _elegir(WidgetTester tester, String opcion) async {
  await tester.tap(find.byType(FotoPerfilEditable));
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcion));
  await tester.pumpAndSettle();
}

void main() {
  group('FotoPerfilEditable (#345)', () {
    testWidgets('sin foto muestra las iniciales y la hoja no ofrece quitarla',
        (tester) async {
      await _montar(tester, _backend());

      expect(find.text('AG'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Cambiar foto de perfil')),
          findsOneWidget);

      await tester.tap(find.byType(FotoPerfilEditable));
      await tester.pumpAndSettle();
      expect(find.text('Tomar foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.text('Quitar foto'), findsNothing);
    });

    testWidgets('una foto de la galería se sube y queda en la sesión',
        (tester) async {
      final api = _backend();
      final pedidas = await _montar(tester, api);

      await _elegir(tester, 'Elegir de la galería');

      expect(pedidas, [ImageSource.gallery]);
      expect(api.llamo(ApiConstants.uploadImagen, metodo: 'UPLOAD'), isTrue);
      expect(_sesion(tester)?['avatar_url'], _url);
      expect(find.text('Tu foto de perfil se actualizó'), findsOneWidget);
    });

    testWidgets('con foto, «Quitar foto» la borra de la sesión',
        (tester) async {
      final api = _backend(avatar: _url);
      await _montar(tester, api);

      await _elegir(tester, 'Quitar foto');

      expect(api.llamadas.last.body, {'avatar_url': null});
      expect(_sesion(tester)?['avatar_url'], isNull);
      expect(find.text('Quitamos tu foto de perfil'), findsOneWidget);
    });

    testWidgets('si la foto no se pudo subir lo dice y la sesión no cambia',
        (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.uploadImagen, 'La foto pesa más de 5 MB');
      await _montar(tester, api);

      await _elegir(tester, 'Elegir de la galería');

      expect(find.text('La foto pesa más de 5 MB'), findsOneWidget);
      expect(_sesion(tester)?['avatar_url'], isNull);
      expect(api.llamo(ApiConstants.updateProfileData), isFalse);
    });

    testWidgets('si se cancela la galería no se sube nada', (tester) async {
      final api = _backend();
      await _montar(tester, api, foto: null);

      await _elegir(tester, 'Elegir de la galería');

      expect(api.llamo(ApiConstants.uploadImagen), isFalse);
    });

    testWidgets('antes de la cámara explica para qué; «Ahora no» no la abre',
        (tester) async {
      final pedidas = await _montar(tester, _backend());

      await _elegir(tester, 'Tomar foto');
      expect(find.text(ExplicacionDePermiso.camaraPerfil.titulo),
          findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(pedidas, isEmpty);
    });

    testWidgets('mientras sube muestra el indicador y no abre otra hoja',
        (tester) async {
      final api = _backend()
        ..demorar(ApiConstants.uploadImagen, const Duration(seconds: 1));
      await _montar(tester, api);

      await tester.tap(find.byType(FotoPerfilEditable));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FotoPerfilEditable));
      await tester.pump();
      expect(find.text('Tomar foto'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_sesion(tester)?['avatar_url'], _url);
    });
  });
}
