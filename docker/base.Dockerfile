# docker/base.Dockerfile — la base de datos PostgreSQL del entorno aislado de
# pruebas, con el esquema del backend y una semilla de datos ficticios.
#
# Hace falta PostgreSQL 17: migrations/000_esquema_referencia.sql usa
# «SET transaction_timeout» y «\restrict», que PostgreSQL 16 no entiende.
FROM postgres:17-alpine

# Al crear la base por primera vez, la imagen ejecuta en orden alfabético los
# .sql de /docker-entrypoint-initdb.d/ con ON_ERROR_STOP: cualquier error
# detiene la creación (y el contenedor no queda sano).
#   1. Las migraciones del backend, 000_esquema_referencia.sql a 011_feed.sql,
#      tal cual están en el commit de docker/backend.version (contexto
#      «backend» de compose.pruebas.yml).
#   2. Al final, la semilla de datos de prueba (900_…, después de todas).
COPY --from=backend migrations/0*.sql /docker-entrypoint-initdb.d/
COPY semilla/semilla_pruebas.sql /docker-entrypoint-initdb.d/900_semilla_pruebas.sql
