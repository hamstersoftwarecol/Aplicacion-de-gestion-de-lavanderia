# Lavandería · Flutter Web + Supabase

Aplicación en español para una lavandería: clientes, catálogo por pieza/kg, pedidos, estados, abonos manuales, historial y panel. Administradores gestionan catálogo y perfiles; empleados gestionan la operación. No incluye cobros bancarios, devoluciones ni facturación fiscal.

## Desarrollo

La versión exacta del SDK se registra en `.flutter-version` una vez verificada. Instala Flutter desde su distribución oficial y ejecuta desde este repositorio:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define-from-file=/ruta/config-publica.json
```

Formato de `config-publica.json` (URL y clave pública, nunca service_role):

```json
{"SUPABASE_URL":"https://TU-PROYECTO.supabase.co","SUPABASE_ANON_KEY":"TU-CLAVE-PUBLICA"}
```

Las variables dart-define quedan incorporadas en el JavaScript. No colocar contraseñas ni claves administrativas allí. Sin configuración la aplicación explica cómo conectarla y no simula datos persistentes.

## Supabase de desarrollo

1. Crea un proyecto de desarrollo en Supabase. No usar datos de producción para pruebas.
2. Aplica los archivos `supabase/migrations/*.sql` en orden desde SQL Editor o el flujo de migraciones de Supabase CLI. Una migración es una operación administrativa: revisa la base destino antes de ejecutarla.
3. Desactiva el registro público en Authentication. Invita o crea usuarios desde la consola, conservando la política de contraseñas de Supabase.
4. Copia el UUID del primer usuario en la siguiente consulta administrativa, reemplazando el ejemplo. No hay contraseñas en la tabla de perfiles:

```sql
insert into public.profiles(id, name, role, active)
values ('UUID-DEL-USUARIO-AUTH', 'Administrador', 'admin', true);
```

5. Para cada invitación adicional, crea su perfil con rol `employee`; después un administrador podrá cambiar rol/estado desde Personal. Eliminar usuarios Auth con historial está restringido; desactiva su perfil.
6. Configura la URL y clave pública y accede con una cuenta activa.

RLS limita lectura y escritura. Las RPC calculan importes, serializan pagos/cambios de estado y registran historial en una transacción. Los pagos no son editables ni eliminables; confirmar siempre el importe antes de registrar. Una corrección financiera requiere un procedimiento administrativo fuera de esta versión, conservando auditoría.

## Pruebas de base de datos

Requiere Docker y Python 3:

```sh
./scripts/test_database.sh
```

Crea un contenedor PostgreSQL 17 desechable sin puerto publicado, aplica un adaptador mínimo de `auth.uid()` y todas las migraciones, ejecuta pruebas de acceso/negocio y concurrencia y elimina solo ese contenedor. No conecta a una base externa. Valida PostgreSQL y RLS; no sustituye comprobar Auth y API de un proyecto Supabase real.

## Reglas operativas

COP en centavos enteros; kg en milésimas; piezas enteras. Introduce `12500,50` para dinero y `1,250` para kg, sin separadores de miles. Redondeo por línea, mitad hacia arriba. Bogotá (UTC−5) define el día comercial. Límites: precio hasta 10.000.000.000 COP, cantidad hasta 1.000.000 unidades internas, 100 líneas por pedido y total máximo de 9.000.000.000.000.000 centavos para preservar exactitud en web.

Los pedidos avanzan recibido → en proceso → listo → entregado; entrega exige saldo cero. Se puede cancelar recibido/en proceso únicamente sin pagos. El detalle queda fijo al confirmar. Clientes/servicios archivados conservan historial pero no se usan en pedidos nuevos.

## Publicación

```sh
flutter build web --dart-define-from-file=/ruta/config-publica.json
```

Publicar `build/web` requiere un alojamiento HTTPS elegido por el propietario. No se ha publicado ningún sitio ni creado servicios externos automáticamente. Los procesos de desarrollo no sobreviven a una restauración cloud: iniciar de nuevo siguiendo los comandos anteriores, usando el checkout existente sin crear otro worktree.

## Integración con Supabase real (pendiente hasta configurar el proyecto)

El propietario ha indicado que creará Supabase más adelante. La prueba de `integration_test/laundry_flow_test.dart` necesita un proyecto **dedicado a pruebas**, un administrador activo y un empleado activo. Crea pedidos y pagos duraderos; al terminar archiva el cliente/servicio de prueba, no borra el historial.

En un archivo local fuera del repositorio añade a la configuración pública: `RUN_SUPABASE_INTEGRATION: true`, `TEST_ADMIN_EMAIL`, `TEST_ADMIN_PASSWORD`, `TEST_EMPLOYEE_EMAIL` y `TEST_EMPLOYEE_PASSWORD`. No compartir ni publicar la compilación de esta prueba: las credenciales de prueba quedan incorporadas en ella. Nunca usar cuentas de producción. Inicia ChromeDriver en el puerto 4444 y ejecuta:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/laundry_flow_test.dart -d chrome \
  --dart-define-from-file=/ruta/segura/laundry-test-config.json
```

Sin la bandera la prueba se omite explícitamente. Las pruebas normales `flutter test` usan repositorios de prueba para los widgets y no afirman validar el servicio remoto.

En este entorno cloud, antes de usar Flutter ejecuta `source scripts/flutter_env.sh`. Redirige cachés y estado del analizador a rutas escribibles, sin modificar HOME. Flutter 3.44.0 está preparado en `/workspace/toolchains/flutter`.

Los borradores de pedido incluyen el precio y la unidad que vio el operador. Si otro administrador cambia el catálogo antes de confirmar, el servidor rechaza el pedido sin guardar filas; quita y agrega el servicio para revisar el nuevo importe.

## Validación realizada

15 pruebas Flutter aprobadas, análisis estático sin incidencias, compilación web correcta y pruebas SQL de permisos, importes, estados y concurrencia aprobadas. Se comprobó el arranque de la pantalla de conexión en Chromium con las fuentes incluidas localmente. La integración autenticada con Supabase remoto y la publicación siguen pendientes. Consulta `docs/IMPLEMENTATION.md` para decisiones y límites de la validación.
