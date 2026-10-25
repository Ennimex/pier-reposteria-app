-- docker/semilla/semilla_pruebas.sql — datos de prueba del entorno aislado.
--
-- Corre una sola vez, al crear la base del contenedor, después de las
-- migraciones del backend (base.Dockerfile la copia como
-- 900_semilla_pruebas.sql). Todo es ficticio y solo existe dentro del
-- contenedor:
--   · 1 cliente activo con el correo verificado, para iniciar sesión:
--     cliente@pier.test. Su contraseña ficticia está en
--     test/api/entorno_aislado.dart; aquí solo va su hash bcrypt (costo 10),
--     generado una vez con bcryptjs, la misma librería con que el backend la
--     compara al iniciar sesión. No es la cuenta de prueba real
--     (USUARIO_PRUEBA) ni ninguna de producción.
--   · 2 categorías.
--   · 4 productos activos: 3 con existencias y 1 agotado (stock_online = 0).
-- Las pruebas de test/api/ y los scripts de pruebas/k6/ cuentan con estos
-- datos; si cambian aquí, cambian allá.

INSERT INTO core.tblusuarios
    (nombre, apellido, email, password_hash, rol, activo, email_verificado)
VALUES
    ('Cliente', 'Prueba', 'cliente@pier.test',
     '$2a$10$OdYuFpq.Zv0WD/DMoTWWDei.alggEc4WIMSg9CPVJuAfbgMkskvru',
     'cliente', true, true);

INSERT INTO core.tblcategorias (nombre, orden)
VALUES
    ('Pasteles', 1),
    ('Pays', 2);

INSERT INTO core.tblproductos
    (nombre, categoria_id, precio_chico, stock_online, activo)
VALUES
    ('Chocoflan',
     (SELECT id FROM core.tblcategorias WHERE nombre = 'Pasteles'),
     350.00, 12, true),
    ('Pastel de tres leches',
     (SELECT id FROM core.tblcategorias WHERE nombre = 'Pasteles'),
     420.00, 8, true),
    ('Pay de queso',
     (SELECT id FROM core.tblcategorias WHERE nombre = 'Pays'),
     250.00, 5, true),
    ('Pay de limón',
     (SELECT id FROM core.tblcategorias WHERE nombre = 'Pays'),
     230.00, 0, true);
