// test/widget/core/movimiento/rutas_test.dart — paginaRaiz (las rutas de
// go_router a las que se llega con context.go: fundido a través de la arena,
// dentro del presupuesto de las pruebas y sin AppTheme; con trasRaiz su
// contenido espera a que la página se vea) y RutaCelebracion
// (checkout → éxito: tapa al instante con un fondo opaco y florece encima).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

class _Pantalla extends StatelessWidget {
  const _Pantalla(this.nombre, {this.alAbrir});

  final String nombre;
  final VoidCallback? alAbrir;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: alAbrir, child: Text(nombre)),
    ),
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/a',
  routes: [
    GoRoute(
      path: '/a',
      pageBuilder: (c, s) => paginaRaiz(s, const _Pantalla('A')),
    ),
    GoRoute(
      path: '/b',
      name: 'bebidas',
      pageBuilder: (c, s) => paginaRaiz(s, const _Pantalla('B')),
    ),
  ],
);

/// Opacidad del fondo arena de la página raíz donde está [pagina]: dentro
/// de su transición (el Stack de paso), el FadeTransition cuyo hijo es un
/// ColoredBox arena sin hijo.
double _fondo(WidgetTester tester, String pagina) {
  final transicion = find
      .ancestor(
        of: find.text(pagina),
        matching: find.byWidgetPredicate(
          (w) => w is Stack && w.fit == StackFit.passthrough,
        ),
      )
      .first;
  return tester
      .widget<FadeTransition>(
        find.descendant(
          of: transicion,
          matching: find.byWidgetPredicate(
            (w) =>
                w is FadeTransition &&
                w.child is ColoredBox &&
                (w.child! as ColoredBox).color == AppColors.pierArena &&
                (w.child! as ColoredBox).child == null,
          ),
        ),
      )
      .opacity
      .value;
}

/// Opacidad de la página (el FadeTransition más cercano al texto).
double _opacidadDe(WidgetTester tester, String texto) => tester
    .widget<FadeTransition>(
      find
          .ancestor(of: find.text(texto), matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

/// Escala de la página (el ScaleTransition más cercano al texto).
double _escalaDe(WidgetTester tester, String texto) => tester
    .widget<ScaleTransition>(
      find
          .ancestor(
            of: find.text(texto),
            matching: find.byType(ScaleTransition),
          )
          .first,
    )
    .scale
    .value;

ModalRoute<dynamic> _rutaDe(WidgetTester tester, String texto) =>
    ModalRoute.of(tester.element(find.text(texto)))!;

void main() {
  group('paginaRaiz', () {
    testWidgets('la página inicial no anima', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
      expect(find.text('A'), findsOneWidget);
      expect(_rutaDe(tester, 'A').animation!.isCompleted, isTrue);
    });

    testWidgets('go funde a través de la arena y revela la página nueva', (
      tester,
    ) async {
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.go('/b');
      await tester.pump();
      await tester.pump();
      // La anterior sigue debajo mientras la arena aparece sobre ella.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(_fondo(tester, 'B'), lessThan(0.5));
      expect(_opacidadDe(tester, 'B'), 0);

      // Al 30 % la arena ya tapa todo y la página nueva empieza a aparecer.
      await tester.pump(const Duration(milliseconds: 110));
      expect(_fondo(tester, 'B'), 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacidadDe(tester, 'B'), inExclusiveRange(0, 1));
      expect(_escalaDe(tester, 'B'), lessThan(1));

      // Dentro del presupuesto de las pruebas (≤ 400 ms) termina y la
      // anterior sale del árbol.
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump();
      expect(_rutaDe(tester, 'B').animation!.isCompleted, isTrue);
      expect(_opacidadDe(tester, 'B'), 1);
      expect(_escalaDe(tester, 'B'), 1);
      expect(find.text('A', skipOffstage: false), findsNothing);
    });

    testWidgets('sin AppTheme se funde en la arena de la paleta', (
      tester,
    ) async {
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_fondo(tester, 'B'), 1); // existe el ColoredBox arena y ya tapa
      await tester.pumpAndSettle();
    });

    testWidgets('conserva la key, el nombre y los argumentos de go_router', (
      tester,
    ) async {
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/b?origen=menu');
      await tester.pumpAndSettle();

      final ruta = _rutaDe(tester, 'B');
      final pagina = ruta.settings as Page<dynamic>;
      final estado = GoRouterState.of(tester.element(find.text('B')));
      expect(pagina.key, estado.pageKey);
      expect(pagina.name, 'bebidas');
      expect(pagina.arguments, {'origen': 'menu'});
      expect(pagina.restorationId, estado.pageKey.value);
    });

    testWidgets('con movimiento reducido no escala (solo se disuelve)', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.go('/b');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_escalaDe(tester, 'B'), 1);
      expect(_fondo(tester, 'B'), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
    });

    testWidgets('un push encima la desplaza con el parallax de Cupertino', (
      tester,
    ) async {
      final router = _router();
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {TargetPlatform.android: TransicionPaginaPier()},
            ),
          ),
        ),
      );
      final antes = tester.getCenter(find.text('A')).dx;

      Navigator.of(tester.element(find.text('A')))
          .push(
            MaterialPageRoute<void>(builder: (_) => const _Pantalla('Encima')),
          )
          .ignore();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getCenter(find.text('A')).dx, lessThan(antes));
      await tester.pumpAndSettle();
    });

    testWidgets('un pop la desvanece y deja ver la ruta de abajo', (
      tester,
    ) async {
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push<void>('/b').ignore();
      await tester.pumpAndSettle();

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final fundido = tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('B'),
                  matching: find.byType(FadeTransition),
                )
                .last,
          )
          .opacity
          .value;
      expect(fundido, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('con trasRaiz el contenido espera a que la página se vea', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(
            path: '/a',
            pageBuilder: (c, s) => paginaRaiz(s, const _Pantalla('A')),
          ),
          GoRoute(
            path: '/c',
            pageBuilder: (c, s) => paginaRaiz(
              s,
              const Scaffold(
                body: Center(
                  child: EntradaSuave(
                    retraso: AppMovimiento.trasRaiz,
                    child: Text('C'),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/c');
      await tester.pump();
      await tester.pump();

      final entrada = find.byType(EntradaSuave);
      // La página: el FadeTransition más cercano por encima de la entrada.
      double pagina() => tester
          .widget<FadeTransition>(
            find
                .ancestor(of: entrada, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value;
      // Mientras la página sigue transparente, su contenido no avanza.
      for (var i = 0; i < 16; i++) {
        if (pagina() == 0) expect(opacidadEn(tester, entrada), 0);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(opacidadEn(tester, entrada), greaterThan(0));
      await tester.pumpAndSettle();
    });
  });

  group('RutaCelebracion', () {
    Widget app() => MaterialApp(
      home: Builder(
        builder: (context) => _Pantalla(
          'Checkout',
          alAbrir: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (contexto) => _Pantalla(
                'Pagar',
                alAbrir: () => Navigator.pushReplacement(
                  contexto,
                  RutaCelebracion<void>(
                    builder: (_) => const _Pantalla('¡Pedido confirmado!'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('tapa la ruta anterior al instante y florece encima', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
      final pagarAntes = tester.getCenter(find.text('Pagar'));

      await tester.tap(find.text('Pagar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Fondo blanco opaco ya desde el principio y la página escalando.
      final fondo = find.ancestor(
        of: find.text('¡Pedido confirmado!'),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == Colors.white,
        ),
      );
      expect(fondo, findsWidgets);
      expect(
        escalaEn(
          tester,
          find
              .ancestor(of: fondo.first, matching: find.byType(FadeTransition))
              .first,
        ),
        lessThan(1),
      );
      // La ruta de abajo no se desliza.
      expect(tester.getCenter(find.text('Pagar')), pagarAntes);

      await tester.pump(AppMovimiento.enfasis);
      expect(find.text('Pagar', skipOffstage: false), findsNothing);
      expect(find.text('¡Pedido confirmado!'), findsOneWidget);
    });

    testWidgets('al quitarse se desvanece', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => _Pantalla(
              'Inicio',
              alAbrir: () => Navigator.of(context).push(
                RutaCelebracion<void>(
                  builder: (_) => const _Pantalla('Gracias'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.text('Gracias'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final fundido = tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('Gracias'),
                  matching: find.byType(FadeTransition),
                )
                .last,
          )
          .opacity
          .value;
      expect(fundido, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('Gracias'), findsNothing);
    });
  });
}
