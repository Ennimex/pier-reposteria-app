// lib/ui/more/widgets/vincular_alexa_screen.dart
// Vincular la cuenta con la skill de Alexa por codigo de un solo uso.
// Espejo del componente web VincularAlexa.tsx:
//   POST /api/auth/alexa/generar-codigo (auth) -> { codigo, expira_en_segundos }
// El usuario le dice el codigo a Alexa y la skill lo canjea por un JWT.
// MVVM: el estado vive en VincularAlexaViewModel; esta vista solo lo pinta.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/more/view_model/vincular_alexa_view_model.dart';
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
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(title: const Text('Vincular con Alexa')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── ENCABEZADO ─────────────────────────────────────────────
          Container(
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.mic,
                        color: Colors.white, size: 20),
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

          // ── ERROR ──────────────────────────────────────────────────
          if (_vm.error.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  child: Text(_vm.error,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.error)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 16),

          // ── CÓDIGO O BOTÓN ─────────────────────────────────────────
          if (_vm.codigo != null)
            _buildCodigo(_vm.codigo!)
          else
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _vm.generando ? null : _vm.generar,
                icon: _vm.generando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.mic,
                        color: Colors.white, size: 18),
                label: Text(
                    _vm.generando
                        ? 'Generando...'
                        : 'Generar código de vinculación',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

          const SizedBox(height: 16),
          Text(
            'Para desvincular, dile a tu Alexa: "cierra sesión". Tu cuenta se desconecta de ese dispositivo al instante.',
            style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.textSecondary.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildCodigo(String codigo) {
    final deletreado = codigo.split('').join(' ');
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
            Text(codigo,
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    color: AppColors.pierVerdeOscuro)),
            const SizedBox(width: 10),
            InkWell(
              onTap: _copiar,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _vm.copiado
                          ? AppColors.pierVerde
                          : AppColors.textSecondary.withValues(alpha: 0.3)),
                ),
                child: Icon(
                    _vm.copiado ? LucideIcons.check : LucideIcons.copy,
                    size: 18,
                    color: _vm.copiado
                        ? AppColors.pierVerde
                        : AppColors.textSecondary),
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
