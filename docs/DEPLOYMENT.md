# Conectar Supabase y publicar

El repositorio incluye un flujo para publicar desde GitHub Actions. Se ejecuta manualmente y no despliega si falta la configuración de Supabase. La aplicación aún no está publicada y Pages todavía necesita activarse.

## 0. Activar GitHub Pages

Abre [Settings → Pages](https://github.com/hamstersoftwarecol/Aplicacion-de-gestion-de-lavanderia/settings/pages) y selecciona **Source: GitHub Actions**. La integración usada en esta tarea puede subir código, pero GitHub rechazó activar Pages mediante API con `403 Resource not accessible by integration`; este paso requiere al propietario desde la interfaz de GitHub.

## 1. Crear el proyecto Supabase

Abre https://supabase.com/dashboard y crea el proyecto. Conserva la contraseña de la base de datos fuera del repositorio y del chat.

En SQL Editor, ejecuta **una vez y en este orden** los archivos de este repositorio:

1. [Esquema y permisos](../supabase/migrations/202610080001_schema.sql).
2. [Pedidos, pagos y estados](../supabase/migrations/202610080002_order_operations.sql).
3. [Panel de resumen](../supabase/migrations/202610080003_dashboard.sql).

Estos archivos están preparados para una base nueva. No se han aplicado a ningún proyecto alojado durante esta tarea.

## 2. Crear la primera cuenta

En Authentication, desactiva el registro público y crea un usuario administrador con correo y contraseña desde la consola. Esta versión permite iniciar sesión con cuentas ya creadas; no incluye un formulario público de registro o de aceptación de invitaciones.

Copia el UUID de ese usuario y ejecuta en SQL Editor:

```sql
insert into public.profiles (id, name, role, active)
values ('UUID-DEL-USUARIO', 'Administrador', 'admin', true);
```

Para empleados, crea también su cuenta Auth y su perfil con `role = 'employee'`. No guardes contraseñas en la tabla `profiles`.

## 3. Guardar la configuración pública

En Project Settings de Supabase, identifica la URL del proyecto y su clave **publishable** (`sb_publishable_...`) o la clave pública heredada **anon**. Nunca uses `service_role`, `sb_secret_...` ni la contraseña de la base.

En [las variables del repositorio GitHub](https://github.com/hamstersoftwarecol/Aplicacion-de-gestion-de-lavanderia/settings/variables/actions), crea:

| Variable | Valor |
| --- | --- |
| `SUPABASE_URL` | URL HTTPS del proyecto |
| `SUPABASE_ANON_KEY` | Clave pública publishable o anon |

Son valores públicos: Flutter los incorpora al navegador. La protección de los datos depende de las políticas RLS de las migraciones y de las sesiones de los usuarios. El validador de publicación rechaza claves administrativas; no comprueba autenticidad ni sustituye la prueba de conexión.

## 4. Comprobar el servicio antes de publicar

Sigue la configuración local del README e inicia sesión con las cuentas creadas. Comprueba crear un cliente y servicio, registrar un pedido, abonar, completar el pago y entregar. Verifica el mismo pedido desde otra sesión y que el empleado no puede modificar precios.

La prueba automatizada de `integration_test/laundry_flow_test.dart` requiere un proyecto dedicado a pruebas y dos cuentas, según el README. No publiques su compilación: contiene credenciales de prueba. El flujo de publicación siempre compila `lib/main.dart`.

## 5. Publicar

En [GitHub Actions](https://github.com/hamstersoftwarecol/Aplicacion-de-gestion-de-lavanderia/actions/workflows/deploy-pages.yml), selecciona **Publish web application → Run workflow → main**.

El flujo valida la configuración pública, instala la versión fijada de Flutter, ejecuta análisis/pruebas, compila con la ruta base de GitHub Pages y publica el artefacto. La URL real aparece en el resultado del trabajo `deploy`. No hay despliegues automáticos en cada push.

Después de publicar, configura esa URL como Site URL en Authentication de Supabase si usas correos de autenticación y verifica de nuevo el acceso desde el sitio público. Una compilación exitosa no demuestra por sí sola que el backend esté configurado.

## Compilación equivalente en local

Carga `SUPABASE_URL` y `SUPABASE_ANON_KEY` en el entorno de tu terminal y ejecuta:

```sh
./scripts/build_deployment.sh /Aplicacion-de-gestion-de-lavanderia/
```

En el entorno cloud, ejecuta antes `source scripts/flutter_env.sh`. El archivo temporal de configuración se elimina al terminar; no se escribe ninguna clave en Git. El flujo de despliegue conserva el sitio anterior si la compilación falla.
