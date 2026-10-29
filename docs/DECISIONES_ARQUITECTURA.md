# Decisiones de arquitectura

Registro de decisiones observables en el código, revisado el **29-oct-2026**.
«Implementada» significa presente en el repositorio; no acredita aplicación en nube
ni aceptación de todas las excepciones de seguridad.

## D01 · Separar las raíces por ciclo de vida

**Estado:** implementada. **Fuente:** [bootstrap](../bootstrap/state),
[staging](../environments/staging) y [efímero](../environments/ephemeral).

El bucket de estado, la adopción de infraestructura compartida y las pruebas
desechables tienen ciclos de vida distintos. Se mantienen raíces y claves de estado
separadas para reducir el riesgo de ejecutar una operación en el entorno equivocado.
La separación no impide errores de credenciales o backend; deben verificarse antes
cada intervención. Staging usa nombres fijos; el efímero exige workspace `eph-*`.

## D02 · Adoptar recursos existentes mediante importaciones declarativas

**Estado:** implementada en configuración; estado remoto pendiente de comprobación.
**Fuente:** [inventario de staging](INFRAESTRUCTURA_STAGING.md).

Los bloques `import` registran la intención de adoptar recursos existentes, evitando
su recreación deliberada. No garantizan un plan sin cambios: diferencias de atributos,
etiquetas o datos reales pueden proponer actualizaciones, reemplazos o eliminaciones.
Cada plan conectado necesita revisión propia. `prevent_destroy` no impide cambios
en sitio ni protege operaciones externas a Terraform.

## D03 · Mantener el despliegue de aplicaciones fuera de Terraform

**Estado:** implementada. **Fuente:** [ecs.tf](../environments/staging/ecs.tf).

Los servicios conservan `ignore_changes` sobre `task_definition` y `desired_count`.
El pipeline de aplicación gestiona revisiones y escala sin que Terraform las revierta.
Esto reduce conflictos entre herramientas, pero también limita el drift que Terraform
corrige en esos atributos. Cambiar esa frontera requiere coordinar ambos pipelines.

## D04 · Tratar el estado y los planes como material privado

**Estado:** implementada en configuración y manejo de archivos; backend real por verificar.
**Fuente:** [operación](OPERACION_TERRAFORM.md) y [SECURITY](../SECURITY.md).

El backend S3 declara cifrado y bloqueo nativo con `use_lockfile`. El bootstrap añade
versionado y política TLS. CI publica resúmenes depurados y elimina archivos temporales;
no sube planes ni logs completos. La privacidad depende también de permisos, accesos,
retención y limpieza del entorno. Un atributo `sensitive` no elimina su valor del estado.

## D05 · Separar validación, plan y apply

**Estado:** implementada y validada en CI; operaciones conectadas bloqueadas.
**Fuente:** [workflows y permisos](CI_TERRAFORM.md).

PR y push solo validan. Los workflows manuales revalidan sin secretos antes de acceder
al rol de operación; plan y apply usan nombres de rol separados y comparten exclusión
mutua. Apply exige entorno y confirmación, además de habilitación explícita.
Las protecciones del entorno no se crean desde YAML: su aplicación sigue pendiente.
La aprobación sucede antes de generar el plan de apply; no equivale a revisar ese
binario antes de ejecutarlo. Esta limitación debe resolverse en el acuerdo operativo.

## D06 · Fijar dependencias y actualizarlas mediante PR

**Estado:** implementada. **Fuente:** [CI](CI_TERRAFORM.md) y
[Dependabot](../.github/dependabot.yml).

Las Actions se fijan por SHA y las herramientas directas por versión. Los lockfiles
conservan checksums de proveedores para Linux y Windows. Dependabot propone cambios
revisables; no hay automerge. Esto reduce cambios implícitos, pero no sustituye revisar
procedencia, compatibilidad y dependencias transitivas.

## D07 · Extraer módulos cuando exista un beneficio comprobable

**Estado:** criterio de evolución; no hay módulos ejecutables.
**Fuente:** [modules/README.md](../modules/README.md).

Las raíces declaran sus recursos directamente. Se extraerán módulos cuando exista
reutilización o una frontera de mantenimiento útil, conservando direcciones mediante
migraciones revisadas. No se crean módulos vacíos por apariencia ni se mueve estado
como parte de una actualización documental.

## Cómo cambiar una decisión

Proponer un PR con contexto, alternativas, consecuencias y evidencia. Actualizar la
fuente de código y esta guía cuando corresponda. Mantener tareas y responsables en
issues; la documentación no cambia el backlog ni autoriza infraestructura.
