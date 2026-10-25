// tool/resumen/smoke_liberacion.dart — el smoke del candidato de liberación
// (release.yml, «Pruebas en el entorno de liberación»): el APK de release,
// instalado en el emulador y apuntando al entorno aislado, abre, carga el
// catálogo e inicia sesión.
//
// En modo release la app no trae lo que usa integration_test (no hay VM
// service), así que el smoke la maneja desde fuera, como una persona: lee la
// pantalla con uiautomator (los widgets de Flutter aparecen por sus
// semánticas de accesibilidad), toca con `input tap` y escribe con
// `input text`. Aquí vive la lógica (leer la pantalla, los pasos y el
// resumen); tool/smoke_liberacion.dart la conecta con adb.
//
// La cuenta es la de la semilla del entorno aislado y solo existe en el
// contenedor: si la app hablara con otro servidor, no podría iniciar sesión.
import 'arranque.dart';
import 'markdown.dart';

/// Un elemento de la pantalla en el volcado de `uiautomator dump`.
class NodoDePantalla {
  const NodoDePantalla({
    required this.clase,
    required this.texto,
    required this.descripcion,
    required this.izquierda,
    required this.arriba,
    required this.derecha,
    required this.abajo,
    this.id = '',
    this.paquete = '',
  });

  /// La clase de Android: un campo de Flutter llega como
  /// android.widget.EditText.
  final String clase;

  /// El atributo text (el contenido de un campo).
  final String texto;

  /// El atributo content-desc: Flutter pone aquí la etiqueta de semántica
  /// (el texto de un botón o de una pestaña).
  final String descripcion;

  final int izquierda;
  final int arriba;
  final int derecha;
  final int abajo;

  /// El atributo resource-id: los avisos de Android traen el suyo
  /// (android:id/aerr_wait es el botón «Wait» del aviso de «no responde»).
  final String id;

  /// El paquete de la ventana del elemento: el de la app, o «android» en un
  /// aviso del sistema.
  final String paquete;

  /// Lo que dice el elemento, renglón por renglón. Una pestaña llega como
  /// «Catálogo» y, en otro renglón, su posición en la barra.
  List<String> get renglones => '$texto\n$descripcion'
      .split('\n')
      .map((renglon) => renglon.trim())
      .where((renglon) => renglon.isNotEmpty)
      .toList();

  bool get esCampoDeTexto => clase == 'android.widget.EditText';

  /// Un elemento sin tamaño está fuera de la pantalla: no se puede tocar.
  bool get esVisible => derecha > izquierda && abajo > arriba;

  /// El centro del elemento, donde se toca.
  ({int x, int y}) get centro =>
      (x: (izquierda + derecha) ~/ 2, y: (arriba + abajo) ~/ 2);
}

/// Los elementos del volcado de uiautomator, en el orden del árbol. Un
/// volcado vacío o roto da una lista vacía (la pantalla todavía no está).
List<NodoDePantalla> leerPantalla(String volcado) {
  final atributo = RegExp(r'([\w-]+)="([^"]*)"');
  final limites = RegExp(r'^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$');
  final nodos = <NodoDePantalla>[];

  for (final etiqueta in RegExp(r'<node\b([^>]*)>').allMatches(volcado)) {
    final atributos = {
      for (final par in atributo.allMatches(etiqueta.group(1)!))
        par.group(1)!: _sinEntidades(par.group(2)!),
    };
    final esquinas = limites.firstMatch(atributos['bounds'] ?? '');
    if (esquinas == null) continue;
    int esquina(int grupo) => int.parse(esquinas.group(grupo)!);
    nodos.add(
      NodoDePantalla(
        clase: atributos['class'] ?? '',
        texto: atributos['text'] ?? '',
        descripcion: atributos['content-desc'] ?? '',
        id: atributos['resource-id'] ?? '',
        paquete: atributos['package'] ?? '',
        izquierda: esquina(1),
        arriba: esquina(2),
        derecha: esquina(3),
        abajo: esquina(4),
      ),
    );
  }
  return nodos;
}

/// uiautomator escapa el XML: los saltos de renglón llegan como &#10;.
String _sinEntidades(String texto) => texto
    .replaceAllMapped(
      RegExp('&#(x?)([0-9a-fA-F]+);'),
      (codigo) => String.fromCharCode(
        int.parse(codigo.group(2)!, radix: codigo.group(1)!.isEmpty ? 10 : 16),
      ),
    )
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// El último elemento visible con un renglón igual a [etiqueta] (una pestaña
/// o un botón), o null si no está en la pantalla. Se toma el último porque
/// la barra de pestañas y los botones de abajo van al final del árbol.
NodoDePantalla? buscarEtiqueta(List<NodoDePantalla> nodos, String etiqueta) {
  final coincidencias = nodos.where(
    (nodo) => nodo.esVisible && nodo.renglones.contains(etiqueta),
  );
  return coincidencias.isEmpty ? null : coincidencias.last;
}

/// Si algún elemento de la pantalla dice [texto] (aunque sea parte de un
/// renglón, como el nombre de un producto en su tarjeta).
bool contieneTexto(List<NodoDePantalla> nodos, String texto) => nodos.any(
  (nodo) => nodo.renglones.any((renglon) => renglon.contains(texto)),
);

/// Los campos de texto visibles, de arriba hacia abajo.
List<NodoDePantalla> camposDeTexto(List<NodoDePantalla> nodos) =>
    nodos.where((nodo) => nodo.esCampoDeTexto && nodo.esVisible).toList();

/// El aviso de Android de que una app no responde (ANR): su título
/// («Quickstep isn't responding») y el botón «Wait» para cerrarlo sin
/// matar a nadie.
typedef AvisoDeNoResponde = ({String titulo, NodoDePantalla esperar});

/// El aviso de «no responde» que tapa la pantalla, o null si no hay.
/// uiautomator lee la ventana que tiene el foco: mientras el aviso esté
/// encima, la app no se ve.
AvisoDeNoResponde? avisoDeNoResponde(List<NodoDePantalla> nodos) {
  final esperar = nodos.where(
    (nodo) => nodo.id == 'android:id/aerr_wait' && nodo.esVisible,
  );
  if (esperar.isEmpty) return null;
  final titulos = nodos.where((nodo) => nodo.id == 'android:id/alertTitle');
  return (
    titulo: titulos.isEmpty ? '' : titulos.first.texto,
    esperar: esperar.first,
  );
}

/// Lo que el smoke necesita del emulador. tool/smoke_liberacion.dart lo hace
/// con adb; las pruebas, con un emulador de mentira.
abstract interface class Dispositivo {
  /// Abre la app y espera su primer cuadro; regresa la salida de
  /// `am start -W`.
  Future<String> abrirApp();

  /// El volcado de `uiautomator dump`, o '' si no se pudo leer.
  Future<String> volcarPantalla();

  Future<void> tocar(int x, int y);

  /// Escribe en el campo que tiene el foco, como un teclado.
  Future<void> escribir(String texto);

  /// La tecla Enter: en el último campo del formulario lo envía.
  Future<void> pulsarEnter();

  /// Guarda la pantalla como imagen, con [nombre] (sin extensión).
  Future<void> guardarCaptura(String nombre);

  Future<void> esperar(Duration tiempo);
}

/// Los datos del entorno aislado con los que corre el smoke.
class DatosDelSmoke {
  const DatosDelSmoke({
    required this.nombreDeLaApp,
    required this.usuario,
    required this.clave,
    required this.producto,
    required this.saludo,
  });

  /// Como Android llama a la app en sus avisos («Pier isn't responding»).
  final String nombreDeLaApp;

  /// La cuenta de la semilla (docker/semilla/semilla_pruebas.sql).
  final String usuario;
  final String clave;

  /// Un producto de la semilla con existencias, que debe verse en el
  /// catálogo.
  final String producto;

  /// Lo que dice el Inicio con la sesión iniciada: «Hola,» y el nombre de
  /// la cuenta.
  final String saludo;
}

/// Un paso del smoke: si pasó, en qué momento terminó (desde que empezó el
/// smoke) y qué se vio.
class PasoDelSmoke {
  const PasoDelSmoke({
    required this.nombre,
    required this.paso,
    required this.momento,
    required this.detalle,
  });

  final String nombre;
  final bool paso;
  final Duration momento;
  final String detalle;

  Map<String, Object> aJson() => {
    'nombre': nombre,
    'paso': paso,
    'momento_ms': momento.inMilliseconds,
    'detalle': detalle,
  };
}

/// Lo que dejó el smoke: sus pasos en orden (se detiene en el primero que
/// falla) y el último volcado de pantalla, para revisar una falla.
class ResultadoDelSmoke {
  const ResultadoDelSmoke({required this.pasos, this.ultimaPantalla = ''});

  final List<PasoDelSmoke> pasos;
  final String ultimaPantalla;

  bool get paso =>
      pasos.length == pasosDelSmoke.length && pasos.every((p) => p.paso);
}

/// Los pasos del smoke, en orden.
const pasosDelSmoke = [
  'Abrir la app (am start -W)',
  'Ver la tienda sin sesión',
  'Cargar el catálogo del entorno aislado',
  'Abrir «Iniciar Sesión»',
  'Iniciar sesión con la cuenta de la semilla',
];

/// Cuántas veces se vuelve a leer la pantalla antes de dar un paso por
/// fallido, y la pausa entre lecturas: unos 60 s en total, lo que tarda el
/// emulador sin GPU en lo más lento (abrir la app en frío).
const intentosPorPaso = 30;
const pausaEntreLecturas = Duration(seconds: 2);

/// Lo que tardan en acomodarse las animaciones de entrada de una pantalla
/// antes de tocarla.
const pausaDeAnimaciones = Duration(milliseconds: 1500);

/// Corre los pasos del smoke en [dispositivo] y se detiene en el primero
/// que falla. [transcurrido] da el tiempo desde que empezó el smoke y
/// [registrar] recibe una línea por cada lectura de pantalla que todavía no
/// muestra lo esperado (va al log del paso).
Future<ResultadoDelSmoke> correrSmoke(
  Dispositivo dispositivo,
  DatosDelSmoke datos, {
  required Duration Function() transcurrido,
  void Function(String linea)? registrar,
}) async {
  final pasos = <PasoDelSmoke>[];
  var nodos = <NodoDePantalla>[];
  var ultimaPantalla = '';
  // El título del aviso si Android dijo que la app no responde.
  String? appSinResponder;

  // Vuelve a leer la pantalla hasta que se cumpla [condicion]; regresa si
  // se cumplió. Si un aviso de «no responde» de otra app (por ejemplo, el
  // lanzador del emulador) tapa la pantalla, toca «Wait» y sigue; si el
  // aviso es de la app, ya no espera: la app se congeló.
  Future<bool> esperarQue(bool Function(List<NodoDePantalla>) condicion) async {
    for (var intento = 1; intento <= intentosPorPaso; intento++) {
      ultimaPantalla = await dispositivo.volcarPantalla();
      nodos = leerPantalla(ultimaPantalla);
      if (condicion(nodos)) return true;

      final aviso = avisoDeNoResponde(nodos);
      if (aviso != null && aviso.titulo.contains(datos.nombreDeLaApp)) {
        appSinResponder = aviso.titulo;
        return false;
      }
      if (aviso != null) {
        final centro = aviso.esperar.centro;
        await dispositivo.tocar(centro.x, centro.y);
      }
      registrar?.call(
        'Lectura $intento de $intentosPorPaso: ${nodos.length} elementos'
        '${nodos.isEmpty ? '' : ' (ventana de ${nodos.first.paquete})'}'
        '${aviso == null ? '' : '; se cerró el aviso «${aviso.titulo}» con «Wait»'}.',
      );
      if (intento < intentosPorPaso) {
        await dispositivo.esperar(pausaEntreLecturas);
      }
    }
    return false;
  }

  // Espera a que aparezca [etiqueta] y la toca; regresa si la encontró.
  Future<bool> tocarEtiqueta(String etiqueta) async {
    if (!await esperarQue((n) => buscarEtiqueta(n, etiqueta) != null)) {
      return false;
    }
    final centro = buscarEtiqueta(nodos, etiqueta)!.centro;
    await dispositivo.tocar(centro.x, centro.y);
    return true;
  }

  // Anota el paso; regresa si pasó, para seguir o detenerse.
  Future<bool> anotar(String detalleSiPaso, String detalleSiFalla,
      {required bool paso, String? captura}) async {
    if (paso && captura != null) await dispositivo.guardarCaptura(captura);
    if (!paso) await dispositivo.guardarCaptura('fallo');
    final congelada = appSinResponder;
    pasos.add(
      PasoDelSmoke(
        nombre: pasosDelSmoke[pasos.length],
        paso: paso,
        momento: transcurrido(),
        detalle: paso
            ? detalleSiPaso
            : congelada == null
            ? detalleSiFalla
            : 'Android avisó que la app no responde: «$congelada»',
      ),
    );
    return paso;
  }

  ResultadoDelSmoke resultado() =>
      ResultadoDelSmoke(pasos: pasos, ultimaPantalla: ultimaPantalla);

  // 1. Abrir la app: Android muestra su ventana (Status: ok).
  final aperturas = leerAperturas(await dispositivo.abrirApp());
  final apertura = aperturas.isEmpty ? null : aperturas.first;
  final tiempoDeApertura = apertura?.totalMs;
  if (!await anotar(
    'ventana en ${milisegundos((tiempoDeApertura ?? 0).toDouble())} '
        '(${apertura?.tipo})',
    'am start -W no mostró la ventana (Status: ${apertura?.estado ?? '—'})',
    paso: apertura?.abrio ?? false,
  )) {
    return resultado();
  }

  // 2. Sin sesión, la app entra a la tienda: la barra de pestañas.
  if (!await anotar(
    'la barra de pestañas con «Catálogo»',
    'no apareció la pestaña «Catálogo»',
    paso: await esperarQue((n) => buscarEtiqueta(n, 'Catálogo') != null),
  )) {
    return resultado();
  }

  // 3. El catálogo trae los productos de la API del contenedor.
  final catalogo = await tocarEtiqueta('Catálogo') &&
      await esperarQue((n) => contieneTexto(n, datos.producto));
  if (!await anotar(
    'el catálogo muestra «${datos.producto}»',
    'el catálogo no mostró «${datos.producto}»',
    paso: catalogo,
    captura: '01_catalogo',
  )) {
    return resultado();
  }

  // 4. «Más» → «Iniciar Sesión»: la pantalla de inicio de sesión con sus
  //    dos campos (correo y contraseña).
  final inicioDeSesion = await tocarEtiqueta('Más') &&
      await tocarEtiqueta('Iniciar Sesión') &&
      await esperarQue((n) => camposDeTexto(n).length >= 2);
  if (inicioDeSesion) await dispositivo.esperar(pausaDeAnimaciones);
  if (!await anotar(
    'la pantalla de inicio de sesión con sus 2 campos',
    'no apareció la pantalla de inicio de sesión',
    paso: inicioDeSesion,
    captura: '02_inicio_de_sesion',
  )) {
    return resultado();
  }

  // 5. Toca cada campo y escribe la cuenta de la semilla; Enter en la
  //    contraseña envía el formulario. Con la sesión iniciada la app vuelve
  //    a la tienda, a la pestaña en que estaba («Más»; corrida
  //    40225339327): cuando reaparece la barra se toca «Inicio», que
  //    saluda con el nombre de la cuenta.
  var sesion = false;
  for (final (indice, texto) in [datos.usuario, datos.clave].indexed) {
    final hayCampo = await esperarQue((n) => camposDeTexto(n).length > indice);
    if (!hayCampo) break;
    final centro = camposDeTexto(nodos)[indice].centro;
    await dispositivo.tocar(centro.x, centro.y);
    await dispositivo.escribir(texto);
    sesion = indice == 1;
  }
  if (sesion) {
    await dispositivo.pulsarEnter();
    sesion = await tocarEtiqueta('Inicio') &&
        await esperarQue((n) => contieneTexto(n, datos.saludo));
  }
  await anotar(
    'el Inicio dice «${datos.saludo}»',
    'después de enviar el formulario el Inicio no dijo «${datos.saludo}»',
    paso: sesion,
    captura: '03_sesion_iniciada',
  );
  return resultado();
}

/// Tabla del smoke para el resumen de la corrida.
String resumenSmoke(ResultadoDelSmoke resultado) {
  final texto = StringBuffer(
    '### 🚀 Smoke del candidato de liberación\n\n'
    'APK de release instalado en el emulador, contra el entorno aislado.\n\n',
  )
    ..writeln('| Paso | Resultado | Al terminar | Qué se vio |')
    ..writeln('|---|:-:|--:|---|');
  for (final (indice, nombre) in pasosDelSmoke.indexed) {
    final paso = indice < resultado.pasos.length
        ? resultado.pasos[indice]
        : null;
    final marca = paso == null ? '⏭️ no llegó' : (paso.paso ? '✅' : '❌');
    final momento = paso == null
        ? '—'
        : '${(paso.momento.inMilliseconds / 1000).toStringAsFixed(1)} s';
    texto.writeln(
      '| ${indice + 1}. ${celda(nombre)} | $marca | $momento '
      '| ${celda(paso?.detalle ?? '')} |',
    );
  }
  texto
    ..writeln()
    ..writeln(
      resultado.paso
          ? '✅ El candidato abre, carga el catálogo e inicia sesión.'
          : '❌ El candidato no pasó el smoke: la captura `fallo.png` y '
                '`pantalla_fallo.xml` están en el artefacto.',
    );
  return texto.toString();
}
