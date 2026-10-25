# docker/backend.Dockerfile — la API del backend de Pier
# (PedroRubioo/pier-reposteria-backend) para el entorno aislado de pruebas.
#
# El código del backend no vive en este repositorio: tool/entorno_pruebas.sh
# (o el pipeline) lo descarga en .backend/ al commit de docker/backend.version,
# y docker/compose.pruebas.yml lo pasa a esta imagen como el contexto
# «backend». No se cambia nada del backend: se instala y se arranca igual que
# en producción, con variables de prueba (ver compose.pruebas.yml).
FROM node:22-alpine

WORKDIR /app

# Primero las dependencias (solo las de producción, sin las de desarrollo),
# para que Docker reutilice esta capa mientras no cambie package-lock.json.
COPY --from=backend --chown=node:node package.json package-lock.json ./
RUN npm ci --omit=dev

# Después el código del backend.
COPY --from=backend --chown=node:node . .

# La API corre con el usuario sin privilegios que trae la imagen de Node.
USER node

# server.js lee el puerto de PORT (3000 en compose.pruebas.yml).
CMD ["node", "server.js"]
