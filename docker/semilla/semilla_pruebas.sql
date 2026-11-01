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
--   · 1 pedido completado de la cuenta de la semilla, recogido en la
--     sucursal y pagado con tarjeta: 1 «Pastel de tres leches». Llena el
--     historial de «Mis Pedidos» y es la compra que vuelve «verificada» la
--     reseña de ese producto (#65). No cambia existencias ni el carrito.
-- Las pruebas de test/api/, los scripts de pruebas/k6/ y los flujos de
-- integration_test/flujos/ cuentan con estos datos; si cambian aquí,
-- cambian allá.

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

-- El pedido completado, con su renglón y su pago, en una sola sentencia, como
-- los guarda el backend al confirmar un pago (routes/pagosRoutes.js). Las
-- fechas son relativas al día en que se crea la base: se pidió hace 3 días y
-- se recogió al día siguiente. El folio es ficticio (los reales llevan la
-- fecha) y único: si ya existe, no se inserta nada. El pago no tiene intento
-- de Stripe: la llave del entorno aislado es ficticia.
WITH pedido AS (
    INSERT INTO core.tblpedidos
        (numero, usuario_id, total, estado, horario_recogida, metodo_pago,
         tipo_entrega, costo_envio, por_confirmar, created_at, updated_at)
    SELECT 'PIER-PRUEBA-0001', u.id, p.precio_chico,
           'completado'::public.estado_pedido, now() - interval '2 days',
           'tarjeta', 'pickup', 0, false,
           now() - interval '3 days', now() - interval '2 days'
      FROM core.tblusuarios u, core.tblproductos p
     WHERE u.email = 'cliente@pier.test' AND p.nombre = 'Pastel de tres leches'
    ON CONFLICT (numero) DO NOTHING
    RETURNING id, total, created_at
), renglon AS (
    INSERT INTO core.tblpedido_items
        (pedido_id, producto_id, nombre_producto, cantidad, tamano,
         precio_unitario, subtotal, stock_descontado)
    SELECT pedido.id, p.id, p.nombre, 1, 'chico',
           p.precio_chico, p.precio_chico, 1
      FROM pedido, core.tblproductos p
     WHERE p.nombre = 'Pastel de tres leches'
)
INSERT INTO core.tblpagos
    (pedido_id, monto_subtotal, monto_total, estado, created_at)
SELECT pedido.id, pedido.total, pedido.total,
       'pagado'::public.estado_pago, pedido.created_at
  FROM pedido;
