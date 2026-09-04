// lib/utils/logger.dart
import 'package:flutter/foundation.dart';

class PierLog {
  // Códigos ANSI
  static const _reset  = '\x1B[0m';
  static const _red    = '\x1B[31m';
  static const _green  = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  static const _blue   = '\x1B[34m';
  static const _cyan   = '\x1B[36m';
  static const _grey   = '\x1B[90m';
  static const _bold   = '\x1B[1m';

  static void _log(String color, String tag, String msg) {
    if (kDebugMode) {
      debugPrint('$color$_bold[$tag]$_reset$color $msg$_reset');
    }
  }

  /// 🔵 Peticiones al API
  static void api(String msg)    => _log(_blue,   'API',   msg);

  /// 🟢 Autenticación
  static void auth(String msg)   => _log(_green,  'AUTH',  msg);

  /// 🔴 Errores
  static void error(String msg)  => _log(_red,    'ERROR', msg);

  /// 🟡 Info general
  static void info(String msg)   => _log(_yellow, 'INFO',  msg);

  /// 🩵 Navegación
  static void nav(String msg)    => _log(_cyan,   'NAV',   msg);

  /// ⚫ Debug / verbose
  static void debug(String msg)  => _log(_grey,   'DEBUG', msg);
}