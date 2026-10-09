# Laundry Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar una aplicación web Flutter en español para gestionar una lavandería con datos compartidos y permisos seguros.

**Architecture:** Flutter separa dominio, repositorios y pantallas por funcionalidad. Supabase Auth identifica usuarios y PostgreSQL protege datos con RLS y funciones transaccionales. Los repositorios inyectables permiten probar la interfaz sin confundir simulaciones con integración real.

**Tech Stack:** Flutter estable con Dart incluido, Material 3, supabase_flutter, intl, timezone, uuid; flutter_test e integration_test; PostgreSQL/Supabase y pruebas SQL con pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-08-lavanderia-design.md`

## Global Constraints

- Aplicación en español construida con Flutter Web, adaptable a computador y móvil.
- La primera versión sirve a una sola lavandería.
- No incluye portal de clientes, pasarela de pago, facturación fiscal, notificaciones ni funcionamiento sin conexión.
- Los importes usarán enteros en unidades monetarias menores; las cantidades usarán milésimas de kilogramo o unidades enteras para piezas.
- Se usará COP inicialmente, con formato y zona horaria America/Bogota centralizados y documentados como valores iniciales.
- No habrá registro público. La aplicación nunca incluirá claves administrativas.
- Los pagos serán inmutables en esta versión. La entrega requiere saldo cero.
- Cada tarea conservará las instrucciones y cambios existentes. Usar el checkout cloud actual; no crear un worktree salvo petición explícita.
- Fijar la versión estable disponible de Flutter al implementar y conservar pubspec.lock. No inventar credenciales ni publicar servicios sin autorización.

## Review Focus

- Cantidades localizadas como `1,250` y fracciones de pieza: aceptar 1,250 kg; rechazar piezas fraccionarias (tarea 1).
- Reintento de pago tras perder la respuesta: misma clave y contenido devuelven el mismo pago; contenido diferente se rechaza (tarea 3).
- Dos administradores desactivándose simultáneamente: conservar al menos un administrador activo (tarea 2).
- Caducidad o desactivación de sesión mientras se guarda: no mostrar éxito, retirar datos protegidos y permitir autenticación nueva (tarea 4).
- Entregas cerca de medianoche UTC: el panel debe usar el día comercial de Bogotá (tarea 6).

## Mapa de archivos

`lib/core/` contendrá configuración, dinero y fechas; `lib/features/<modulo>/` agrupará modelos, repositorio y presentación. `lib/app.dart` compondrá dependencias y navegación; `lib/main.dart` inicializará Supabase. `supabase/migrations/` almacenará esquema y funciones; `supabase/tests/` probará autorización e integridad. `test/` reflejará las funcionalidades, `integration_test/` probará el recorrido real y `README.md` documentará configuración y arranque. Los archivos generados por Flutter se limitarán a soporte web y configuración estándar.

### Tarea 1: Base Flutter y reglas de importes y estados

**Files:** crear `pubspec.yaml`, `pubspec.lock`, `.gitignore`, `.metadata`, `analysis_options.yaml`, `.flutter-version`, soporte `web/`, `lib/core/money.dart`, `lib/core/business_time.dart`, `lib/features/orders/order_rules.dart`, `test/core/money_test.dart`, `test/features/orders/order_rules_test.dart`.

**Interfaces:** `enum ServiceUnit { piece, kilogram }`; `int parseQuantity(String text, ServiceUnit unit)`; `int lineSubtotal({required int priceMinor, required int quantity, required ServiceUnit unit})`; `enum OrderStatus { received, processing, ready, delivered, cancelled }`; `bool canTransition(OrderStatus from, OrderStatus to, {required int balanceMinor, required bool hasPayments})`; `DateTime businessDate(DateTime instant)` devuelve fecha comercial en Bogotá.

- [ ] Inspeccionar herramientas, recursos e instrucciones locales. Instalar Flutter estable desde origen oficial conservando verificación TLS y registrar versión exacta; generar soporte web sin sobrescribir documentos.
- [ ] Escribir pruebas: `parseQuantity('1,250', kilogram) == 1250`; piezas `1,5` lanzan FormatException; cero y negativos se rechazan; `lineSubtotal(priceMinor: 1001, quantity: 1500, unit: kilogram) == 1502`; no permitir saltar de received a delivered, entregar con saldo ni cancelar con pagos.
- [ ] Ejecutar `flutter test test/core/money_test.dart test/features/orders/order_rules_test.dart`; confirmar fallos por reglas aún no implementadas.
- [ ] Implementar interfaces con aritmética entera, redondeo medio hacia arriba, validación de cantidades y fechas. Rechazar separadores de miles ambiguos y entradas con más de tres decimales de kg. Añadir las dependencias necesarias con restricciones compatibles y guardar lockfile.
- [ ] Repetir el comando y exigir todas las pruebas aprobadas; crear commit `feat: add laundry domain rules and Flutter foundation` con archivos de esta tarea.

### Tarea 2: Esquema, perfiles y acceso seguro

**Files:** crear `supabase/config.toml`, `supabase/migrations/202610080001_schema.sql`, `supabase/tests/access_test.sql`, `README.md` (provisión de desarrollo y primer administrador).

**Interfaces:** tablas `profiles(id uuid, name text, role text, active boolean)`, `clients(id uuid, name text, phone text, email text, notes text, active boolean, created_at timestamptz)`, `services(id uuid, name text, unit text, price_minor bigint, active boolean)`, `orders(id uuid, number bigint, client_id uuid, status text, received_at timestamptz, due_at timestamptz, notes text, created_by uuid, total_minor bigint)`, `order_items(id uuid, order_id uuid, service_id uuid, service_name text, unit text, price_minor bigint, quantity bigint, subtotal_minor bigint)`, `payments(id uuid, order_id uuid, amount_minor bigint, method text, reference text, created_at timestamptz, created_by uuid, idempotency_key uuid)`, `order_events(id uuid, order_id uuid, from_status text, to_status text, created_at timestamptz, created_by uuid)`. RPC `set_profile_access(p_profile_id uuid, p_role text, p_active boolean) returns void`.

- [ ] Escribir pruebas pgTAP con fixtures aislados: anónimo no lee tablas; empleado activo lee y modifica clientes pero no catálogo ni roles; desactivado no lee; administrador modifica catálogo; no hay autopromoción ni eliminación/desactivación del último administrador. Probar también bloqueo de escritura directa en pedidos, detalles, pagos e historial.
- [ ] Preparar Supabase local si Docker está disponible; de otro modo identificar configuración de un proyecto de desarrollo sin revelar valores. Ejecutar `supabase test db` antes de implementar y registrar el fallo esperado; si no hay backend disponible marcar integración bloqueada, no aprobada.
- [ ] Crear esquema con claves foráneas, restricciones positivas y estados enumerados por CHECK. Activar RLS en todas las tablas; revocar operaciones financieras directas. Crear funciones de rol sin recursión RLS, search_path fijo y privilegios mínimos. Serializar cambios de administradores mediante bloqueo transaccional compartido, prohibir cambios directos de perfiles y cubrir eliminación de perfiles vinculados a Auth.
- [ ] Añadir prueba concurrente en `supabase/tests/admin_concurrency.sh`: ejecutar dos transacciones de desactivación mediante psql contra fixtures; exigir un rechazo y al menos un administrador activo. Documentar ejecución con DATABASE_URL local segura sin imprimirla.
- [ ] Aplicar migraciones en base de desarrollo, ejecutar `supabase test db` y `bash supabase/tests/admin_concurrency.sh`; registrar resultados reales y commit `feat: secure laundry data and staff roles`.

### Tarea 3: Pedidos y pagos transaccionales

**Files:** crear `supabase/migrations/202610080002_order_operations.sql`, `supabase/tests/orders_test.sql`, `supabase/tests/payment_concurrency.sh`.

**Interfaces:** RPC `create_order(p_client_id uuid, p_due_at timestamptz, p_notes text, p_items jsonb) returns uuid`, cada elemento contiene `service_id` y `quantity`; `record_payment(p_order_id uuid, p_amount_minor bigint, p_method text, p_reference text, p_idempotency_key uuid) returns uuid`; `change_order_status(p_order_id uuid, p_expected_status text, p_next_status text) returns void`. Usar estados y unidades en inglés definidos en tareas 1–2; textos españoles solo en presentación.

- [ ] Escribir pruebas SQL: creación con cliente/servicio inactivo falla sin dejar filas; subtotales históricos permanecen al cambiar catálogo; fecha anterior falla; transiciones ilegales y entrega con deuda fallan. Dos llamadas idénticas con clave de pago común devuelven el mismo UUID y una sola fila; reutilizar clave con importe o pedido diferente falla. Rechazar pagos no positivos, sobrepagos y pagos a cancelados.
- [ ] Ejecutar `supabase test db` y confirmar que faltan las funciones objetivo.
- [ ] Implementar RPC atómicas con comprobación de usuario activo, autor derivado de auth.uid(), cálculos enteros equivalentes al dominio y snapshots del catálogo. Bloquear la fila del pedido para pagos y estados, proteger claves de idempotencia con unicidad y devolver pago existente solo si coincide todo el contenido. Insertar historial en la misma transacción y rechazar estados esperados obsoletos.
- [ ] Añadir prueba concurrente: dos pagos distintos mayores que la mitad del saldo inicial; exigir solo un éxito y suma nunca mayor al total. Probar que una cancelación concurrente no admite un pago posterior. Ejecutar `supabase test db` y `bash supabase/tests/payment_concurrency.sh`.
- [ ] Crear commit `feat: add atomic orders payments and status history` tras registrar resultados.

### Tarea 4: Sesión, clientes, catálogo y personal

**Files:** crear `lib/main.dart`, `lib/app.dart`, `lib/core/app_config.dart`, `lib/features/auth/{auth_repository.dart,login_screen.dart,session_gate.dart}`, `lib/features/clients/{client.dart,clients_repository.dart,clients_screen.dart}`, `lib/features/services/{laundry_service.dart,services_repository.dart,services_screen.dart}`, `lib/features/staff/staff_screen.dart`; pruebas `test/features/auth/session_test.dart`, `test/features/clients/clients_screen_test.dart`, `test/features/services/services_screen_test.dart`.

**Interfaces:** `AuthRepository.signIn(String email, String password) -> Future<void>`, `signOut() -> Future<void>`, `watchSession() -> Stream<StaffSession?>`, `refreshProfile() -> Future<StaffSession>`; StaffSession contiene id, name, role y active. `ClientsRepository.list({String query = '', int page = 0}) -> Future<List<Client>>`, `save(ClientDraft draft, {String? id}) -> Future<Client>`, `archive(String id) -> Future<void>`. ServicesRepository ofrece list, save y archive equivalentes con LaundryService/ServiceDraft. Modelos reflejan columnas de tarea 2; listas tienen páginas de 25 y orden estable por nombre e id. Inyectar repositorios, no usar singleton en widgets.

- [ ] Escribir pruebas de widgets con repositorios falsos: validar nombre/teléfono, conservar campos tras error, archivar sin borrar historial, impedir doble envío, ocultar edición de catálogo a empleado; sesión caducada o perfil desactivado durante guardado elimina contenido protegido y no muestra éxito.
- [ ] Ejecutar `flutter test test/features/auth test/features/clients test/features/services` y comprobar fallos esperados.
- [ ] Implementar configuración SUPABASE_URL/SUPABASE_ANON_KEY por dart-define, validación de configuración faltante, login sin registro público y cierre de sesión. Implementar repositorios Supabase, formularios, búsqueda literal escapada, paginación y pantallas diferenciando carga, vacío y error; comprobar perfil al volver a primer plano y tras rechazo de permisos. Personal administra perfiles existentes mediante set_profile_access; nunca invoca API administrativa desde navegador.
- [ ] Verificar widgets en 390×844 y 1440×900, etiquetas semánticas y foco por teclado. Repetir pruebas y commit `feat: add authenticated customer catalog and staff screens`.

### Tarea 5: Interfaz completa de pedidos y pagos

**Files:** crear `lib/features/orders/{order.dart,orders_repository.dart,orders_screen.dart,order_form.dart,order_detail_screen.dart}`, `lib/features/payments/payment_dialog.dart`, `test/features/orders/order_flow_test.dart`.

**Interfaces:** Order/OrderDetail/OrderDraft reflejan pedidos, detalles y eventos; PaymentDraft contiene amountMinor, method, reference e idempotencyKey. `OrdersRepository.list({String query = '', OrderStatus? status, int page = 0, String? clientId}) -> Future<List<Order>>`; `detail(String id) -> Future<OrderDetail>`; `create(OrderDraft draft) -> Future<String>`; `pay(String orderId, PaymentDraft draft) -> Future<String>`; `transition(String id, OrderStatus expected, OrderStatus next) -> Future<void>`. Implementación llama RPC de tarea 3; detalle incluye pagos, saldo y eventos ordenados. Búsqueda por número y nombre del cliente; paginación de 25, orden received_at/id descendente.

- [ ] Escribir pruebas de recorrido con repositorio falso: cliente + dos servicios → revisión → creación; abono → saldo restante → pago completo → entrega. Confirmar que no se envían detalles editables tras creación, que errores no producen éxito y que doble clic ejecuta una llamada. Ante pérdida de respuesta, conservar PaymentDraft con misma clave para reintentar; ante conflicto de estado refrescar detalle y explicar el rechazo.
- [ ] Ejecutar `flutter test test/features/orders/order_flow_test.dart`; comprobar fallo esperado.
- [ ] Implementar listado y filtros, selección de cliente/servicios activos, fecha prevista, cálculo previo, confirmación final y detalle con historial. Añadir diálogo de pago con confirmación explícita, método manual y referencia; deshabilitar acciones incompatibles según reglas sin sustituir validación del servidor. Conectar historial del cliente con filtro clientId.
- [ ] Repetir pruebas, comprobar importes y cantidades localizadas y ejecutar `flutter analyze`; corregir fallos antes del commit `feat: implement laundry order and payment workflow`.

### Tarea 6: Panel, recorrido real y entorno reproducible

**Files:** crear `supabase/migrations/202610080003_dashboard.sql`, `lib/features/dashboard/{dashboard_repository.dart,dashboard_screen.dart}`, `test/features/dashboard/dashboard_test.dart`, `integration_test/laundry_flow_test.dart`, `test_driver/integration_test.dart`; completar `README.md` y `.github/workflows/flutter.yml`.

**Interfaces:** RPC `dashboard_summary() returns jsonb` con active_orders (received/processing/ready), due_today (activos con due_at en día Bogotá) y outstanding_minor (total menos pagos de no cancelados). `DashboardRepository.load() -> Future<DashboardSummary>` refleja estos campos. La agregación se ejecuta en servidor, no sobre una página de pedidos.

- [ ] Escribir prueba de límite temporal: instante `2026-10-09T02:00:00Z` pertenece al 8 de octubre en Bogotá; pedido previsto `2026-10-09T04:59:00Z` pertenece al mismo día y `05:00:00Z` al siguiente. Añadir prueba SQL de resumen con más de 25 pedidos y saldos parciales para descartar sumas basadas en páginas.
- [ ] Ejecutar `flutter test test/features/dashboard/dashboard_test.dart` y `supabase test db`, registrar fallos iniciales y luego implementar panel con agregación restringida a usuario activo y fechas de servidor.
- [ ] Implementar prueba de integración contra backend de desarrollo: administrador crea servicio/cliente, empleado crea pedido y abono, otra sesión ve el saldo, completa pago y entrega; impedir acceso anónimo y edición de catálogo por empleado. Proveer cuentas de prueba por configuración segura; no almacenar contraseñas en Git. Si falta backend o cuentas, informar exactamente qué falta y continuar build/pruebas locales sin declarar éxito en línea.
- [ ] Ejecutar `flutter analyze`, `flutter test` y `flutter build web --dart-define-from-file=/tmp/laundry-public-config.json`; el archivo contiene únicamente URL y clave pública reales cuando estén disponibles. Para integración arrancar ChromeDriver en puerto 4444 y ejecutar `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/laundry_flow_test.dart -d chrome --dart-define-from-file=/tmp/laundry-test-config.json`. Registrar número de pruebas y resultados, sin publicar el archivo de cuentas.
- [ ] Documentar versión Flutter, `flutter pub get`, configuración, migraciones con `supabase db reset` solo en instancia local desechable, provisión del primer administrador, pruebas y `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define-from-file=<config-publica>`. Añadir CI de análisis, pruebas y compilación; las comprobaciones remotas pendientes deben quedar explícitas.
- [ ] Ejecutar el arranque documentado y validar una petición HTTP al documento Flutter y sus recursos; esta comprobación no sustituye el recorrido autenticado. Guardar install_script/start_skill en borrador cloud con directorios y checks probados, preservando configuración conocida y aclarando procesos que deben reiniciarse.
- [ ] Revisar cambios y secretos, crear commit `feat: add dashboard and verify laundry development workflow`. Informar comprobaciones aprobadas, fallidas o bloqueadas y solicitar revisión final de implementación antes de cualquier publicación externa.

## Revisión del plan

Cobertura: datos, roles y RLS (2), atomicidad e historial (3), sesión y formularios (4), recorrido de pedidos/pagos (5), panel y operación reproducible (6), aritmética y estados (1). Las cinco condiciones de Review Focus tienen pruebas asignadas. Los repositorios usan los mismos identificadores y unidades que el esquema. No se da por disponible Supabase ni se sustituye la validación remota por mocks. Ejecutar secuencialmente porque las interfaces del dominio y la base sustentan las pantallas.
