// pruebas/k6/rendimiento.js — prueba de rendimiento de la API con carga
// normal, contra el entorno aislado (tool/entorno_pruebas.sh): nunca contra
// producción.
//
// Qué mide: cuánto tarda la API en contestar lo que la app pide al abrir el
// catálogo (productos, categorías) y el estado del servidor, con 10 clientes
// a la vez. El 95 % de las respuestas (p95) debe llegar en menos de 800 ms y
// menos del 1 % puede fallar; además, tool/comparar_rendimiento.sh compara el
// p95 con la línea base (tool/linea_base_rendimiento.json) y falla si sube más
// de 20 %.
//
// Cómo se corre (rendimiento.yml):
//   k6 run --summary-export build/resultados/k6_rendimiento.json \
//     --env API_BASE_URL=http://localhost:3000/api --env DURACION=30s \
//     pruebas/k6/rendimiento.js
// DURACION es 30s en los Pull Requests y 1m con «completo» (la carga es la
// misma; cambia cuánto dura).
//
// Límite conocido del backend: 3,000 peticiones cada 15 minutos por IP (al
// pasarlo contesta 429). Cada cliente hace 3 peticiones y espera 1 s, así que
// 10 clientes hacen menos de 30 peticiones por segundo:
//   30 s → menos de   900 peticiones (30 × 30)
//   1 m  → menos de 1,800 peticiones (30 × 60)
// Las dos quedan por debajo de 3,000. Si algún día se pasara, el contador
// respuestas_429 lo dice y su umbral hace fallar la prueba: no se esconde.
import { check, sleep } from 'k6';
import http from 'k6/http';
import { Counter } from 'k6/metrics';

const api = __ENV.API_BASE_URL ?? 'http://localhost:3000/api';
const duracion = __ENV.DURACION ?? '30s';
const clientes = 10;

// Respuestas 429 (límite de peticiones del backend): deben ser cero.
const respuestas429 = new Counter('respuestas_429');

export const options = {
  scenarios: {
    carga_normal: {
      executor: 'constant-vus',
      vus: clientes,
      duration: duracion,
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.01'],
    checks: ['rate>0.99'],
    respuestas_429: ['count==0'],
  },
};

// Lo que pide la app al abrir el catálogo, y el estado del servidor.
const peticiones = [
  ['productos', `${api}/productos`],
  ['categorias', `${api}/categorias`],
  ['salud', `${api}/health`],
];

export default function () {
  for (const [nombre, url] of peticiones) {
    const respuesta = http.get(url, { tags: { endpoint: nombre } });
    if (respuesta.status === 429) {
      respuestas429.add(1);
    }
    check(respuesta, {
      [`${nombre}: 200`]: (r) => r.status === 200,
    });
  }
  sleep(1);
}
