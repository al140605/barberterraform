# Terraform de UrbanBlade

Este repositorio gestiona la infraestructura compartida de UrbanBlade:
AWS (ECS/Fargate, ALB, CloudFront, ECR y S3) y MongoDB Atlas. El bootstrap declara
un bucket dedicado al estado; staging declara ECR, logs, red, ALB, ECS, contenedores
de secretos, CloudFront, S3 y Atlas mediante bloques de importación. Declararlos
no demuestra que estén incorporados al estado remoto ni que coincidan con el entorno.
La evidencia de esta revisión es estática y local; no se ejecutó un plan conectado.

## Estructura

- `environments/staging/`: configuracion raiz y valores no secretos del staging.
- `bootstrap/state/`: bucket cifrado/versionado para los estados Terraform.
- `environments/ephemeral/`: ambiente desechable por workspace (`eph-*`) para probar crear y destruir; ver `docs/AMBIENTE_EFIMERO.md`.
- `modules/`: propuesta de modularización; las raíces actuales aún declaran sus recursos directamente.
- `docs/INFRAESTRUCTURA_STAGING.md`: diagrama, recursos administrados, variables y salidas de staging.
- `backend.hcl.example`: backend remoto para el estado de staging.
- `.gitignore`: excluye estado, configuracion local y planes de Terraform.

## Requisitos

- Terraform >= 1.10 (para `use_lockfile` en el backend S3).
- AWS CLI configurado con permisos adecuados para la cuenta `209479293733` en
  `us-east-1`.
- Credenciales de MongoDB Atlas, solo cuando se administren recursos de Atlas: las
  lee el proveedor de `MONGODB_ATLAS_PUBLIC_API_KEY` y `MONGODB_ATLAS_PRIVATE_API_KEY`;
  nunca guardarlas en `.tfvars` ni en el repositorio. Staging las requiere para el
  plan conectado porque ya declara Atlas; formato, validación y pruebas mock no las requieren.
  Tratar estado y planes como sensibles: pueden contener datos de los proveedores.

## Operaciones con infraestructura

Las secciones siguientes son procedimientos para una intervención autorizada.
No ejecutar bootstrap, migración, importación, apply o destroy como parte de
una revisión documental. Si el bucket o el estado ya existen, comprobar primero
su ubicación y permisos; no repetir el aprovisionamiento.

## Crear el bucket de estado

El bootstrap necesita AWS CLI/credenciales con permisos para S3 y STS. Verificar la
identidad con `aws sts get-caller-identity` y confirmar que sea la cuenta indicada
antes de aplicar. El proveedor AWS tambien limita las operaciones a `aws_account_id`
mediante `allowed_account_ids`; no usar credenciales de otra cuenta.

Desde `bootstrap/state`:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend=false
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Revisar el plan: debe crear solo el bucket de estado, su bloqueo de acceso publico,
versionado, cifrado y politica que exige TLS. El recurso tiene `prevent_destroy`.
Despues de crearlo, migrar el estado local del bootstrap al bucket:

```powershell
Copy-Item backend.hcl.example backend.hcl
terraform init -migrate-state -backend-config=backend.hcl
```

Conservar el archivo `terraform.tfstate` temporal solo hasta confirmar que la
migracion termino. No subirlo ni el plan binario al repositorio.

## Revisar las importaciones de staging

Desde `environments/staging`, copiar el ejemplo de variables, configurar
las credenciales Atlas mediante variables de entorno, y luego inicializar el backend:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend-config=../../backend.hcl
terraform validate
terraform plan -out staging.tfplan
```

La raíz completa incluye las 51 importaciones descritas en
[INFRAESTRUCTURA_STAGING.md](docs/INFRAESTRUCTURA_STAGING.md), incluidas Atlas, red,
ECS, CloudFront y S3. No es un plan limitado a los seis recursos de ECR y logs.
El número de importaciones pendientes depende del estado remoto. Revisar todas las
acciones, cambios de outputs y drift antes de considerar aplicar el plan guardado. No aplicar
si el plan intenta crear duplicados o modificar atributos no previstos.

Los repositorios ECR se declaran con etiquetas **mutables**, que es como estan hoy en
AWS: el despliegue de staging empuja siempre `latest` y las definiciones de tarea de
ECS la usan. Hacerlas inmutables rompe el siguiente `docker push`. El orden correcto es:
publicar cada version con una etiqueta unica (SHA de commit), actualizar las
definiciones de tarea y el flujo de reversion, y solo entonces cambiar
`image_tag_mutability` a `IMMUTABLE` en una rama aparte, revisando su plan.

El archivo `backend.hcl.example` usa la clave `staging/terraform.tfstate`; el estado
del bootstrap usa `bootstrap/state.tfstate`, ambos en el mismo bucket.

## Red y ALB de staging (T024)

`network.tf` y `alb.tf` declaran recursos para adoptar por importación; el plan
real debe confirmar que no propone crear, reemplazar o destruir red:

| Recurso | Cantidad | Importado por |
|---|---|---|
| Grupos de seguridad (3 de CloudFront por puerto, 1 de las tareas, 1 heredado) | 5 | id del grupo |
| Balanceador `urbanblade-staging` | 1 | ARN |
| Target groups (barber, frontend, spark) | 3 | ARN |
| Listeners HTTP (80, 8080, 8501) | 3 | ARN |

La VPC predeterminada, sus subredes y la lista de prefijos de CloudFront solo se leen con `data` sources.
Estos bloques declaran 12 importaciones adicionales a las 6 de ECR y logs. Los
recursos aún no incorporados al estado deben figurar como importaciones; detenerse
si aparecen reemplazos (`-/+`) o eliminaciones: `name` y `description` de un
grupo de seguridad no se pueden cambiar sin reemplazarlo, por eso replican exactamente lo que hay en AWS.
Los recursos de estos dos archivos llevan `prevent_destroy`; esta guarda no impide
cambios en sitio ni operaciones externas a Terraform.

Dos cosas se importan **tal cual** y quedan anotadas como pendientes en el codigo (`#checkov:skip`):
los listeners son HTTP (CloudFront publica el HTTPS y habla HTTP con el origen) y existe un grupo de seguridad
heredado que ya no esta asociado al balanceador pero sigue nombrado en las reglas del grupo de las tareas.
Cambiar cualquiera de las dos es una decision aparte, con su propio PR y plan.


## ECS y secretos de barber (T026)

`ecs.tf` y `secrets.tf` importan lo que ya corre; el despliegue de las aplicaciones sigue siendo del pipeline.

| Recurso | Cantidad | Importado por |
|---|---|---|
| Clúster `urbanblade-staging` y sus proveedores de capacidad (FARGATE, FARGATE_SPOT por defecto) | 2 | nombre del clúster |
| Servicios `uba-stg-barber` y `uba-stg-frontend` | 2 | `clúster/servicio` |
| Secretos `urbanblade/staging/barber/*` (solo el contenedor, nunca el valor) | 12 | ARN |

- Los servicios llevan `ignore_changes = [task_definition, desired_count]`: el pipeline registra revisiones nuevas y
  escala sin que Terraform las revierta. La definicion de tarea no se administra aqui; se lee la ultima revision
  activa de cada familia solo para satisfacer el argumento obligatorio al importar.
- Nunca declarar `aws_secretsmanager_secret_version` para estos secretos: el valor lo gestiona otro proceso y no
  debe pasar por el codigo ni por el estado. Son exactamente los 12 que lee la tarea de barber.
- `spark` y `ollama` (servicios, secretos de spark, ECR y logs de ollama) quedan fuera de este alcance.
- Estos archivos declaran 16 importaciones (clúster, proveedores, 2 servicios y 12 secretos).
  Confirmar cuáles faltan en el estado y detenerse ante reemplazos o eliminaciones.


## CloudFront y S3 (T120)

`cdn.tf` y `storage.tf` declaran la adopción de distribuciones y buckets existentes.
Los comentarios registran una lectura previa de AWS; esta revisión no la repite ni
certifica que esos valores sigan coincidiendo con el entorno.

| Recurso | Cantidad | Importado por |
|---|---|---|
| Distribuciones de CloudFront: `frontend` (urbanblade.com.mx y www), `api` y `spark`, las tres hacia el ALB | 3 | ID de la distribucion |
| Buckets `urbanblade-staging-uploads-*` (publico, solo lectura) y `urbanblade-staging-receipts-*` (privado) | 2 | nombre |
| Cifrado AES256, bloqueo de acceso publico y propiedad de objetos de cada bucket | 6 | nombre del bucket |
| Politica de lectura publica de `uploads` (solo `GetObject`) | 1 | nombre del bucket |

- El certificado ACM se referencia por ARN; no se administra aqui. Las politicas de cache y de solicitud al origen son las
  administradas por AWS (CachingDisabled y AllViewer): nada se cachea en el borde.
- `uploads` tiene el bloqueo de politica publica **apagado a proposito**: sirve imagenes por URL publica. `receipts` lo
  tiene todo bloqueado. No cambiar ninguno sin revisar el plan.
- El bucket de respaldos de la Fase 5 (`urbanblade-backups-*`) queda fuera de este alcance.
- Las etiquetas por defecto del proveedor (`Project`, `Environment`, `ManagedBy`) se agregan en sitio a los 5 recursos
  que las admiten (3 distribuciones y 2 buckets); es un cambio en sitio que debe revisarse además de las
  12 importaciones declaradas (3 distribuciones, 2 buckets, 6 configuraciones de bucket y 1 política). No debe proponer reemplazos ni eliminaciones.
- Falta el `plan` real: depende del estado remoto (T115) y de credenciales con lectura de CloudFront y S3.


## MongoDB Atlas (T118)

`atlas.tf` describe el clúster y los usuarios de base de datos para importarlos. **Esta revisión no ejecuta ni acredita un plan conectado**; su comprobación
requiere los datos reales de Atlas y las credenciales de su API.

| Recurso | Cantidad | Importado por |
|---|---|---|
| Clúster gratuito (M0) sobre AWS | 1 | `<id-proyecto>-<nombre-cluster>` |
| Usuarios `laravel_core_rw`, `laravel_analytics_reader`, `spark_core_reader` y `ANALYTIC` | 4 | `<id-proyecto>-<usuario>-admin` |

Datos que hay que dar (no estan en ningun archivo del repo; van en `terraform.tfvars`, que Git ignora):
`atlas_project_id` (24 caracteres hexadecimales, Project Settings), `atlas_cluster_name` y `atlas_region`
(por defecto `US_EAST_1`; debe coincidir con la real). Credenciales de la API: `MONGODB_ATLAS_PUBLIC_API_KEY` y
`MONGODB_ATLAS_PRIVATE_API_KEY`, de una llave con rol **Project Read Only** mientras solo se haga `plan`.

- Todo lleva `prevent_destroy`. Si la region o el nivel no coinciden con Atlas, el plan debe **fallar**, no proponer
  reemplazar el clúster: en M0 no hay respaldo en la nube y reemplazar es perder los datos.
- Los usuarios llevan `ignore_changes = [password]`. Las contraseñas se gestionan fuera de este código;
  no declararlas aquí ni asumir que la guarda protege cualquier contenido del estado.
- Fuera de alcance: el usuario personal `luis` (excepcion aceptada del propietario) y la lista de acceso de red de
  Atlas. De esta ultima hoy se desconoce el contenido; para incorporarla hay que leerla (`atlas accessLists list`) y
  anadir `mongodbatlas_project_ip_access_list` con sus entradas reales.
- Para adoptar los cinco recursos de Atlas, revisar importaciones pendientes y exigir ausencia de cambios. Cualquier `must be replaced`
  o `will be updated` significa que un valor declarado no coincide: corregir el codigo, nunca aplicar.


## Validacion local sin AWS

Desde un checkout de revisión aislado, sin credenciales heredadas ni configuración
local de backend; no reutilizar un directorio operativo ya inicializado.
Las descargas de proveedores requieren red, pero no acceso a AWS/Atlas:

```powershell
terraform -chdir=bootstrap/state init -backend=false -input=false -lockfile=readonly
terraform -chdir=bootstrap/state validate
terraform -chdir=environments/staging init -backend=false -input=false -lockfile=readonly
terraform -chdir=environments/staging validate
terraform -chdir=environments/ephemeral init -backend=false -input=false -lockfile=readonly
terraform -chdir=environments/ephemeral validate
terraform -chdir=environments/ephemeral test
python -m pip install -r .github/requirements-tests.txt
python -B -m unittest discover -s tests -v
terraform fmt -check -recursive
```

La validacion local no confirma permisos, existencia de recursos ni que el plan de
AWS sea seguro. Eso requiere credenciales y revisar el plan real.

Para validar solo el codigo sin configurar el backend remoto, usar
`terraform init -backend=false` y despues `terraform validate`.

## Analisis estatico (T030)

Dos herramientas, ambas sin credenciales de AWS:

```powershell
# Estilo y errores de Terraform/AWS (config en .tflint.hcl)
tflint --init
tflint --chdir=bootstrap/state --config="$PWD/.tflint.hcl"
tflint --chdir=environments/staging --config="$PWD/.tflint.hcl"
tflint --chdir=environments/ephemeral --config="$PWD/.tflint.hcl"

# Seguridad (config en .checkov.yaml)
checkov --config-file .checkov.yaml
```

El [registro de excepciones](docs/EXCEPCIONES_CHECKOV.md) distingue compatibilidad,
limitaciones de análisis y deuda pendiente. No equivale a una aceptación de riesgos.
Las excepciones de Checkov viven en el código, junto al recurso, como
`#checkov:skip=ID:motivo`. Revisarlas al cambiar el recurso: por ejemplo, las de ECR
(`CKV_AWS_51` etiquetas mutables y `CKV_AWS_136` cifrado KMS) dependen de pasar a etiquetas por SHA y de
poder recrear el repositorio. Los grupos de logs de staging retienen 90 dias; produccion debe retener mas.


## Estado y secretos

El backend usa bloqueo nativo S3 (`use_lockfile = true`); no requiere una tabla
DynamoDB. Mantener versionado y cifrado del bucket de estado. El estado puede contener
valores sensibles aunque las variables se marquen como `sensitive`; restringir su
lectura y no compartirlo como artefacto.

Los secretos existentes de Secrets Manager se incorporaran sin declarar sus valores
en Terraform. Importar recursos no equivale a importar el valor secreto; evitar
recursos `aws_secretsmanager_secret_version` para secretos gestionados fuera de este
repositorio.

## Pipeline (T043 a T046)

Los flujos tienen responsabilidades y permisos separados:

| Workflow | Cuándo corre | Acceso a nube |
| --- | --- | --- |
| [Terraform Validacion](.github/workflows/terraform.yml) | Todo PR y push a main; manual; reutilizable por workflow_call. | Ninguno: token contents:read, sin secretos ni OIDC. |
| [Terraform Plan](.github/workflows/terraform-plan.yml) | Solo manual, desde main, con TERRAFORM_PLAN=true. | Rol AWS de lectura y bloqueo de estado, más lectura de Atlas. |
| [Terraform Apply](.github/workflows/terraform-apply.yml) | Solo manual, desde main, con ambas variables en true y confirmación APLICAR staging. | Rol de aplicación, tras el entorno staging-aprobacion. |

Un push o PR nunca inicia plan ni apply. Los flujos manuales reutilizan primero
las seis validaciones sin heredar secretos y solo después permiten el job conectado.
Se mantienen los seis nombres de checks previstos en la protección de main.

La validación comprueba formato, tres raíces, prueba mock del ambiente efímero,
tflint, Checkov, resumen seguro y políticas del pipeline. Los tests de operaciones
usan un ejecutable Terraform ficticio en Linux; no ejecutan un plan/apply real.

Las Actions externas se fijan a commits completos, con versión legible en comentario,
y usan releases Node 24 verificadas. El runner se fija en ubuntu-24.04. Dependabot
propone actualizaciones semanales de Actions y dependencias Python de CI; no las
fusiona ni cambia permisos automáticamente. Terraform sigue en 1.16.2, tflint en
0.65.0 y Checkov en 3.4.0; no se actualizan proveedores de infraestructura.

Configuración operativa, pendiente de revisión autorizada:

1. Roles separados: AWS_PLAN_ROLE_ARN para plan y AWS_APPLY_ROLE_ARN para apply.
   La cuenta no tiene esos secretos configurados por este mantenimiento. La
   confianza OIDC debe distinguir rama main y entorno staging-aprobacion.
2. TF_BACKEND_HCL, TF_VAR_AWS_ACCOUNT_ID, TF_VAR_ATLAS_PROJECT_ID,
   TF_VAR_ATLAS_CLUSTER_NAME y llaves API de Atlas se gestionan privadamente.
3. Mantener TERRAFORM_PLAN=false y TERRAFORM_APPLY=false. Activarlas requiere
   autorización operativa independiente; preparar YAML no la concede.
4. El propietario debe aplicar revisores, prevención de autoaprobación, sin bypass
   y solo main en staging-aprobacion. Mencionar el entorno en YAML no lo protege.

Plan y apply comparten una exclusión mutua sobre staging. El segundo workflow
vuelve a generar su propio plan después de la aprobación del entorno y aplica
exactamente ese archivo local. Esa aprobación autoriza la ejecución, no acredita
que una persona haya revisado previamente ese plan binario concreto. Antes de
habilitar apply hay que acordar la revisión privada y el procedimiento operativo.
No se intercambian planes ni logs entre workflows mediante artefactos públicos.

El script común usa permisos restrictivos y limpia backend temporal, plan, JSON y
logs en éxitos y fallos. Solo publica un resumen depurado; no imprime valores del
plan ni errores completos. Un fallo puede requerir diagnóstico privado autorizado.

## Sprint 4: validacion y plan revisable

La guia [CI_TERRAFORM.md](docs/CI_TERRAFORM.md) detalla T137 y T138, los contextos
que pueden usar credenciales, el resumen seguro del plan y las evidencias necesarias
para cerrar las tareas. Los PR se validan sin secretos; el plan real requiere main
y habilitacion explicita.

## Documentación de referencia

- [Arquitectura e inventario declarado](docs/INFRAESTRUCTURA_STAGING.md).
- [Validación y plan del Sprint 4](docs/CI_TERRAFORM.md).
- [Excepciones de Checkov y decisiones pendientes](docs/EXCEPCIONES_CHECKOV.md).
- [Ambiente efímero](docs/AMBIENTE_EFIMERO.md).
- [Protecciones de GitHub y responsabilidades](docs/PROTECCIONES_GITHUB.md).

## Políticas y licencia

- [GNU GPLv3, versión 3 únicamente](LICENSE) — GPL-3.0-only.
- [Alcance de la licencia y componentes de terceros](LICENSING.md).
- [Política de seguridad y reporte privado](SECURITY.md).
- [Cómo contribuir](CONTRIBUTING.md).
- [Código de conducta](CODE_OF_CONDUCT.md).
