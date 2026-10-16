# Terraform de UrbanBlade

Este repositorio gestiona la infraestructura compartida de UrbanBlade:
AWS (ECS/Fargate, ALB, CloudFront, ECR y S3) y MongoDB Atlas. El bootstrap declara
un bucket dedicado al estado; staging declara los repositorios ECR y grupos de logs
existentes con importaciones explicitas. Los demas recursos de staging no se
administran todavia con Terraform; confirmar su alcance antes de incorporarlos.

## Estructura

- `environments/staging/`: configuracion raiz y valores no secretos del staging.
- `bootstrap/state/`: bucket cifrado/versionado para los estados Terraform.
- `environments/ephemeral/`: ambiente desechable por workspace (`eph-*`) para probar crear y destruir; ver `docs/AMBIENTE_EFIMERO.md`.
- `modules/`: guia de los modulos previstos; se agregaran al codificar recursos.
- `backend.hcl.example`: backend remoto para el estado de staging.
- `.gitignore`: excluye estado, configuracion local y planes de Terraform.

## Requisitos

- Terraform >= 1.10 (para `use_lockfile` en el backend S3).
- AWS CLI configurado con permisos adecuados para la cuenta `209479293733` en
  `us-east-1`.
- Credenciales de MongoDB Atlas, solo cuando se administren recursos de Atlas: las
  lee el proveedor de `MONGODB_ATLAS_PUBLIC_API_KEY` y `MONGODB_ATLAS_PRIVATE_API_KEY`;
  nunca guardarlas en `.tfvars`, el repositorio ni el estado. Hoy no se necesitan.

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

## Importar ECR y logs de staging

Desde `environments/staging`, copiar el ejemplo de variables, configurar
las credenciales Atlas mediante variables de entorno, y luego inicializar el backend:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend-config=../../backend.hcl
terraform validate
terraform plan -out staging.tfplan
```

El primer plan contiene bloques `import` para los tres ECR y tres CloudWatch Log
Groups documentados. Confirmar que importa esos seis recursos sin reemplazos,
eliminaciones ni cambios inesperados antes de aplicar el plan guardado. No aplicar
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

`network.tf` y `alb.tf` describen lo que ya existe y lo **importan**; no crean ni destruyen red:

| Recurso | Cantidad | Importado por |
|---|---|---|
| Grupos de seguridad (3 de CloudFront por puerto, 1 de las tareas, 1 heredado) | 5 | id del grupo |
| Balanceador `urbanblade-staging` | 1 | ARN |
| Target groups (barber, frontend, spark) | 3 | ARN |
| Listeners HTTP (80, 8080, 8501) | 3 | ARN |

La VPC predeterminada, sus subredes y la lista de prefijos de CloudFront solo se leen con `data` sources.
Con estos bloques el primer `plan` suma 12 importaciones nuevas a las 6 de ECR y logs. Debe decir
`will be imported` en todas y no proponer reemplazos (`-/+`) ni eliminaciones: `name` y `description` de un
grupo de seguridad no se pueden cambiar sin reemplazarlo, por eso replican exactamente lo que hay en AWS.
Todos los recursos llevan `prevent_destroy`.

Dos cosas se importan **tal cual** y quedan anotadas como pendientes en el codigo (`#checkov:skip`):
los listeners son HTTP (CloudFront publica el HTTPS y habla HTTP con el origen) y existe un grupo de seguridad
heredado que ya no esta asociado al balanceador pero sigue nombrado en las reglas del grupo de las tareas.
Cambiar cualquiera de las dos es una decision aparte, con su propio PR y plan.


## Validacion local sin AWS

Para comprobar sintaxis y formato sin credenciales ni backend remoto:

```powershell
terraform -chdir=bootstrap/state init -backend=false
terraform -chdir=bootstrap/state validate
terraform -chdir=environments/staging init -backend=false
terraform -chdir=environments/staging validate
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

# Seguridad (config en .checkov.yaml)
checkov --config-file .checkov.yaml
```

Las excepciones de checkov viven en el codigo, junto al recurso, como
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