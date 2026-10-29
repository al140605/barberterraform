# CI: validación y operaciones manuales

El pipeline separa comprobaciones de código, lectura de un plan y aplicación de
infraestructura. Esta guía describe los workflows vigentes; el historial está en
[EVIDENCIAS.md](EVIDENCIAS.md) y los comandos locales en [PRUEBAS.md](PRUEBAS.md).

## Flujos y condiciones

| Workflow | Disparador | Condición para acceder a nube |
| --- | --- | --- |
| [Terraform Validacion](../.github/workflows/terraform.yml) | Todo PR y push a `main`, manual o `workflow_call`. | Nunca recibe secretos ni identidad de nube. |
| [Terraform Plan](../.github/workflows/terraform-plan.yml) | Solo `workflow_dispatch`. | `main`, `TERRAFORM_PLAN=true` y validación aprobada. |
| [Terraform Apply](../.github/workflows/terraform-apply.yml) | Solo `workflow_dispatch`. | `main`, ambas variables en `true`, `confirmar=APLICAR staging`, validación aprobada y entorno `staging-aprobacion`. |

Los workflows conectados llaman primero a validación con `contents:read`, sin
`secrets:inherit`. Solo el job de operación obtiene `id-token:write` y secretos.
No se usa `pull_request_target` ni `workflow_run` para elevar permisos desde un PR.
En ramas distintas de `main`, los jobs conectados quedan omitidos.

Plan y apply usan el grupo común `terraform-staging-operation`, sin cancelar una
operación en curso. La validación tiene otro grupo para no bloquear al workflow
que la llama. Este control de GitHub no sustituye el bloqueo del backend ni impide
una operación iniciada fuera de GitHub.

## Seis checks de validación

Los nombres se conservan para los [payloads de protección](../.github/protections/main-protection.json):

| Check | Comprobación |
| --- | --- |
| `Pruebas del resumen de plan (sin nube)` | 30 casos Python/Bash con datos sintéticos y Terraform ficticio en Linux. |
| `terraform fmt` | Formato de las configuraciones. |
| `terraform validate (bootstrap/state)` | Init sin backend, lockfile de solo lectura y validate. |
| `terraform validate (environments/staging)` | Mismos controles en staging. |
| `terraform validate (environments/ephemeral)` | Mismos controles y prueba mock que rechaza workspace default. |
| `tflint y checkov` | Análisis estático; errores de tflint y controles Checkov no exceptuados. |

No se filtran rutas en PR o push a `main`. Los checks obligatorios no deben quedar
pendientes porque solo cambió Markdown. Revisar el SHA exacto y todos los resultados;
una ejecución antigua o una validación local no satisface la evidencia de otro commit.

## Herramientas y dependencias

| Componente | Versión configurada | Fuente |
| --- | --- | --- |
| Runner | Ubuntu 24.04 | `runs-on` en los workflows. |
| Terraform CLI | 1.16.2 | `TF_VERSION`; wrapper desactivado. |
| Python | 3.12 | Action setup-python. |
| tflint / plugin AWS | 0.65.0 / 0.38.0 | Workflow y [.tflint.hcl](../.tflint.hcl). |
| Checkov | 3.4.0 | [requirements-security.txt](../.github/requirements-security.txt). |
| PyYAML para pruebas | 6.0.3 | [requirements-tests.txt](../.github/requirements-tests.txt). |

Las cinco Actions externas usan SHA de commits de releases verificadas. Sus
comentarios de versión facilitan revisión; la referencia ejecutable es el SHA.
Dependabot propone actualizaciones semanales de `github-actions` y `pip` en
[.github/dependabot.yml](../.github/dependabot.yml), con máximo tres PR abiertos
por ecosistema. No hay automerge ni activación de operaciones por actualizar dependencias.
Los manifiestos Python fijan dependencias directas, no un lock completo de transitivas.

Para añadir una plataforma de proveedor, ejecutar `terraform providers lock` desde
la raíz correspondiente, con `-platform=linux_amd64 -platform=windows_amd64`.
Revisar que no cambien versiones ni constraints. No borrar el lockfile, editar
hashes a mano, desactivar verificación o usar `init -upgrade` para ocultar un fallo.
Si se usa un mirror, contrastar los ZIP con checksums oficiales antes de confiar en ellos.

## Configuración operativa privada

| Nombre | Alcance |
| --- | --- |
| `AWS_PLAN_ROLE_ARN` | Rol de lectura de recursos y permisos necesarios para bloquear el backend durante plan. |
| `AWS_APPLY_ROLE_ARN` | Rol de aplicación; permisos y confianza deben revisarse separadamente. |
| `TF_BACKEND_HCL` | Configuración privada del backend de staging. |
| `TF_VAR_AWS_ACCOUNT_ID` | Cuenta esperada por el proveedor. |
| `TF_VAR_ATLAS_PROJECT_ID`, `TF_VAR_ATLAS_CLUSTER_NAME` | Identidad del proyecto y clúster de Atlas. |
| `MONGODB_ATLAS_PUBLIC_API_KEY`, `MONGODB_ATLAS_PRIVATE_API_KEY` | Acceso API de Atlas compatible con la operación autorizada. |

El job verifica presencia de configuración sin imprimir valores. Tener un nombre
de secreto correcto no demuestra que su valor, rol o permisos sean adecuados.
No configurar credenciales para validar documentos ni publicarlas en issues.

### Confianza OIDC y aprobación

La confianza debe limitar repositorio y contexto. Con subjects basados en nombres,
plan usa `repo:al140605/barberterraform:ref:refs/heads/main`; apply usa
`repo:al140605/barberterraform:environment:staging-aprobacion`.
Son ejemplos, no una política IAM aplicada. Los subjects inmutables o personalizados
pueden incluir IDs y otra estructura: comprobar el formato real antes de configurar IAM.
No ampliar a comodines para resolver un rechazo.

El propietario debe aplicar revisores, prevención de autoaprobación, sin bypass y
solo `main` al entorno. Nombrarlo en YAML no configura esas reglas. Ver
[PROTECCIONES_GITHUB.md](PROTECCIONES_GITHUB.md).

Apply espera aprobación **antes de generar su plan** y aplica exactamente el archivo
que acaba de generar. No reutiliza el plan del otro workflow y esa aprobación no
acredita revisión humana previa del binario concreto. Acordar el procedimiento de
revisión privada antes de habilitar `TERRAFORM_APPLY`.

## Planes, logs y resúmenes

[terraform_operation.sh](../scripts/terraform_operation.sh) centraliza init, plan,
resumen y apply opcional. Usa `mktemp`, `umask 077`, `-lockfile=readonly` y un trap de
limpieza. Códigos de plan 0 y 2 son satisfactorios; cualquier otro detiene la operación.
Errores de init, plan, lectura del JSON, resumen o apply no publican el log completo.

Backend temporal, plan, JSON y logs no se suben como artefactos. El trap elimina
archivos al terminar; una terminación abrupta no garantiza su ejecución. Los jobs
usan runners hospedados efímeros. Un runner persistente necesita aislamiento y
limpieza adicionales antes de considerarse compatible.

[summarize_plan.py](../scripts/summarize_plan.py) publica en `GITHUB_STEP_SUMMARY`
acciones por recurso, importaciones aunque sean no-op, reemplazos, retiros del
estado, cambios de outputs, drift y planes incompletos. Omite atributos, valores,
IDs de importación y claves string de instancia; escapa metadatos y rechaza formatos
no soportados. Las direcciones estructurales siguen visibles: no usar secretos como
nombres de módulos o recursos. El resumen no sustituye una revisión privada completa.

## Evidencia y pendientes

La revisión del 29-oct-2026 mantiene ambas variables operativas en `false`, cero
entornos configurados y los issues [#13](https://github.com/al140605/barberterraform/issues/13)
y [#14](https://github.com/al140605/barberterraform/issues/14) abiertos.
La validación está implementada y tiene [evidencia remota](EVIDENCIAS.md); plan,
protecciones y funcionamiento de AWS/Atlas necesitan sus propias comprobaciones.
La documentación no cierra tareas del backlog.

## Referencias

[Reutilizar workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) ·
[OIDC con AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws) ·
[Dependabot para Actions](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-on-actions) ·
[Checksums multiplataforma](https://developer.hashicorp.com/terraform/cli/commands/providers/lock).
