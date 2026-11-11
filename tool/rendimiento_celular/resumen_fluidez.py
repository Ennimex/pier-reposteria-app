"""tool/rendimiento_celular/resumen_fluidez.py — medianas de 3 corridas de fluidez y arranque en frío (#355).

Lee lo que deja fluidez.sh en la carpeta (<escena>_<n>.timeline_summary.json y start_up_info_<n>.json) y
devuelve, por escena y por indicador, el valor de cada corrida y la mediana, como en el #324. Los umbrales están
en docs/pruebas-rendimiento-celular.md.

Uso: python tool/rendimiento_celular/resumen_fluidez.py <carpeta>
"""
import json
import os
import statistics
import sys

CAMPOS = [
    ("p90 construcción", "90th_percentile_frame_build_time_millis"),
    ("p90 rasterizado", "90th_percentile_frame_rasterizer_time_millis"),
    ("construcción promedio", "average_frame_build_time_millis"),
    ("peor construcción", "worst_frame_build_time_millis"),
    ("cuadros perdidos al construir", "missed_frame_build_budget_count"),
    ("cuadros perdidos al rasterizar", "missed_frame_rasterizer_budget_count"),
    ("cuadros medidos", "frame_count"),
]


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    d = sys.argv[1]
    salida = {}
    for escena in ("arranque", "catalogo", "checkout"):
        corridas = []
        for i in (1, 2, 3):
            p = os.path.join(d, f"{escena}_{i}.timeline_summary.json")
            if os.path.exists(p):
                with open(p, encoding="utf-8") as f:
                    corridas.append(json.load(f))
        salida[escena] = {}
        for nombre, clave in CAMPOS:
            vals = [c[clave] for c in corridas if clave in c]
            if vals:
                salida[escena][nombre] = {"corridas": [round(v, 2) for v in vals],
                                          "mediana": round(statistics.median(vals), 2)}
    arranques = []
    for i in (1, 2, 3):
        p = os.path.join(d, f"start_up_info_{i}.json")
        if os.path.exists(p):
            with open(p, encoding="utf-8") as f:
                arranques.append(json.load(f)["timeToFirstFrameRasterizedMicros"] / 1000)
    if arranques:
        salida["arranque_en_frio_ms"] = {"corridas": [round(v) for v in arranques],
                                         "mediana": round(statistics.median(arranques))}
    print(json.dumps(salida, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
