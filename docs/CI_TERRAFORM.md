# Pipeline Terraform · T137 y T138

Sprint 4: 26 de octubre a 6 de noviembre de 2026.
Fuentes: [validación](../.github/workflows/terraform.yml),
[plan](../.github/workflows/terraform-plan.yml) y [apply](../.github/workflows/terraform-apply.yml).

| Tarea | Responsable según el backlog | Alcance |
| --- | --- | --- |
| T137 | María Isabel Cruz Flores | Formato y validación automática de las tres raíces. |
| T138 | Alan Ruiz Vilchis | Plan de staging y resumen disponible para revisión. |

Esta guía no cambia asignaciones ni marca tareas como completadas.
Los estados del Excel se actualizan únicamente con evidencia del entorno correspondiente.

## Modos de ejecución

| Contexto | Sin credenciales | Plan con credenciales | Apply |
| --- | --- | --- | --- |
| Todo PR o push hacia main | Seis controles de validación. | Nunca. | Nunca. |
| Terraform Validacion manual o reutilizable | Mismos controles. | Nunca. | Nunca. |
| Terraform Plan manual desde main | Revalida antes del job conectado. | Solo TERRAFORM_PLAN=true. | Nunca. |
| Terraform Apply manual desde main | Revalida antes del job conectado. | Genera su propio plan local si se habilita la ejecución. | Ambas variables=true, confirmación APLICAR staging y entorno protegido. |
| Rama diferente de main | Validación mediante PR o despacho manual. | No. | No. |

No se usa workflow_run, pull_request_target ni secrets:inherit. Los flujos
conectados tienen únicamente workflow_dispatch; el código sin revisar de un PR
no puede iniciar trabajos con credenciales desde estos workflows.

La presencia de un environment en YAML no prueba que sus revisores estén
configurados. Las protecciones administrativas continúan pendientes del propietario.
Plan y apply no se han ejecutado contra AWS/Atlas durante esta mejora.

## T137: validación aislada

Se conservan las tres raíces:

- bootstrap/state.
- environments/staging.
- environments/ephemeral.

El pipeline ejecuta init con backend=false, input=false y lockfile=readonly antes
de validate. No actualiza proveedores ni accede al estado remoto para validar.

La prueba guard.tftest.hcl usa mock_provider y command=plan para comprobar que
el workspace default se rechaza. Ese plan es sintético; no es un plan de AWS/Atlas.

El analisis fija Python 3.12, tflint 0.65.0 y Checkov 3.4.0, y conserva
las configuraciones existentes del proyecto.
No se añaden exclusiones para ocultar hallazgos.

## T138: plan real y publicación del resultado

El workflow de plan se despacha manualmente desde main, revalida y solo ejecuta su job conectado con
TERRAFORM_PLAN=true. Apply exige además TERRAFORM_APPLY=true. Requiere los nombres siguientes; no se documentan valores:

- AWS_PLAN_ROLE_ARN para plan, AWS_APPLY_ROLE_ARN para apply y TF_BACKEND_HCL.
- TF_VAR_AWS_ACCOUNT_ID, TF_VAR_ATLAS_PROJECT_ID y TF_VAR_ATLAS_CLUSTER_NAME.
- MONGODB_ATLAS_PUBLIC_API_KEY y MONGODB_ATLAS_PRIVATE_API_KEY.

AWS usa OIDC. La confianza y los permisos del rol deben revisarse para el repositorio,
rama y operaciones autorizadas. Con el formato de subject basado en nombres, el sub
del job plan sin environment corresponde a repo:al140605/barberterraform:ref:refs/heads/main;
el de apply con environment corresponde a repo:al140605/barberterraform:environment:staging-aprobacion.
Estos son ejemplos, no una política IAM verificada: repositorios nuevos desde
el 15-jul-2026 o que adoptaron subjects inmutables incluyen IDs de propietario y
repositorio. Verificar formato real y personalizaciones de OIDC antes de configurar el rol. La protección del
entorno debe restringir ramas y revisores; no sustituir condiciones específicas
por comodines para hacer funcionar la autenticación. Un rol de lectura de recursos
también necesita permisos explícitos del backend para su bloqueo; esto no autoriza apply.
Atlas requiere acceso compatible con la lectura del
plan. No se crean o cambian esas cuentas desde este mantenimiento.

El job valida la presencia de configuración sin imprimir valores.
Los códigos de salida 0 y 2 de terraform plan son satisfactorios; 1 indica error.
No se publica el log completo, tampoco en caso de fallo.

Backend temporal, plan binario, JSON y logs se guardan con permisos restringidos
en RUNNER_TEMP, no se suben como artefactos y se limpian al finalizar el job.
La revisión pública usa únicamente GITHUB_STEP_SUMMARY.

## Resumen seguro y fiel al plan

[summarize_plan.py](../scripts/summarize_plan.py) lee el JSON de Terraform por stdin:

- Muestra acciones por recurso, incluidos reemplazos y retiros del estado.
- Incluye importaciones aunque las acciones del recurso sean no-op.
- Cuenta cambios de outputs sin mostrar sus nombres o valores.
- Cuenta recursos con drift y señala planes incompletos.
- Omite valores before/after, IDs de importación y claves de instancia de tipo string.
- Escapa metadatos para evitar que formen nuevas filas o HTML en el resumen.
- Rechaza estructuras, versiones mayores o acciones no soportadas; no publica el input inválido.

Las direcciones estructurales de Terraform siguen siendo visibles. No usar secretos
como nombres de recursos, módulos o identificadores en la configuración.
Un resumen no sustituye la revisión privada del plan cuando sea necesaria.

## Pruebas locales sin nube

Desde la raíz del repositorio:

```powershell
python -m pip install -r .github/requirements-tests.txt
python -B -m unittest discover -s tests -v
terraform fmt -check -recursive
```

La suite del resumen usa JSON sintético. Las políticas usan PyYAML fijado en
requirements-tests.txt. Los tests del runner Bash usan Terraform ficticio y solo
se ejecutan en Linux; en Windows quedan omitidos. Ninguna suite necesita nube.
Para validate y terraform test, inicializar un directorio de datos local aislado con
backend desactivado y los proveedores de las versiones del lockfile. No reutilizar
la configuración o estado de un directorio operativo.

En una revisión local hay que retirar las credenciales heredadas del proceso,
desactivar metadatos de instancia y aislar la configuración de AWS.
Los comandos de prueba no autorizan un plan conectado, import, apply o destroy.

## Evidencia y pendientes operativos

Estado inicial observado el 28 de octubre de 2026 (antes de habilitar validaciones):

- El workflow remoto figura disabled_manually.
- GitHub devolvió cero secretos de Actions y cero variables del repositorio.
- No se activó el workflow ni se configuraron secretos, OIDC, entornos o recursos.
- GitHub devolvió cero entornos; staging-aprobacion y sus revisores no están configurados.
  El propietario debe establecerlos antes de considerar cualquier apply.
- Las validaciones locales no demuestran que un plan real pueda leer AWS/Atlas
  ni que la infraestructura ya esté importada en el estado.

### Activación de validación sin nube

El 28-oct-2026 se habilitó el workflow y se fijó TERRAFORM_PLAN=false.
La primera [ejecución remota](https://github.com/al140605/barberterraform/actions/runs/40808978959)
aprobó formato, las 15 pruebas del resumen y tflint/Checkov; validate falló por
checksums de paquetes Linux ausentes en los lockfiles. Plan y apply se omitieron.
Los lockfiles se generaron con providers lock para Linux y Windows en la
[ejecución de diagnóstico](https://github.com/al140605/barberterraform/actions/runs/40809985048),
que aprobó los seis jobs de validación y omitió plan/apply. Se copiaron únicamente
los lockfiles y se comprobó que conservan versiones, constraints y hashes anteriores.
La rama de diagnóstico no forma parte de los PR ni debe fusionarse.
La corrección incorpora hashes de Linux sin actualizar las versiones de proveedores
ni retirar lockfile=readonly. Un resultado fallido permanece como evidencia;
la corrección debe comprobarse en una nueva ejecución del SHA actualizado.

No configurar secretos ni cambiar TERRAFORM_PLAN durante este mantenimiento.
El seguimiento de protecciones y permisos está en [#13](https://github.com/al140605/barberterraform/issues/13)
y el acuerdo de responsables de excepciones en [#14](https://github.com/al140605/barberterraform/issues/14).
Sus asignaciones al propietario son de coordinación; los responsables técnicos y
fechas de ejecución aún requieren acuerdo del equipo.

Por tanto, T137 y T138 no se declaran cerradas solo por editar YAML.
La activación y ejecución remota del plan requieren su revisión operativa.

## Validación local de esta revisión

- Terraform 1.16.2: fmt aprobado y validate aprobado en las tres raíces.
- Inicialización con backend desactivado, lockfile de solo lectura y proveedores
  ya descargados, sin heredar credenciales del proceso.
- Ambiente efímero: una prueba con proveedor mock aprobada, cero fallos.
- Resumen: 15 pruebas unitarias/CLI aprobadas.
- Integración del resumen con un plan local de terraform_data, proveedor incorporado:
  JSON de formato 1.2 aceptado sin mostrar el valor sintético privado. Sin apply.
- actionlint 1.7.12: workflow aprobado; ShellCheck/Pyflakes no se ejecutaron.
- tflint 0.65.0 con el plugin AWS 0.38.0: tres raíces aprobadas.
- Checkov 3.4.0: 80 aprobaciones, cero fallos, 107 exclusiones existentes y cero
  errores de parseo. No se cambiaron configuraciones de exclusión ni archivos .tf.

Esta evidencia es local. No equivale a una ejecución del workflow en GitHub ni
al plan de staging conectado a AWS/Atlas.

## Resto del Sprint 4

| Tarea | Evidencia en código | Pendiente de comprobar |
| --- | --- | --- |
| T124 | ECS y servicios declarados en [ecs.tf](../environments/staging/ecs.tf), con importación y guardas. | Estado remoto, revisión del plan y cualquier despliegue autorizado. |
| T125 | Atlas y usuarios declarados en [atlas.tf](../environments/staging/atlas.tf). | Lectura autorizada, correspondencia con el estado e integridad real de datos. |
| TT14 | [cdn.tf](../environments/staging/cdn.tf) declara redirect-to-https y TLSv1.2_2021. | Coincidencia del plan con CloudFront real y validación del entorno. |
| T126 / TT15 | Requieren verificación de API y clientes contra el entorno acordado. | Evidencia funcional por rol y entorno, sin dar por aprobados pagos o datos reales. |

La existencia del código no acredita importaciones aplicadas ni funcionamiento remoto.

## Fuentes

[Terraform plan](https://developer.hashicorp.com/terraform/cli/commands/plan) ·
[Mocks de proveedores](https://developer.hashicorp.com/terraform/language/tests/mocking) ·
[OIDC en AWS con GitHub Actions](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

La revisión de omisiones y criterios para retirar excepciones está en
[EXCEPCIONES_CHECKOV.md](EXCEPCIONES_CHECKOV.md).

## Mantenimiento de checksums multiplataforma

Conservar las versiones del lockfile al añadir una plataforma. Desde cada raíz,
terraform providers lock -platform=linux_amd64 -platform=windows_amd64 obtiene
paquetes y checksums oficiales sin inicializar el backend ni leer AWS/Atlas.
Revisar que el diff solo agregue hashes y que no cambie version ni constraints.
Si se usa un mirror local, verificar primero los ZIP contra los zh ya registrados;
los hashes del mirror por sí solos no acreditan procedencia oficial.

No editar hashes a mano, borrar el lockfile, usar init -upgrade ni desactivar su
verificación para resolver un fallo. Referencia: [providers lock](https://developer.hashicorp.com/terraform/cli/commands/providers/lock).

Las reglas preparadas, permisos comprobados y responsables de coordinación están en
[PROTECCIONES_GITHUB.md](PROTECCIONES_GITHUB.md). Su aplicación administrativa sigue pendiente.

## Separación de flujos y dependencias (29-oct-2026)

terraform.yml conserva los nombres de los seis checks y se puede llamar sin secretos.
Los flujos manuales reutilizan esa validación con contents:read explícito; solo
su job de operación recibe id-token:write y secretos. Los roles plan/apply tienen
nombres de secreto separados para evitar reutilizar accidentalmente el rol de escritura
al revisar un plan. Los permisos IAM reales aún deben configurarse y comprobarse.

La aprobación del entorno ocurre antes de generar el plan de apply. Ese job aplica
exactamente el plan que acaba de generar; no reutiliza el plan de otro workflow y
no demuestra una revisión humana previa de ese binario. Esta limitación exige
acordar la revisión privada antes de habilitar TERRAFORM_APPLY.

scripts/terraform_operation.sh centraliza init, plan, resumen y apply opcional.
mktemp y umask 077 aíslan los archivos; un trap los limpia en éxitos y errores.
La terminación abrupta del runner no garantiza ejecutar el trap: se usan runners
hospedados efímeros y no se publican los archivos. No usar runners persistentes
sin diseñar su limpieza y aislamiento.

Las Actions se fijan a SHA de releases oficiales verificadas, incluidos sus
entrypoints compilados. setup-terraform 4.0.1, setup-tflint 6.3.2 y
configure-aws-credentials 6.3.0 reemplazan majors anteriores; checkout 7.0.1 y
setup-python 7.1.0 se fijan también por SHA. Sus entradas utilizadas se contrastaron
con action.yml oficial. La autenticación real de AWS no se prueba con mocks.

Dependabot revisa github-actions y pip en /.github semanalmente, con máximo tres
PR abiertos por ecosistema y sin automerge. Las versiones y dependencias transitivas
se revisan con sus PR; los manifiestos fijan dependencias directas, no constituyen
un lock completo con hashes de todo el entorno Python. Una actualización no autoriza nube.

No se versionan credenciales, no se actualizan recursos/proveedores, no se cambian
exclusiones Checkov y las dos variables operativas siguen en false.

Fuentes: [reutilizar workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows),
[Dependabot para Actions](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-on-actions).
