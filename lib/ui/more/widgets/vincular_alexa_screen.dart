// lib/ui/more/widgets/vincular_alexa_screen.dart
// Vincular la cuenta con la skill de Alexa por codigo de un solo uso.
// Espejo del componente web VincularAlexa.tsx:
//   POST /api/auth/alexa/generar-codigo (auth) -> { codigo, expira_en_segundos }
// El usuario le dice el codigo a Alexa y la skill lo canjea por un JWT.
// MVVM: el estado vive en VincularAlexaViewModel; esta vista solo lo pinta.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/more/view_model/vincular_alexa_view_model.dart';
import 'package:provider/provider.dart';

class VincularAlexaScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const VincularAlexaScreen({super.key, this.viewModel});

  final VincularAlexaViewModel? viewModel;

  @override
  State<VincularAlexaScreen> createState() => _VincularAlexaScreenState();
}

class _VincularAlexaScreenState extends State<VincularAlexaScreen> {
  // El State solo es dueño del ViewModel (lo crea y lo libera).
  late final VincularAlexaViewModel _vm = widget.viewModel ??
      VincularAlexaViewModel(repo: context.read<CuentaRepository>());

  // Tras el primer cuadro, lo que aparezca después (el botón cuando el
  // código expira) entra sin la espera de la página recién empujada.
  bool _montada = false;

  // El aviso de error se apaga mostrando el último mensaje (el ViewModel
  // ya lo vació al reintentar).
  String _ultimoError = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _montada = true;
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _copiar() async {
    final codigo = _vm.codigo;
    if (codigo == null) return;
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!mounted) return;
    _vm.marcarCopiado();
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildPantalla(),
    );
  }

  Widget _buildPantalla() {
    // La página llega con un push: sus bloques entran en cascada (una sola
    // vez; el ViewModel avisa cada segundo y nada se repite).
    const retraso = AppMovimiento.trasEmpuje;
    final hayError = _vm.error.isNotEmpty;
    if (hayError) _ultimoError = _vm.error;
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(title: const Text('Vincular con Alexa')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── ENCABEZADO ─────────────────────────────────────────────
          EntradaSuave(
            retraso: retraso,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    // El micrófono «escucha»: dos ondas salen una vez.
                    _OndasMicrofono(
                      retraso: retraso,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.pierVerde,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.mic,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vincular con Alexa',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Playfair Display')),
                          SizedBox(height: 2),
                          Text('Tu asistente por voz de Pier Repostería',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                            text:
                                'Genera un código de un solo uso (expira en 5 minutos) y dile a tu Alexa: '),
                        TextSpan(
                            text: '"Alexa, abre pier asistente"',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        TextSpan(text: ' y luego '),
                        TextSpan(
                            text: '"vincula mi cuenta con el código..."',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── ERROR ──────────────────────────────────────────────────
          // Aparece abriendo su espacio y se sacude; al reintentar se
          // apaga y el espacio se cierra.
          Sacudida(
            disparo: hayError ? _vm.error : null,
            child: Aparicion(
              visible: hayError,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(LucideIcons.circleAlert,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_ultimoError,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.error)),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── CÓDIGO O BOTÓN ─────────────────────────────────────────
          // Sin transición entre los dos (el botón sale en ese mismo
          // cuadro): la tarjeta del código solo tiene entrada.
          if (_vm.codigo != null)
            EntradaSuave(
              key: ValueKey<String>('codigo ${_vm.codigo}'),
              escalaInicial: 0.96,
              desplazamiento: const Offset(0, AppMovimiento.distanciaCorta),
              child: _buildCodigo(_vm.codigo!),
            )
          else
            EntradaSuave(
              key: const ValueKey<String>('generar'),
              orden: _montada ? 0 : 2,
              retraso: _montada ? Duration.zero : retraso,
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _vm.generando ? null : _vm.generar,
                  icon: CambioAnimado(
                    tipo: TipoCambio.escalar,
                    alineacion: Alignment.center,
                    child: _vm.generando
                        ? const SizedBox(
                            key: ValueKey<String>('generando'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.mic,
                            key: ValueKey<String>('generar'),
                            color: Colors.white, size: 18),
                  ),
                  label: CambioAnimado(
                    alineacion: Alignment.center,
                    child: Text(
                        _vm.generando
                            ? 'Generando...'
                            : 'Generar código de vinculación',
                        key: ValueKey<bool>(_vm.generando),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),
          EntradaSuave(
            orden: 3,
            retraso: retraso,
            child: Text(
              'Para desvincular, dile a tu Alexa: "cierra sesión". Tu cuenta se desconecta de ese dispositivo al instante.',
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppColors.textSecondary.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodigo(String codigo) {
    final deletreado = codigo.split('').join(' ');
    final duracionCambio = AppMovimiento.duracion(context, AppMovimiento.corta);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppColors.pierVerde.withValues(alpha: 0.25), width: 2),
      ),
      child: Column(children: [
        const Text('TU CÓDIGO DE VINCULACIÓN',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Los dígitos se revelan de izquierda a derecha (un solo Text).
            _RevelarCodigo(
              key: ValueKey<String>(codigo),
              child: Text(codigo,
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                      color: AppColors.pierVerdeOscuro)),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _copiar,
              borderRadius: BorderRadius.circular(12),
              // Copiar ↔ copiado: el borde se tiñe y el ícono cambia con
              // un pop.
              child: AnimatedContainer(
                duration: duracionCambio,
                curve: AppMovimiento.curvaEstandar,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _vm.copiado
                          ? AppColors.pierVerde
                          : AppColors.textSecondary.withValues(alpha: 0.3)),
                ),
                child: CambioAnimado(
                  tipo: TipoCambio.escalar,
                  duracion: AppMovimiento.rapida,
                  alineacion: Alignment.center,
                  child: Icon(
                      _vm.copiado ? LucideIcons.check : LucideIcons.copy,
                      key: ValueKey<bool>(_vm.copiado),
                      size: 18,
                      color: _vm.copiado
                          ? AppColors.pierVerde
                          : AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Expira en '),
              TextSpan(
                  text: _vm.tiempoRestante,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerdeOscuro)),
              const TextSpan(text: ' · un solo uso'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Dile: "vincula mi cuenta con el código $deletreado"',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
              color: AppColors.textSecondary),
        ),
      ]),
    );
  }
}

/// Dos ondas que salen del micrófono una sola vez al llegar a la pantalla
/// (como cuando Alexa escucha). Solo pinta, alrededor del ícono; con
/// movimiento reducido no aparecen.
class _OndasMicrofono extends StatefulWidget {
  const _OndasMicrofono({required this.retraso, required this.child});

  /// Espera antes de la primera onda (la página aún se desliza).
  final Duration retraso;
  final Widget child;

  @override
  State<_OndasMicrofono> createState() => _OndasMicrofonoState();
}

class _OndasMicrofonoState extends State<_OndasMicrofono>
    with SingleTickerProviderStateMixin {
  // Cada onda se abre como los anillos de la app (AppMovimiento.relleno) y
  // la segunda sale un tramo de sección después.
  static const Duration _duracionOnda = AppMovimiento.relleno;
  static const Duration _entreOndas = AppMovimiento.media;

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: widget.retraso + _entreOndas + _duracionOnda,
  );
  bool _preparada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    if (AppMovimiento.reducido(context)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _control.forward().ignore();
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  // El tramo del reloj que le toca a la onda que sale tras [espera]. Cada
  // extremo es una sola división: el de la última onda vale 1 exacto
  // (Interval no admite pasarse de 1).
  Interval _tramo(Duration espera) {
    final total = _control.duration!.inMicroseconds;
    final inicio = widget.retraso + espera;
    return Interval(
      inicio.inMicroseconds / total,
      (inicio + _duracionOnda).inMicroseconds / total,
    );
  }

  Widget _onda(Interval tramo) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _control,
          builder: (context, anillo) {
            final valor = _control.value;
            // Antes de su tramo y al terminarlo, la onda no se ve.
            if (valor <= tramo.begin || valor >= tramo.end) {
              return const SizedBox.shrink();
            }
            final t = tramo.transform(valor);
            return Opacity(
              opacity: 0.45 * (1 - t),
              child: Transform.scale(
                scale: 1 + 0.7 * AppMovimiento.curvaEntrada.transform(t),
                child: anillo,
              ),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.pierVerde, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Capa propia: las ondas duran más que la cascada de la página y no
    // deben repintar la pantalla entera en cada cuadro.
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _onda(_tramo(Duration.zero)),
          _onda(_tramo(_entreOndas)),
          widget.child,
        ],
      ),
    );
  }
}

/// Revela al hijo de izquierda a derecha una sola vez (recorte de pintura:
/// el texto es uno solo y su tamaño no cambia).
class _RevelarCodigo extends StatefulWidget {
  const _RevelarCodigo({required this.child, super.key});

  final Widget child;

  @override
  State<_RevelarCodigo> createState() => _RevelarCodigoState();
}

class _RevelarCodigoState extends State<_RevelarCodigo>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _curva = CurveTween(
    curve: const Interval(0.15, 1, curve: AppMovimiento.curvaEntrada),
  );

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: AppMovimiento.enfasis,
  );
  late final Animation<double> _avance = _control.drive(_curva);
  bool _preparada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    if (AppMovimiento.reducido(context)) {
      _control.value = 1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _control.forward().ignore();
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: _RecorteRevelado(_avance),
      child: widget.child,
    );
  }
}

class _RecorteRevelado extends CustomClipper<Rect> {
  _RecorteRevelado(this.avance) : super(reclip: avance);

  final Animation<double> avance;

  // Margen para que nada del texto quede recortado en reposo.
  static const double _margen = 12;

  @override
  Rect getClip(Size size) {
    final t = avance.value;
    final derecha = t >= 1 ? size.width + _margen : size.width * t;
    return Rect.fromLTRB(-_margen, -_margen, derecha, size.height + _margen);
  }

  @override
  bool shouldReclip(_RecorteRevelado oldClipper) =>
      oldClipper.avance != avance;
}
