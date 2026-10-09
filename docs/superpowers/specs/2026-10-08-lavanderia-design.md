# Gestión de lavandería — diseño de la primera versión

## Objetivo y alcance aprobado
Aplicación en español construida con Flutter Web, adaptable a computador y móvil, para que administradores y empleados gestionen clientes, servicios, pedidos, pagos manuales y entregas. Supabase proporciona autenticación y PostgreSQL compartido. La primera versión sirve a una sola lavandería. No incluye portal de clientes, pasarela de pago, facturación fiscal, notificaciones ni funcionamiento sin conexión.

El éxito consiste en iniciar sesión, registrar un cliente, crear un pedido con varios servicios, registrar abonos y completar su entrega conservando un historial consultable desde otro dispositivo autorizado.

## Arquitectura
Flutter separará presentación, modelos de dominio y repositorios de acceso a Supabase. Los módulos serán autenticación, clientes, catálogo, pedidos, pagos y panel. La lógica de importes y transiciones tendrá pruebas independientes de la interfaz. PostgreSQL garantizará integridad, permisos y operaciones atómicas; las restricciones no dependerán únicamente de los controles visuales.

La URL y clave pública de Supabase serán configuración de compilación. La aplicación nunca incluirá claves administrativas. Las migraciones SQL y las instrucciones de configuración formarán parte del repositorio. El proyecto remoto y sus credenciales deberán configurarse para validar el flujo en línea; una demostración con datos locales no contará como integración verificada.

## Usuarios y permisos
No habrá registro público. El primer administrador será aprovisionado mediante Supabase por el propietario. Los administradores podrán asignar roles o desactivar perfiles ya aprovisionados; crear credenciales e invitar usuarios se hará desde la consola de Supabase en esta versión, sin exponer privilegios administrativos en Flutter.

Ambos roles podrán consultar y registrar clientes, pedidos y pagos. Solo administradores podrán modificar el catálogo, roles y estado activo de los perfiles. Las políticas RLS comprobarán que el usuario está activo y su rol; usuarios anónimos o desactivados no accederán a datos del negocio. Ningún usuario podrá promoverse a sí mismo ni desactivar al último administrador.

## Datos e integridad
- Perfiles: identificador de Auth, nombre, rol y estado activo.
- Clientes: nombre obligatorio, teléfono obligatorio, correo y notas opcionales, fecha de creación y estado activo. Archivar no elimina su historial.
- Servicios: nombre, unidad (pieza o kilogramo), precio positivo y estado activo. Solo servicios activos podrán añadirse a nuevos pedidos.
- Pedidos: número único generado en servidor, cliente, estado, fecha de recepción, fecha de entrega prevista, notas y usuario creador.
- Detalles: servicio, nombre/unidad/precio históricos, cantidad y subtotal. Cambiar el catálogo no cambiará pedidos existentes.
- Pagos: pedido, importe positivo, método (efectivo, transferencia o tarjeta registrada manualmente), fecha, autor y referencia opcional.
- Historial de estados: pedido, estado anterior y nuevo, fecha y autor.

Los importes usarán enteros en unidades monetarias menores; las cantidades usarán milésimas de kilogramo o unidades enteras para piezas. Se redondeará cada subtotal a la unidad monetaria menor y el total será la suma de subtotales. Se usará COP inicialmente, con formato y zona horaria America/Bogota centralizados y documentados como valores iniciales. No se agregarán impuestos o descuentos implícitos.

Los pagos serán inmutables en esta versión. La interfaz exigirá confirmación antes de registrarlos; una clave de idempotencia impedirá duplicarlos al reintentar. La base de datos bloqueará el pedido durante el registro para impedir sobrepagos concurrentes. No habrá eliminación de pedidos o pagos desde la aplicación. Correcciones financieras y devoluciones quedan fuera de este alcance y requerirán un procedimiento administrativo separado.

## Flujo de pedidos y pagos
Crear un pedido exige cliente activo, al menos un servicio y cantidades positivas. Su creación, detalles y primer evento de historial se guardarán en una única transacción. Los detalles quedarán fijos tras confirmar el pedido; la pantalla permitirá revisarlos antes de guardar.

Transiciones permitidas: recibido → en proceso → listo → entregado. Un pedido recibido o en proceso podrá cancelarse únicamente si no tiene pagos. Entregado y cancelado son estados finales. La entrega requiere saldo cero. Los pagos se aceptarán en pedidos no cancelados con saldo pendiente. La fecha prevista no podrá ser anterior a la recepción.

El servidor calculará y validará totales, saldo y transiciones. Si otra sesión cambia el pedido, la operación incompatible se rechazará y la interfaz actualizará sus datos, conservando una explicación legible.

## Pantallas
Navegación lateral en escritorio y navegación adaptada en móvil. Panel con pedidos activos, entregas previstas para hoy y saldo pendiente de pedidos no cancelados. Listas de clientes y pedidos con búsqueda y paginación; pedidos filtrables por estado. Fichas con historial, formulario de cliente, catálogo, formulario de pedido con resumen de importes y detalle de pedido con acciones de estado y pagos.

La sesión tendrá estados de carga, acceso denegado y cierre de sesión. Los formularios mostrarán errores junto a los campos y evitarán envíos duplicados. Las pantallas distinguirán carga, lista vacía y fallo de conexión. Ante un fallo no se mostrará una operación como exitosa; habrá reintento y actualización después de cada escritura. Los controles incluirán etiquetas accesibles y soporte de teclado.

## Validación y entrega
Ejecutar análisis estático, pruebas de dominio (cantidades, redondeo, saldos y transiciones), pruebas de widgets de los formularios principales y compilación web. Validar contra Supabase las políticas de acceso anónimo, empleado y administrador, la creación atómica, el rechazo de sobrepagos y la idempotencia de pagos.

Prueba funcional: iniciar sesión, crear cliente y servicio, crear pedido, registrar abono, comprobar saldo, completar pago, avanzar estados y entregar; comprobar persistencia desde otra sesión. Probar errores de red y una escritura concurrente incompatible. Las pruebas usarán datos aislados de desarrollo y nunca datos de producción.

La entrega incluirá código Flutter, migraciones, instrucciones para provisionar el primer administrador, configuración sin secretos y comandos de instalación, pruebas y arranque. La publicación del sitio y la provisión de servicios remotos no se considerarán realizadas sin evidencia. Las validaciones bloqueadas por credenciales se reportarán como pendientes.
