# Estado de implementación

Primera versión de Flutter Web implementada en español: clientes, servicios, pedidos, estados, abonos manuales, historial, panel y roles. PostgreSQL/Supabase impone RLS y operaciones transaccionales. El código usa el checkout cloud existente y está publicado en la rama `main` de GitHub.

## Evidencia y límites

- Flutter 3.44.0; análisis estático sin incidencias y compilación web verificados.
- 15 pruebas Flutter aprobadas: dominio, formularios, creación/pago/entrega, reintento de pago y revocación de sesión.
- PostgreSQL 17: acceso anónimo/empleado/administrador, registros inválidos, pedidos/pagos, agregación, catálogo cambiado y transacciones simultáneas.
- Servidor de desarrollo y artefacto compilado sirven HTML, bootstrap y JavaScript mediante peticiones HTTP locales.
- Supabase alojado y despliegue **pendientes**: el propietario creará el proyecto después. La prueba optativa está en `integration_test/laundry_flow_test.dart`; no se ha ejecutado contra un servicio remoto.
- Arranque real de Flutter confirmado en Chromium mediante Playwright: desaparece el indicador inicial, aparece la vista Flutter y la captura muestra la pantalla de conexión pendiente. Roboto e iconos se incluyen localmente; no se desactivó TLS. Esto no valida las pantallas autenticadas contra Supabase remoto.
- Borrador cloud: `install_script` y `start_skill` guardados. El SDK y cachés se conservan en el snapshot; los procesos deben reiniciarse. El borrador no publica el entorno ni la aplicación.

## Revisión independiente

Tres hallazgos importantes, corregidos con regresiones que fallaron antes del cambio: rutas protegidas abiertas después de cerrar sesión, errores de autorización que conservaban el editor y cambios concurrentes de catálogo que reinterpretan cantidades/precios. No quedaron hallazgos menores aplazados de esa revisión. Los commits de implementación y correcciones se subieron a `main` por petición del propietario.

## Decisiones de ejecución y límites asociados

- Ruling: Use existing isolated cloud checkout on work; no worktree — onboarding instructions and approved plan — no additional isolation needed.
- Ruling: Skill scripts unavailable as local executables; maintain equivalent task briefs and ledger directly — preserves traceability — manual bookkeeping risk.
- Ruling: Validate SQL on isolated PostgreSQL 17 with a minimal auth.uid adapter; Docker is available and no hosted binding exists — exercises actual database constraints/RLS — hosted Auth integration still requires separate validation.
- Ruling: Use assertion SQL via psql instead of pgTAP to avoid an unnecessary test-extension dependency — same behavioral assertions — commands differ from original plan.
- Ruling: Obtain Flutter from Cirrus Labs published container pinned by digest; official archive domain blocked — no TLS/checksum bypass — third-party packaging dependency.
- Ruling: Share a typed repository contract and reusable client/service editor instead of duplicate per-table scaffolding — same feature boundaries with fewer identical widgets — generic row decoding requires integration coverage.
- Ruling: User will create Supabase later. Continue all local implementation and tests; hosted login/persistence remains explicitly unverified until configured.
- Ruling: Full Flutter image exceeds environment storage due to Docker layer copies. Extract only SDK paths from digest-verified registry layers with TLS intact — preserves toolchain, avoids Android runtime duplication — fallback packaging procedure documented.
- Ruling: Bogotá uses fixed UTC−5 for current/future operational dates instead of bundling timezone database — current Colombia rules — must update if legal time zone changes.
- Ruling: Database readiness checks TCP rather than initial temporary Unix socket — observed startup race after environment restart — slightly longer startup, avoids false readiness.
- Ruling: Whole review template resource unavailable from cloud skill; reviewer receives spec, plan, complete code range and explicit review focus directly — equivalent review scope — no omitted requirements intended.
- Final: Ruling: Expand order-item request to include expected_unit and expected_price_minor — server must reject catalog changes rather than reinterpret stored quantity — all callers must send the new fields; migration/frontend/tests updated together.
- Final: Ruling: Hosted integration/deployment remain deferred to user project creation — explicitly requested by user — cannot claim online Auth or production readiness.
- Final: Ruling: Reviewer excluded toolchain provenance, test adapter/framework, repository factoring and fixed time offset from code review — retain prior documented choices and their limitations — local SQL evidence does not replace hosted Supabase validation.

- Ruling: Incluir Roboto y CupertinoIcons en los assets — el motor Flutter intentaba descargar la fuente principal y avisaba de iconos ausentes — aumenta ligeramente el tamaño del bundle, conserva licencias y evita depender del CDN para el arranque verificado.

## Preparación de publicación

Flujo manual para GitHub Pages, validación de claves públicas y guía en `docs/DEPLOYMENT.md`. GitHub denegó la activación de Pages mediante la integración (HTTP 403); el propietario debe seleccionar GitHub Actions en Settings → Pages. Supabase sigue sin existir y no se ha ejecutado una publicación pública de la aplicación.
