// lib/utils/demo_bloqueo_analisis.dart — SOLO para la demostración de #52.
// La variable sin usar genera un aviso nuevo de `flutter analyze`; el CI
// compara contra el baseline y debe bloquear el merge. Este PR no se mezcla.
int demoBloqueoAnalisis() {
  final sinUsar = 1;
  return 0;
}
