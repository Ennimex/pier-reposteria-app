// pruebas/k6/esfuerzo.js — prueba de esfuerzo de la API contra el entorno
// aislado (tool/entorno_pruebas.sh): nunca contra producción.
//
// Qué revisa: que la API aguanta más clientes de lo normal y, sobre todo, que
// se recupera después. Tiene dos escenarios:
//   · esfuerzo: sube a 10 clientes, los sostiene, sube a un pico de 25 y baja
//     a 0. Debe fallar menos del 1 % y el p95 quedar por debajo de 1.5 s.
//   · recuperacion: empieza 5 s después de que termina el esfuerzo, con solo
//     2 clientes. Tiene sus propios umbrales (fase:recuperacion): p95 por
//     debajo de 500 ms y menos del 1 % de errores. Si la API se quedó
//     atascada por el pico, aquí se nota.
// Cada vuelta de un cliente pide una cosa distinta, como la app: productos,
// categorías, el detalle de un producto, su carrito (con sesión) y el estado
// del servidor; luego espera 1 s.
//
// Cómo se corre (esfuerzo.yml):
//   k6 run --summary-export build/resultados/k6_esfuerzo.json \
//     --env API_BASE_URL=http://localhost:3000/api --env CARGA=reducida \
//     pruebas/k6/esfuerzo.js
// CARGA es «reducida» en los Pull Requests (las fases duran la mitad) y
// «completa» con la casilla del pipeline.
//
// Límite conocido del backend: 3,000 peticiones cada 15 minutos por IP (al
// pasarlo contesta 429) y bloqueo de la cuenta tras 5 inicios de sesión
// fallidos. Por eso:
//   · solo hay 1 inicio de sesión en toda la prueba (setup), con la cuenta de
//     la semilla, y nunca uno fallido;
//   · cada cliente hace 1 petición por vuelta y espera 1 s, así que hace
//     menos de 1 petición por segundo. Clientes × segundos de cada fase:
//       completa: 5×30 + 10×60 + 17.5×30 + 12.5×30 + 2×30 = 1,710 → < 1,710 peticiones
//       reducida: 5×15 + 10×30 + 17.5×15 + 12.5×15 + 2×20 =   865 → <   865 peticiones
//     (17.5 y 12.5 son el promedio de clientes mientras sube de 10 a 25 y
//     baja de 25 a 0). Las dos quedan por debajo de 3,000.
// Si algún día se pasara, el contador respuestas_429 lo dice y su umbral hace
// fallar la prueba: el 429 es un límite del sistema, no se esconde.
import { check, fail, sleep } from 'k6';
import http from 'k6/http';
import { Counter } from 'k6/metrics';

const api = __ENV.API_BASE_URL ?? 'http://localhost:3000/api';
const cargaCompleta = __ENV.CARGA === 'completa';

// La cuenta de docker/semilla/semilla_pruebas.sql: ficticia, solo existe en
// el contenedor (la misma de test/api/entorno_aislado.dart).
const correoDeLaSemilla = 'cliente@pier.test';
const claveDeLaSemilla = 'Chocoflan-Prueba-2026';

// Duración de cada fase en segundos: la reducida dura la mitad.
const factor = cargaCompleta ? 1 : 0.5;
const segundos = (base) => `${Math.round(base * factor)}s`;
const fases = [
  { duration: segundos(30), target: 10 }, // subir
  { duration: segundos(60), target: 10 }, // sostener
  { duration: segundos(30), target: 25 }, // pico
  { duration: segundos(30), target: 0 }, //  bajar
];
const duracionDelEsfuerzo = 150 * factor;

const respuestas429 = new Counter('respuestas_429');

export const options = {
  scenarios: {
    esfuerzo: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: fases,
      gracefulRampDown: '5s',
      tags: { fase: 'esfuerzo' },
    },
    recuperacion: {
      executor: 'constant-vus',
      vus: 2,
      duration: cargaCompleta ? '30s' : '20s',
      startTime: `${duracionDelEsfuerzo + 5}s`,
      tags: { fase: 'recuperacion' },
    },
  },
  thresholds: {
    'http_req_failed{fase:esfuerzo}': ['rate<0.01'],
    'http_req_duration{fase:esfuerzo}': ['p(95)<1500'],
    'http_req_failed{fase:recuperacion}': ['rate<0.01'],
    'http_req_duration{fase:recuperacion}': ['p(95)<500'],
    checks: ['rate>0.99'],
    respuestas_429: ['count==0'],
  },
};

// Antes de los clientes: un solo inicio de sesión y los ids del catálogo.
export function setup() {
  const sesion = http.post(
    `${api}/auth/login`,
    JSON.stringify({ email: correoDeLaSemilla, password: claveDeLaSemilla }),
    { headers: { 'Content-Type': 'application/json' }, tags: { endpoint: 'login' } },
  );
  if (sesion.status !== 200) {
    fail(`no se pudo iniciar sesión con la cuenta de la semilla: ${sesion.status} ${sesion.body}`);
  }
  const catalogo = http.get(`${api}/productos`, { tags: { endpoint: 'productos' } });
  const ids = catalogo.json('productos').map((producto) => producto.id);
  return { token: sesion.json('token'), ids };
}

export default function (datos) {
  const sesion = { headers: { Authorization: `Bearer ${datos.token}` } };
  const idDelProducto = datos.ids[__ITER % datos.ids.length];
  // Una petición por vuelta, rotando entre lo que pide la app.
  const peticiones = [
    ['productos', () => http.get(`${api}/productos`, { tags: { endpoint: 'productos' } })],
    ['categorias', () => http.get(`${api}/categorias`, { tags: { endpoint: 'categorias' } })],
    ['detalle', () => http.get(`${api}/productos/${idDelProducto}`, { tags: { endpoint: 'detalle' } })],
    ['carrito', () => http.get(`${api}/carrito`, { ...sesion, tags: { endpoint: 'carrito' } })],
    ['salud', () => http.get(`${api}/health`, { tags: { endpoint: 'salud' } })],
  ];
  const [nombre, pedir] = peticiones[(__VU + __ITER) % peticiones.length];
  const respuesta = pedir();
  if (respuesta.status === 429) {
    respuestas429.add(1);
  }
  check(respuesta, {
    [`${nombre}: 200`]: (r) => r.status === 200,
  });
  sleep(1);
}
