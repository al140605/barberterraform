# Pipeline Terraform · T137 y T138

Sprint 4: 26 de octubre a 6 de noviembre de 2026.
Fuente de implementación: [.github/workflows/terraform.yml](../.github/workflows/terraform.yml).

| Tarea | Responsable según el backlog | Alcance |
| --- | --- | --- |
| T137 | María Isabel Cruz Flores | Formato y validación automática de las tres raíces. |
| T138 | Alan Ruiz Vilchis | Plan de staging y resumen disponible para revisión. |

Esta guía no cambia asignaciones ni marca tareas como completadas.
Los estados del Excel se actualizan únicamente con evidencia del entorno correspondiente.

## Modos de ejecución

| Contexto | Sin credenciales | Plan con credenciales | Apply |
| --- | --- | --- | --- |
| PR hacia main con archivos relevantes | Formato, validate, tflint, Checkov y pruebas del resumen. | No, aunque el PR proceda del mismo repositorio. | No. |
| Push de infraestructura/pipeline revisado a main | Mismos controles. | Solo con TERRAFORM_PLAN=true y configuración completa. | No. |
| Ejecución manual desde main | Mismos controles. | Mismas condiciones. | El mecanismo existente requiere marcar aplicar y el entorno staging-aprobacion. |
| Rama diferente de main | La validación depende del evento de PR. | No. | No. |

Los PR son una superficie de código todavía no revisado: no reciben secretos del plan.
El plan remoto se ejecuta sobre main después de revisar el cambio.
Si se necesita un plan previo a fusionar, debe diseñarse un flujo protegido y de mínimo
privilegio; no basta con comprobar que el PR pertenezca al mismo repositorio.

El apply existente corresponde a un alcance operativo distinto. La presencia de un
environment en YAML no prueba que sus revisores estén configurados en GitHub.

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

El job solo puede ejecutarse desde main, tras superar los controles previos y con
TERRAFORM_PLAN=true. Requiere los nombres siguientes; no se documentan valores:

- AWS_ROLE_ARN y TF_BACKEND_HCL.
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
python -B -m unittest discover -s tests -v
terraform fmt -check -recursive
```

La suite del resumen usa JSON sintético y no requiere proveedores ni credenciales.
Para validate y terraform test, inicializar un directorio de datos local aislado con
backend desactivado y los proveedores de las versiones del lockfile. No reutilizar
la configuración o estado de un directorio operativo.

En una revisión local hay que retirar las credenciales heredadas del proceso,
desactivar metadatos de instancia y aislar la configuración de AWS.
Los comandos de prueba no autorizan un plan conectado, import, apply o destroy.

## Evidencia y pendientes operativos

Revisión del 28 de octubre de 2026:

- El workflow remoto figura disabled_manually.
- GitHub devolvió cero secretos de Actions y cero variables del repositorio.
- No se activó el workflow ni se configuraron secretos, OIDC, entornos o recursos.
- GitHub devolvió cero entornos; staging-aprobacion y sus revisores no están configurados.
  El propietario debe establecerlos antes de considerar cualquier apply.
- Las validaciones locales no demuestran que un plan real pueda leer AWS/Atlas
  ni que la infraestructura ya esté importada en el estado.

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
