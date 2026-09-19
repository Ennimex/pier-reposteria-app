// lib/ui/more/widgets/vincular_alexa_screen.dart
// Vincular la cuenta con la skill de Alexa por codigo de un solo uso.
// Espejo del componente web VincularAlexa.tsx:
//   POST /api/auth/alexa/generar-codigo (auth) -> { codigo, expira_en_segundos }
// El usuario le dice el codigo a Alexa y la skill lo canjea por un JWT.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class VincularAlexaScreen extends StatefulWidget {
  const VincularAlexaScreen({super.key});

  @override
  State<VincularAlexaScreen> createState() => _VincularAlexaScreenState();
}

class _VincularAlexaScreenState extends State<VincularAlexaScreen> {
  final _cuentaRepo = CuentaRepository();

  String? _codigo;
  int _segundos = 0;
  bool _generando = false;
  bool _copiado = false;
  String _error = '';
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generar() async {
    setState(() {
      _generando = true;
      _error = '';
      _copiado = false;
    });

    final result = await _cuentaRepo.generarCodigoAlexa();

    if (!mounted) return;
    if (result['success'] == true && result['codigo'] != null) {
      _timer?.cancel();
      setState(() {
        _codigo = result['codigo'].toString();
        _segundos = (result['expira_en_segundos'] as num?)?.toInt() ?? 300;
        _generando = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          if (_segundos <= 1) {
            _codigo = null;
            _segundos = 0;
            t.cancel();
          } else {
            _segundos--;
          }
        });
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ??
            'No se pudo generar el código';
        _generando = false;
      });
    }
  }

  Future<void> _copiar() async {
    final codigo = _codigo;
    if (codigo == null) return;
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!mounted) return;
    setState(() => _copiado = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  String _formatoTiempo(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
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
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary),
                    children: const [
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
          if (_error.isNotEmpty) ...[
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
                  child: Text(_error,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.error)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 16),

          // ── CÓDIGO O BOTÓN ─────────────────────────────────────────
          if (_codigo != null)
            _buildCodigo(_codigo!)
          else
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _generando ? null : _generar,
                icon: _generando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.mic,
                        color: Colors.white, size: 18),
                label: Text(
                    _generando
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
        Text('TU CÓDIGO DE VINCULACIÓN',
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
                      color: _copiado
                          ? AppColors.pierVerde
                          : AppColors.textSecondary.withValues(alpha: 0.3)),
                ),
                child: Icon(
                    _copiado ? LucideIcons.check : LucideIcons.copy,
                    size: 18,
                    color: _copiado
                        ? AppColors.pierVerde
                        : AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Expira en '),
              TextSpan(
                  text: _formatoTiempo(_segundos),
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
          style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
              color: AppColors.textSecondary),
        ),
      ]),
    );
  }
}
