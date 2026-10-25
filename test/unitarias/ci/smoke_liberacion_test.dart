// test/unitarias/ci/smoke_liberacion_test.dart — el smoke del candidato de
// liberación (tool/resumen/smoke_liberacion.dart): la lectura del volcado de
// uiautomator y los pasos, con un emulador de mentira que cambia de pantalla
// según lo que se toca.
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/smoke_liberacion.dart';

/// Un elemento como lo escribe `uiautomator dump` (con los saltos de
/// renglón escapados).
String _nodo(
  String limites, {
  String texto = '',
  String descripcion = '',
  String clase = 'android.view.View',
}) =>
    '<node index="0" text="$texto" resource-id="" class="$clase" '
    'package="mx.com.pierreposteria" '
    'content-desc="${descripcion.replaceAll('\n', '&#10;')}" '
    'clickable="true" bounds="$limites" />';

String _volcado(List<String> nodos) => [
  "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>",
  '<hierarchy rotation="0">',
  '<node index="0" text="" class="android.widget.FrameLayout" content-desc="" bounds="[0,0][1080,2400]">',
  ...nodos,
  '</node></hierarchy>',
].join();

/// La barra de pestañas de la tienda, como la expone Flutter.
final List<String> _barra = [
  for (final (indice, pestana)
      in ['Inicio', 'Catálogo', 'Carrito', 'Pedidos', 'Más'].indexed)
    _nodo(
      '[${indice * 216},2200][${indice * 216 + 216},2340]',
      descripcion: '$pestana\nPestaña ${indice + 1} de 5',
    ),
];

const _datos = DatosDelSmoke(
  usuario: 'cliente@pier.test',
  clave: 'Chocoflan-Prueba-2026',
  producto: 'Chocoflan',
  saludo: 'Hola, Cliente',
);

const _aperturaOk = '''
Starting: Intent { cmp=mx.com.pierreposteria/.MainActivity }
Status: ok
LaunchState: COLD
Activity: mx.com.pierreposteria/.MainActivity
TotalTime: 4321
WaitTime: 4325
Complete
''';

const _aperturaSinVentana = '''
Starting: Intent { cmp=mx.com.pierreposteria/.MainActivity }
Status: timeout
LaunchState: UNKNOWN (-1)
Activity: mx.com.pierreposteria/.MainActivity
WaitTime: 10370
Complete
''';

/// Un emulador de mentira: cada pantalla es un volcado y tocar una pestaña o
/// un botón lleva a la siguiente, como en la app.
class _EmuladorDeMentira implements Dispositivo {
  _EmuladorDeMentira({
    this.abre = true,
    this.catalogoConProducto = true,
    this.aceptaLaCuenta = true,
  });

  final bool abre;
  final bool catalogoConProducto;
  final bool aceptaLaCuenta;

  /// Mientras la app arranca, uiautomator no la ve.
  int lecturasVaciasAlAbrir = 2;

  String pantalla = 'cerrada';
  int lecturas = 0;
  int enters = 0;
  int? campoConFoco;
  final toques = <({int x, int y})>[];
  final escrito = <int, String>{};
  final capturas = <String>[];
  final esperas = <Duration>[];

  Map<String, String> get _volcados => {
    'cerrada': '',
    'tienda': _volcado([
      _nodo('[40,200][1040,300]', descripcion: 'Bienvenido'),
      _nodo('[40,400][1040,500]', descripcion: 'Ver catálogo completo'),
      ..._barra,
    ]),
    'catalogo': _volcado([
      if (catalogoConProducto)
        _nodo('[40,400][520,900]', descripcion: r'Chocoflan&#10;$350.00')
      else
        _nodo('[40,400][1040,500]', descripcion: 'Sin resultados'),
      ..._barra,
    ]),
    'mas': _volcado([
      _nodo('[40,300][1040,400]', descripcion: '¡Bienvenido!'),
      _nodo(
        '[40,500][1040,596]',
        descripcion: 'Iniciar Sesión',
        clase: 'android.widget.Button',
      ),
      // Fuera de la pantalla: no se puede tocar.
      _nodo('[0,0][0,0]', descripcion: 'Iniciar Sesión'),
      ..._barra,
    ]),
    'login': _volcado([
      _nodo('[40,300][1040,400]', descripcion: 'Bienvenido'),
      _nodo(
        '[40,800][1040,940]',
        texto: escrito[0] ?? '',
        clase: 'android.widget.EditText',
      ),
      _nodo(
        '[40,980][1040,1120]',
        texto: escrito[1] ?? '',
        clase: 'android.widget.EditText',
      ),
      _nodo(
        '[40,1300][1040,1420]',
        descripcion: 'Iniciar Sesión',
        clase: 'android.widget.Button',
      ),
    ]),
    'inicio': _volcado([
      _nodo('[40,200][1040,300]', descripcion: 'Hola, Cliente'),
      ..._barra,
    ]),
  };

  @override
  Future<String> abrirApp() async {
    pantalla = abre ? 'tienda' : 'cerrada';
    return abre ? _aperturaOk : _aperturaSinVentana;
  }

  @override
  Future<String> volcarPantalla() async {
    lecturas++;
    if (lecturasVaciasAlAbrir > 0) {
      lecturasVaciasAlAbrir--;
      return '';
    }
    return _volcados[pantalla]!;
  }

  @override
  Future<void> tocar(int x, int y) async {
    toques.add((x: x, y: y));
    final tocado = leerPantalla(_volcados[pantalla]!).lastWhere(
      (nodo) =>
          nodo.izquierda <= x &&
          x <= nodo.derecha &&
          nodo.arriba <= y &&
          y <= nodo.abajo,
    );
    if (tocado.esCampoDeTexto) {
      campoConFoco = tocado.arriba < 950 ? 0 : 1;
      return;
    }
    final etiqueta = tocado.renglones.first;
    pantalla = switch ((pantalla, etiqueta)) {
      (_, 'Catálogo') => 'catalogo',
      (_, 'Más') => 'mas',
      ('mas', 'Iniciar Sesión') => 'login',
      _ => pantalla,
    };
  }

  @override
  Future<void> escribir(String texto) async {
    escrito[campoConFoco!] = (escrito[campoConFoco!] ?? '') + texto;
  }

  @override
  Future<void> pulsarEnter() async {
    enters++;
    final cuentaCorrecta =
        escrito[0] == _datos.usuario && escrito[1] == _datos.clave;
    if (pantalla == 'login' && cuentaCorrecta && aceptaLaCuenta) {
      pantalla = 'inicio';
    }
  }

  @override
  Future<void> guardarCaptura(String nombre) async => capturas.add(nombre);

  @override
  Future<void> esperar(Duration tiempo) async => esperas.add(tiempo);
}

Future<ResultadoDelSmoke> _correr(_EmuladorDeMentira emulador) {
  var segundos = 0;
  return correrSmoke(
    emulador,
    _datos,
    transcurrido: () => Duration(seconds: ++segundos),
  );
}

void main() {
  group('leerPantalla', () {
    test('lee clase, texto, descripción y límites de cada elemento', () {
      final nodos = leerPantalla(
        _volcado([
          _nodo(
            '[10,20][110,220]',
            descripcion: 'Catálogo\nPestaña 2 de 5',
          ),
          _nodo(
            '[40,800][1040,940]',
            texto: 'Pan &amp; café',
            clase: 'android.widget.EditText',
          ),
        ]),
      );

      // El FrameLayout de la raíz también cuenta.
      expect(nodos, hasLength(3));
      final pestana = nodos[1];
      expect(pestana.renglones, ['Catálogo', 'Pestaña 2 de 5']);
      expect(pestana.centro, (x: 60, y: 120));
      expect(pestana.esCampoDeTexto, isFalse);
      expect(nodos[2].texto, 'Pan & café');
      expect(nodos[2].esCampoDeTexto, isTrue);
    });

    test('un volcado vacío o roto no tiene elementos', () {
      expect(leerPantalla(''), isEmpty);
      expect(leerPantalla('ERROR: could not get idle state.'), isEmpty);
      expect(leerPantalla('<node text="sin límites" />'), isEmpty);
    });

    test('traduce las entidades numéricas y con nombre', () {
      final nodo = leerPantalla(
        '<node text="&lt;a&gt; &quot;b&quot; &apos;c&apos; &#xE1;" '
        'content-desc="uno&#10;dos" bounds="[0,0][1,1]" />',
      ).single;

      expect(nodo.texto, '<a> "b" \'c\' á');
      expect(nodo.renglones, ['<a> "b" \'c\' á', 'uno', 'dos']);
    });
  });

  group('buscar en la pantalla', () {
    final tienda = leerPantalla(
      _volcado([
        _nodo('[40,400][1040,500]', descripcion: 'Ver catálogo completo'),
        _nodo('[0,0][0,0]', descripcion: 'Más'),
        ..._barra,
      ]),
    );

    test('una etiqueta es un renglón completo, no parte de uno', () {
      expect(buscarEtiqueta(tienda, 'Catálogo')?.centro, (x: 324, y: 2270));
      expect(buscarEtiqueta(tienda, 'catálogo'), isNull);
      expect(buscarEtiqueta(tienda, 'Ver catálogo'), isNull);
    });

    test('ignora los elementos fuera de la pantalla y toma el último', () {
      expect(buscarEtiqueta(tienda, 'Más')?.centro, (x: 972, y: 2270));
    });

    test('contieneTexto encuentra parte de un renglón', () {
      expect(contieneTexto(tienda, 'catálogo completo'), isTrue);
      expect(contieneTexto(tienda, 'Chocoflan'), isFalse);
    });

    test('camposDeTexto da los campos visibles de arriba hacia abajo', () {
      final login = leerPantalla(
        _volcado([
          _nodo('[40,800][1040,940]', clase: 'android.widget.EditText'),
          _nodo('[0,0][0,0]', clase: 'android.widget.EditText'),
          _nodo('[40,980][1040,1120]', clase: 'android.widget.EditText'),
        ]),
      );

      expect(camposDeTexto(login).map((campo) => campo.arriba), [800, 980]);
    });
  });

  group('correrSmoke', () {
    test('abre, carga el catálogo e inicia sesión: los 5 pasos pasan', () async {
      final emulador = _EmuladorDeMentira();

      final resultado = await _correr(emulador);

      expect(resultado.paso, isTrue);
      expect(resultado.pasos.map((paso) => paso.nombre), pasosDelSmoke);
      expect(resultado.pasos.every((paso) => paso.paso), isTrue);
      expect(resultado.pasos.first.detalle, 'ventana en 4,321.00 ms (COLD)');
      expect(resultado.pasos[2].detalle, 'el catálogo muestra «Chocoflan»');
      expect(resultado.pasos.last.detalle, 'el Inicio dice «Hola, Cliente»');
      expect(
        resultado.pasos.map((paso) => paso.momento.inSeconds),
        [1, 2, 3, 4, 5],
      );
      expect(emulador.escrito, {0: _datos.usuario, 1: _datos.clave});
      expect(emulador.enters, 1);
      expect(emulador.capturas, [
        '01_catalogo',
        '02_inicio_de_sesion',
        '03_sesion_iniciada',
      ]);
      // Las dos lecturas vacías del arranque se volvieron a intentar, y
      // antes de tocar la pantalla de inicio de sesión se esperó a sus
      // animaciones.
      expect(
        emulador.esperas,
        [pausaEntreLecturas, pausaEntreLecturas, pausaDeAnimaciones],
      );
    });

    test('se detiene si la app no muestra su ventana', () async {
      final emulador = _EmuladorDeMentira(abre: false);

      final resultado = await _correr(emulador);

      expect(resultado.paso, isFalse);
      expect(resultado.pasos.single.paso, isFalse);
      expect(
        resultado.pasos.single.detalle,
        'am start -W no mostró la ventana (Status: timeout)',
      );
      expect(emulador.lecturas, 0);
      expect(emulador.capturas, ['fallo']);
    });

    test('falla en el catálogo si no llega el producto de la semilla', () async {
      final emulador = _EmuladorDeMentira(catalogoConProducto: false);

      final resultado = await _correr(emulador);

      expect(resultado.paso, isFalse);
      expect(resultado.pasos, hasLength(3));
      expect(resultado.pasos[2].paso, isFalse);
      expect(resultado.pasos[2].detalle, 'el catálogo no mostró «Chocoflan»');
      expect(resultado.ultimaPantalla, contains('Sin resultados'));
      expect(emulador.capturas, ['fallo']);
      expect(
        emulador.esperas.where((espera) => espera == pausaEntreLecturas),
        hasLength(2 + intentosPorPaso - 1),
      );
    });

    test('falla en el último paso si el servidor no acepta la cuenta', () async {
      final emulador = _EmuladorDeMentira(aceptaLaCuenta: false);

      final resultado = await _correr(emulador);

      expect(resultado.paso, isFalse);
      expect(resultado.pasos, hasLength(5));
      expect(resultado.pasos.last.paso, isFalse);
      expect(resultado.pasos.last.detalle, contains('no dijo «Hola, Cliente»'));
      expect(emulador.capturas.last, 'fallo');
    });
  });

  group('resumenSmoke', () {
    test('una fila por paso y la conclusión', () async {
      final resumen = resumenSmoke(await _correr(_EmuladorDeMentira()));

      expect(resumen, contains('### 🚀 Smoke del candidato de liberación'));
      expect(
        resumen,
        contains(
          '| 3. Cargar el catálogo del entorno aislado | ✅ | 3.0 s '
          '| el catálogo muestra «Chocoflan» |',
        ),
      );
      expect(
        resumen,
        contains('✅ El candidato abre, carga el catálogo e inicia sesión.'),
      );
    });

    test('marca el paso que falló y los que no se corrieron', () async {
      final resumen = resumenSmoke(
        await _correr(_EmuladorDeMentira(catalogoConProducto: false)),
      );

      expect(resumen, contains('| ❌ | 3.0 s | el catálogo no mostró'));
      expect(
        resumen,
        contains('| 5. Iniciar sesión con la cuenta de la semilla | ⏭️ no llegó | — |  |'),
      );
      expect(resumen, contains('❌ El candidato no pasó el smoke'));
    });
  });
}
