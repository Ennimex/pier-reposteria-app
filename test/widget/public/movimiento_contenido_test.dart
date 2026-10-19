// test/widget/public/movimiento_contenido_test.dart — el movimiento de las
// pantallas de contenido: las piezas de movimiento_contenido.dart (espera de
// la página, pop de entrada, estrellas, insignia de éxito, sacudida por
// aviso, cuenta rodante, destello del pulgar de «útil», aro de lo recién
// llegado o cambiado, entradas que esperan a verse y cifras que se cuentan)
// y lo que hacen en Nosotros (paralaje, título que se desvanece, cifras al
// verse), Contacto (sacudida de los campos inválidos, insignia sin
// chispas), Preguntas frecuentes (tarjeta que se eleva, categoría que
// cierra las preguntas, chip centrado) y Marco legal (solo la primera
// pestaña entra y la página que se va se atenúa). Con movimiento reducido,
// cada pieza queda en su lugar. Sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/public/view_model/about_us_view_model.dart';
import 'package:pier_reposteria/ui/public/view_model/contact_view_model.dart';
import 'package:pier_reposteria/ui/public/view_model/faq_view_model.dart';
import 'package:pier_reposteria/ui/public/view_model/legal_view_model.dart';
import 'package:pier_reposteria/ui/public/widgets/about_us_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/contact_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/faq_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/legal_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/movimiento_contenido.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

// ── Utilidades ──────────────────────────────────────────────────────────

/// Desplazamiento horizontal actual del primer Transform dentro de [de].
double _dxEn(WidgetTester tester, Finder de) => tester
    .widget<Transform>(
      find.descendant(of: de, matching: find.byType(Transform)).first,
    )
    .transform
    .getTranslation()
    .x;

/// La sacudida que envuelve a [hijo].
Finder _sacudidaDe(Finder hijo) =>
    find.ancestor(of: hijo, matching: find.byType(Sacudida)).first;

/// La EntradaAlVer más cercana a [hijo].
Finder _entradaAlVerDe(Finder hijo) =>
    find.ancestor(of: hijo, matching: find.byType(EntradaAlVer)).first;

/// La EntradaSuave más cercana a [hijo].
Finder _entradaSuaveDe(Finder hijo) =>
    find.ancestor(of: hijo, matching: find.byType(EntradaSuave)).first;

/// El scroll principal de la pantalla (el primero que aparece).
ScrollPosition _scroll(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

/// Registra la espera que calcula esperaDePagina en cada build.
class _Espia extends StatelessWidget {
  const _Espia(this.esperas);

  final List<Duration> esperas;

  @override
  Widget build(BuildContext context) {
    esperas.add(esperaDePagina(context));
    return const Text('espía');
  }
}

/// Anfitrión que empuja a [_Espia] con un MaterialPageRoute.
class _Anfitrion extends StatelessWidget {
  const _Anfitrion(this.esperas);

  final List<Duration> esperas;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => _Espia(esperas)),
        ).ignore(),
        child: const Text('Abrir'),
      ),
    ),
  );
}

/// Cinco estrellas con la calificación [calificacion].
Widget _estrellas(int calificacion) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < 5; i++)
      EstrellaAnimada(
        indice: i,
        calificacion: calificacion,
        child: Icon(
          i < calificacion ? Icons.star_rounded : Icons.star_border_rounded,
        ),
      ),
  ],
);

/// Un Transform de la estrella [i] (solo existe mientras se mueve).
Finder _movimientoDeEstrella(int i) => find.descendant(
  of: find.byType(EstrellaAnimada).at(i),
  matching: find.byType(Transform),
);

/// Contenido fijo más alto que la pantalla: arriba se ve, abajo espera.
Widget _vistaRevelada() => const MaterialApp(
  home: Scaffold(
    body: VistaRevelada(
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: EntradaAlVer(child: Text('Arriba')),
            ),
            SizedBox(height: 900),
            EntradaAlVer(
              child: Row(
                children: [
                  PopAlCompas(child: Icon(Icons.star)),
                  CifraQueCuenta(texto: '100%'),
                ],
              ),
            ),
            SizedBox(height: 400),
          ],
        ),
      ),
    ),
  ),
);

FakeApiClient _faqConCategorias(List<String> categorias) => FakeApiClient(
  respuestas: {
    ApiConstants.configuracionSeccion('faq'): {
      'success': true,
      'config': {
        'preguntas': [
          for (final c in categorias)
            {
              'categoria': c,
              'pregunta': '¿Pregunta de $c?',
              'respuesta': 'Respuesta de $c',
            },
        ],
      },
    },
  },
);

Future<void> _montarFaq(WidgetTester tester, FakeApiClient api) async {
  await tester.pumpApp(
    FAQScreen(
      viewModel: FaqViewModel(repo: ConfiguracionRepositoryRemote(api: api)),
    ),
    api: api,
  );
  await tester.pump();
}

Future<void> _montarNosotros(WidgetTester tester) async {
  final api = FakeApiClient()
    ..fallar(ApiConstants.configuracionSeccion('nosotros'), 'Sin conexión');
  await tester.pumpApp(
    AboutUsScreen(
      viewModel: AboutUsViewModel(
        repo: ConfiguracionRepositoryRemote(api: api),
      ),
    ),
    api: api,
  );
  await tester.pump();
}

Future<void> _montarContacto(WidgetTester tester, FakeApiClient api) async {
  await tester.pumpApp(
    ContactScreen(
      viewModel: ContactViewModel(
        configRepo: ConfiguracionRepositoryRemote(api: api),
        cuentaRepo: CuentaRepositoryRemote(api: api),
      ),
    ),
    api: api,
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('piezas de movimiento del contenido', () {
    testWidgets('esperaDePagina espera mientras la página llega y luego no', (
      tester,
    ) async {
      final esperas = <Duration>[];
      await tester.pumpWidget(MaterialApp(home: _Anfitrion(esperas)));
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      expect(esperas.last, AppMovimiento.trasEmpuje);

      await tester.pumpAndSettle();
      // Ya quieta, lo que se arme de nuevo entra sin esperar.
      tester.element(find.byType(_Espia)).markNeedsBuild();
      await tester.pump();
      expect(esperas.last, Duration.zero);
    });

    testWidgets('PopAlEntrar crece con rebote y termina en 1; sin animar, ya '
        'en su lugar', (tester) async {
      await montarMovimiento(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopAlEntrar(child: Text('pop')),
            PopAlEntrar(animar: false, child: Text('quieto')),
          ],
        ),
      );
      await tester.pump();
      final pop = find.byType(PopAlEntrar).first;
      expect(escalaEn(tester, pop), 0.6);
      expect(opacidadEn(tester, pop), 0);
      expect(escalaEn(tester, find.byType(PopAlEntrar).last), 1);

      await tester.pump(const Duration(milliseconds: 200));
      expect(escalaEn(tester, pop), greaterThan(0.6));
      await tester.pumpAndSettle();
      expect(escalaEn(tester, pop), 1);
      expect(opacidadEn(tester, pop), 1);
    });

    testWidgets('las estrellas que se encienden dan un pop en fila; el ícono '
        'cambia al instante', (tester) async {
      await montarMovimiento(tester, _estrellas(0));
      expect(_movimientoDeEstrella(0), findsNothing);

      await montarMovimiento(tester, _estrellas(3));
      // El ícono ya cambió: 3 llenas desde el primer cuadro.
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      await tester.pump();
      // La tocada (tercera) empieza dos escalones de cascada después (100 ms).
      await tester.pump(const Duration(milliseconds: 120));
      // La primera ya da su pop, la tocada (tercera) empieza enderezándose
      // desde un giro y la cuarta no se mueve.
      expect(_movimientoDeEstrella(0), findsWidgets);
      final giro = tester
          .widgetList<Transform>(_movimientoDeEstrella(2))
          .first
          .transform;
      expect(giro.entry(0, 1), isNot(0));
      expect(_movimientoDeEstrella(3), findsNothing);

      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        expect(_movimientoDeEstrella(i), findsNothing);
      }

      // Al bajar, las que se apagan se encogen apenas y regresan.
      await montarMovimiento(tester, _estrellas(1));
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_movimientoDeEstrella(1), findsWidgets);
      expect(_movimientoDeEstrella(0), findsNothing);
      await tester.pumpAndSettle();
      expect(_movimientoDeEstrella(1), findsNothing);
    });

    testWidgets('InsigniaExito cae completa y solo con chispas si se piden', (
      tester,
    ) async {
      await montarMovimiento(tester, const InsigniaExito());
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.byType(Chispas), findsNothing);
      await tester.pumpAndSettle();
      final escalas = tester.widgetList<ScaleTransition>(
        find.descendant(
          of: find.byType(InsigniaExito),
          matching: find.byType(ScaleTransition),
        ),
      );
      for (final escala in escalas) {
        expect(escala.scale.value, 1);
      }

      await montarMovimiento(
        tester,
        const InsigniaExito(key: ValueKey('publicada'), conChispas: true),
      );
      expect(find.byType(Chispas), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('con movimiento reducido la insignia llega quieta y sin '
        'chispas', (tester) async {
      await montarMovimiento(
        tester,
        const InsigniaExito(conChispas: true),
        reducido: true,
      );
      expect(find.byType(Chispas), findsNothing);
      expect(
        escalaEn(tester, find.byType(InsigniaExito)),
        1,
      );
    });

    testWidgets('SacudidaConAviso sacude cada vez que sube el aviso', (
      tester,
    ) async {
      final aviso = ValueNotifier<int>(0);
      addTearDown(aviso.dispose);
      await montarMovimiento(
        tester,
        SacudidaConAviso(aviso: aviso, child: const Text('campo')),
      );
      expect(_dxEn(tester, find.byType(Sacudida)), 0);

      aviso.value++;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_dxEn(tester, find.byType(Sacudida)), isNot(0));
      await tester.pumpAndSettle();
      expect(_dxEn(tester, find.byType(Sacudida)), 0);
    });

    testWidgets('CuentaRodante sube si crece, baja si decrece y termina '
        'exacta', (tester) async {
      await montarMovimiento(tester, const CuentaRodante(valor: 3));
      final reposo = tester.getTopLeft(find.text('3')).dy;

      await montarMovimiento(tester, const CuentaRodante(valor: 4));
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(find.text('4')).dy, greaterThan(reposo));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsNothing);
      expect(tester.getTopLeft(find.text('4')).dy, reposo);

      await montarMovimiento(tester, const CuentaRodante(valor: 3));
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(find.text('3')).dy, lessThan(reposo));
      await tester.pumpAndSettle();
      expect(find.text('4'), findsNothing);
    });

    testWidgets('DestelloAlMarcar solo destella al marcarse y el ícono sigue '
        'fundiendo su color', (tester) async {
      const apagado = Color(0xFF000000);
      const encendido = Color(0xFF00FF00);
      Widget pulgar({required bool activo}) => DestelloAlMarcar(
        activo: activo,
        child: IconoColorSuave(
          Icons.thumb_up,
          tamano: 14,
          color: activo ? encendido : apagado,
        ),
      );
      // La escala del pop (1 en reposo; el árbol es siempre el mismo).
      double escala() => escalaEn(tester, find.byType(DestelloAlMarcar));
      Color? color() => tester.widget<Icon>(find.byIcon(Icons.thumb_up)).color;

      // Montarse ya marcado no destella.
      await montarMovimiento(tester, pulgar(activo: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(escala(), 1);

      // Desmarcar tampoco.
      await montarMovimiento(tester, pulgar(activo: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(escala(), 1);
      await tester.pumpAndSettle();
      expect(color(), apagado);

      // Marcar sí, y el color pasa al nuevo con un fundido (no salta).
      await montarMovimiento(tester, pulgar(activo: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(escala(), greaterThan(1));
      expect(color(), isNot(apagado));
      expect(color(), isNot(encendido));
      await tester.pumpAndSettle();
      expect(escala(), 1);
      expect(color(), encendido);
    });

    testWidgets('con movimiento reducido DestelloAlMarcar no destella', (
      tester,
    ) async {
      Widget pulgar({required bool activo}) => DestelloAlMarcar(
        activo: activo,
        child: const Icon(Icons.thumb_up),
      );
      await montarMovimiento(tester, pulgar(activo: false), reducido: true);
      await montarMovimiento(tester, pulgar(activo: true), reducido: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(escalaEn(tester, find.byType(DestelloAlMarcar)), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('DestelloAlMarcar no celebra una marca que no pidió un toque', (
      tester,
    ) async {
      Widget pulgar({required bool activo}) => DestelloAlMarcar(
        activo: activo,
        porToque: false,
        child: const Icon(Icons.thumb_up),
      );
      await montarMovimiento(tester, pulgar(activo: false));
      await montarMovimiento(tester, pulgar(activo: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(escalaEn(tester, find.byType(DestelloAlMarcar)), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('ResaltadoUnaVez pinta su aro solo si llega activo', (
      tester,
    ) async {
      CustomPaint? pintura() {
        final finder = find.descendant(
          of: find.byType(ResaltadoUnaVez),
          matching: find.byType(CustomPaint),
        );
        return finder.evaluate().isEmpty
            ? null
            : tester.widget<CustomPaint>(finder.first);
      }

      await montarMovimiento(
        tester,
        ResaltadoUnaVez(
          activo: false,
          radio: BorderRadius.circular(16),
          child: const SizedBox(width: 100, height: 60),
        ),
      );
      expect(pintura()?.foregroundPainter, isNull);

      await montarMovimiento(
        tester,
        ResaltadoUnaVez(
          key: const ValueKey('nueva'),
          activo: true,
          radio: BorderRadius.circular(16),
          child: const SizedBox(width: 100, height: 60),
        ),
      );
      expect(pintura()?.foregroundPainter, isNotNull);
      // Termina solo.
      await tester.pumpAndSettle();
    });

    testWidgets('ResaltadoUnaVez vuelve a encender el aro con cada disparo '
        'nuevo, sin montar otra vez la tarjeta', (tester) async {
      Widget tarjeta(Object? disparo) => ResaltadoUnaVez(
        activo: false,
        disparo: disparo,
        radio: BorderRadius.circular(16),
        child: const SizedBox(key: ValueKey('tarjeta'), width: 100, height: 60),
      );
      CustomPaint pintura() => tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(ResaltadoUnaVez),
              matching: find.byType(CustomPaint),
            )
            .first,
      );

      // Montarse con un disparo no enciende nada.
      await montarMovimiento(tester, tarjeta(1));
      expect(pintura().foregroundPainter, isNull);
      final antes = tester.element(find.byKey(const ValueKey('tarjeta')));

      await montarMovimiento(tester, tarjeta(2));
      expect(pintura().foregroundPainter, isNotNull);
      // Es la misma tarjeta (no perdió su estado).
      expect(
        tester.element(find.byKey(const ValueKey('tarjeta'))),
        same(antes),
      );
      await tester.pumpAndSettle();

      // El mismo disparo otra vez no repite: el aro ya terminó.
      await montarMovimiento(tester, tarjeta(2));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('con movimiento reducido un disparo nuevo no enciende el aro', (
      tester,
    ) async {
      Widget tarjeta(Object? disparo) => ResaltadoUnaVez(
        activo: false,
        disparo: disparo,
        radio: BorderRadius.circular(16),
        child: const SizedBox(width: 100, height: 60),
      );
      await montarMovimiento(tester, tarjeta(null), reducido: true);
      await montarMovimiento(tester, tarjeta(1), reducido: true);
      expect(
        tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(ResaltadoUnaVez),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            )
            .foregroundPainter,
        isNull,
      );
    });

    testWidgets('CifraQueCuenta cuenta hasta el texto exacto y lo que no es '
        'número late', (tester) async {
      await montarMovimiento(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CifraQueCuenta(texto: '100%'),
            CifraQueCuenta(texto: '+ 5 años'),
            CifraQueCuenta(texto: '❤️'),
            CifraQueCuenta(texto: '10,000+'),
          ],
        ),
      );
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('+ 0 años'), findsOneWidget);
      // Con separador de miles no se cuenta (no habría un número limpio).
      expect(find.text('10,000+'), findsOneWidget);
      // Los lectores de pantalla oyen siempre la cifra final.
      final semantica = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(CifraQueCuenta).first,
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantica.properties.label, '100%');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('100%'), findsNothing);
      final latido = find.descendant(
        of: find.byType(CifraQueCuenta).at(2),
        matching: find.byType(ScaleTransition),
      );
      expect(tester.widget<ScaleTransition>(latido).scale.value, isNot(1));

      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('+ 5 años'), findsOneWidget);
      expect(find.text('10,000+'), findsOneWidget);
      expect(tester.widget<ScaleTransition>(latido).scale.value, 1);
    });

    testWidgets('una cifra que no cabe en un entero no rompe la pantalla: late '
        'y queda exacta', (tester) async {
      const enorme = '99999999999999999999 clientes';
      await montarMovimiento(tester, const CifraQueCuenta(texto: enorme));
      expect(tester.takeException(), isNull);
      expect(find.text(enorme), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text(enorme), findsOneWidget);
    });

    testWidgets('con movimiento reducido las cifras ya están completas', (
      tester,
    ) async {
      await montarMovimiento(
        tester,
        const CifraQueCuenta(texto: '100%'),
        reducido: true,
      );
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('lo que está abajo espera a que el scroll lo traiga y entra '
        'una sola vez', (tester) async {
      await tester.pumpWidget(_vistaRevelada());
      await tester.pumpAndSettle();

      expect(opacidadEn(tester, _entradaAlVerDe(find.text('Arriba'))), 1);
      final abajo = _entradaAlVerDe(find.byIcon(Icons.star));
      // Construido, pero esperando: invisible, con su ícono chico y su
      // cifra en cero.
      expect(opacidadEn(tester, abajo), 0);
      expect(escalaEn(tester, abajo), 0.6);
      expect(find.text('0%'), findsOneWidget);

      _scroll(tester).jumpTo(800);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacidadEn(tester, abajo), greaterThan(0));
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, abajo), 1);
      expect(escalaEn(tester, abajo), 1);
      expect(find.text('100%'), findsOneWidget);

      // Volver arriba y bajar otra vez no la repite.
      _scroll(tester).jumpTo(0);
      await tester.pumpAndSettle();
      _scroll(tester).jumpTo(800);
      await tester.pump();
      await tester.pump();
      expect(opacidadEn(tester, abajo), 1);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('lo último de la página entra aunque el scroll al tope no lo '
        'suba hasta el 90 % de la vista', (tester) async {
      // Vista alta y contenido apenas más alto: con el scroll al tope, el
      // último bloque se ve completo pero su borde queda en el 93 %.
      tester.view
        ..physicalSize = const Size(400, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VistaRevelada(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 1000),
                    EntradaAlVer(
                      child: SizedBox(height: 50, child: Text('Final')),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ultimo = _entradaAlVerDe(find.text('Final'));
      expect(opacidadEn(tester, ultimo), 0);

      _scroll(tester).jumpTo(_scroll(tester).maxScrollExtent);
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, ultimo), 1);
    });
  });

  group('Nosotros', () {
    testWidgets('la foto se queda atrás al subir y el título se desvanece', (
      tester,
    ) async {
      await _montarNosotros(tester);
      await tester.pumpAndSettle();
      // La portada de respaldo (sin red) es la que lleva el paralaje.
      final portada = find.byIcon(LucideIcons.store).first;
      double desplazamientoFoto() => tester
          .widget<Transform>(
            find.ancestor(of: portada, matching: find.byType(Transform)).first,
          )
          .transform
          .getTranslation()
          .y;
      double opacidadTitulo() => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('Nuestra Historia'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(desplazamientoFoto(), 0);
      expect(opacidadTitulo(), 1);

      _scroll(tester).jumpTo(150);
      await tester.pump();
      expect(desplazamientoFoto(), closeTo(60, 0.01));
      expect(opacidadTitulo(), closeTo(0.25, 0.01));
    });

    testWidgets('las cifras se cuentan cuando el scroll las trae', (
      tester,
    ) async {
      await _montarNosotros(tester);
      await tester.pumpAndSettle();
      expect(find.text('0%', skipOffstage: false), findsOneWidget);

      _scroll(tester).jumpTo(_scroll(tester).maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('+ 5 años'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
    });

    testWidgets('con movimiento reducido todo aparece en su lugar', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      await _montarNosotros(tester);
      expect(opacidadEn(tester, _entradaAlVerDe(find.text('Misión'))), 1);
      expect(find.text('100%', skipOffstage: false), findsOneWidget);
      _scroll(tester).jumpTo(150);
      await tester.pump();
      final portada = find.byIcon(LucideIcons.store).first;
      expect(
        tester
            .widget<Transform>(
              find
                  .ancestor(of: portada, matching: find.byType(Transform))
                  .first,
            )
            .transform
            .getTranslation()
            .y,
        0,
      );
    });
  });

  group('Contacto', () {
    testWidgets('al enviar incompleto se sacuden solo los campos con error', (
      tester,
    ) async {
      await _montarContacto(tester, FakeApiClient());
      final boton = find.text('Enviar Mensaje');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Los textos de error son los de siempre.
      expect(find.text('Ingresa tu nombre'), findsOneWidget);
      expect(find.text('Mínimo 20 caracteres'), findsOneWidget);
      expect(_dxEn(tester, _sacudidaDe(find.text('Tu nombre'))), isNot(0));
      expect(_dxEn(tester, _sacudidaDe(find.text('tu@correo.com'))), isNot(0));
      expect(
        _dxEn(
          tester,
          _sacudidaDe(find.text('Describe tu consulta o queja con detalle...')),
        ),
        isNot(0),
      );
      // El teléfono (opcional) no tiene nada que sacudir.
      expect(
        find.ancestor(
          of: find.text('771 000 0000'),
          matching: find.byType(Sacudida),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(_dxEn(tester, _sacudidaDe(find.text('Tu nombre'))), 0);
    });

    testWidgets('el diálogo de mensaje enviado trae la insignia, sin chispas', (
      tester,
    ) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.enviarContacto: {'success': true},
        },
      );
      await _montarContacto(tester, api);
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Ana López');
      await tester.enterText(campos.at(1), 'ana@pier.mx');
      await tester.enterText(campos.at(3), 'Quiero un pastel de 3 pisos');
      await tester.pump();
      final boton = find.text('Enviar Mensaje');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pump();
      await tester.pump();

      expect(find.byType(InsigniaExito), findsOneWidget);
      expect(find.byType(EntradaDialogo), findsOneWidget);
      expect(find.byType(Chispas), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('¡Mensaje enviado!'), findsOneWidget);
    });
  });

  group('Preguntas frecuentes', () {
    testWidgets('abrir eleva la tarjeta y cambiar de categoría la cierra', (
      tester,
    ) async {
      await _montarFaq(tester, _faqConCategorias(['Envíos', 'Pagos']));
      await tester.pumpAndSettle();

      // El filo verde de la tarjeta (va encima, como foregroundDecoration).
      Color filo() {
        final tarjeta = tester.widget<AnimatedContainer>(
          find
              .ancestor(
                of: find.text('¿Pregunta de Envíos?'),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is AnimatedContainer && w.foregroundDecoration != null,
                ),
              )
              .first,
        );
        return (tarjeta.foregroundDecoration! as BoxDecoration)
            .border!
            .top
            .color;
      }

      expect(filo().a, 0);
      await tester.tap(find.text('¿Pregunta de Envíos?'));
      await tester.pumpAndSettle();
      expect(find.text('Respuesta de Envíos'), findsOneWidget);
      expect(filo().a, greaterThan(0));

      // La lista de otra categoría llega con todas las preguntas cerradas.
      await tester.tap(find.text('Envíos'));
      await tester.pumpAndSettle();
      expect(find.text('¿Pregunta de Envíos?'), findsOneWidget);
      expect(find.text('Respuesta de Envíos'), findsNothing);
      expect(filo().a, 0);
    });

    testWidgets('el chip elegido se centra en su fila', (tester) async {
      await _montarFaq(
        tester,
        _faqConCategorias([
          for (var i = 1; i <= 9; i++) 'Categoría número $i',
        ]),
      );
      await tester.pumpAndSettle();
      final fila = tester
          .state<ScrollableState>(
            find
                .ancestor(
                  of: find.text('Todas'),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(fila.pixels, 0);

      final chip = find.text('Categoría número 2');
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(fila.pixels, greaterThan(0));
      // Queda cerca del centro de la fila.
      final centro = tester.getCenter(chip).dx;
      expect(centro, closeTo(400, 40));
    });

    testWidgets('con movimiento reducido las preguntas ya están en su lugar', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      await _montarFaq(tester, _faqConCategorias(['Envíos']));
      expect(
        opacidadEn(tester, _entradaSuaveDe(find.text('¿Pregunta de Envíos?'))),
        1,
      );
    });

    testWidgets('en una lista larga cada pregunta entra una sola vez: lo que '
        'llega al bajar ya está en su lugar y volver no repite', (
      tester,
    ) async {
      await _montarFaq(
        tester,
        FakeApiClient(
          respuestas: {
            ApiConstants.configuracionSeccion('faq'): {
              'success': true,
              'config': {
                'preguntas': [
                  for (var i = 0; i < 30; i++)
                    {
                      'categoria': 'Envíos',
                      'pregunta': '¿Pregunta $i?',
                      'respuesta': 'Respuesta $i',
                    },
                ],
              },
            },
          },
        ),
      );
      await tester.pumpAndSettle();
      final lista = tester
          .state<ScrollableState>(
            find
                .ancestor(
                  of: find.text('¿Pregunta 0?'),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;

      // La lista arma las filas de abajo al llegar a ellas: ya en su lugar.
      lista.jumpTo(lista.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      expect(
        opacidadEn(tester, _entradaSuaveDe(find.text('¿Pregunta 29?'))),
        1,
      );
      await tester.pumpAndSettle();

      // Las de arriba se desarmaron al bajar; al volver no repiten su
      // entrada.
      lista.jumpTo(0);
      await tester.pump();
      await tester.pump();
      expect(
        opacidadEn(tester, _entradaSuaveDe(find.text('¿Pregunta 0?'))),
        1,
      );
      await tester.pumpAndSettle();
    });
  });

  group('Marco legal', () {
    testWidgets('solo la pestaña de llegada entra; las demás llegan quietas', (
      tester,
    ) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.configuracionSeccion('legales'), 'Sin conexión');
      await tester.pumpApp(
        LegalScreen(
          viewModel: LegalViewModel(
            repo: ConfiguracionRepositoryRemote(api: api),
          ),
        ),
        api: api,
      );
      await tester.pump();
      final primera = _entradaSuaveDe(find.text('Responsable del Tratamiento'));
      expect(opacidadEn(tester, primera), lessThan(1));
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, primera), 1);

      await tester.tap(find.text('Términos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        opacidadEn(tester, _entradaSuaveDe(find.text('Proceso de Compra'))),
        1,
      );
      await tester.pumpAndSettle();

      // Volver a la primera no repite su entrada.
      await tester.tap(find.text('Privacidad'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        opacidadEn(
          tester,
          _entradaSuaveDe(find.text('Responsable del Tratamiento')),
        ),
        1,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('al cambiar de pestaña la página que se va se atenúa y en '
        'reposo nada queda atenuado', (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.configuracionSeccion('legales'), 'Sin conexión');
      await tester.pumpApp(
        LegalScreen(
          viewModel: LegalViewModel(
            repo: ConfiguracionRepositoryRemote(api: api),
          ),
        ),
        api: api,
      );
      await tester.pumpAndSettle();
      Finder pagina(int indice) => find.byWidgetPredicate(
        (w) => w is PaginaAtenuada && w.indice == indice,
      );
      expect(opacidadEn(tester, pagina(0)), 1);

      await tester.tap(find.text('Términos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // A media vuelta: la que se va, apagada pero nunca bajo 0.55; la que
      // llega, todavía aclarándose.
      expect(opacidadEn(tester, pagina(0)), lessThan(1));
      expect(opacidadEn(tester, pagina(0)), greaterThanOrEqualTo(0.55));
      expect(opacidadEn(tester, pagina(1)), lessThan(1));

      await tester.pumpAndSettle();
      expect(opacidadEn(tester, pagina(1)), 1);
      expect(find.text('Proceso de Compra'), findsOneWidget);
    });
  });
}
