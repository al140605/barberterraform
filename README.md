# Terraform de UrbanBlade

Este repositorio gestiona la infraestructura compartida de UrbanBlade:
AWS (ECS/Fargate, ALB, CloudFront, ECR y S3) y MongoDB Atlas. El bootstrap declara
un bucket dedicado al estado; staging declara los repositorios ECR y grupos de logs
existentes con importaciones explicitas. Los demas recursos de staging no se
administran todavia con Terraform; confirmar su alcance antes de incorporarlos.

## Estructura

- `environments/staging/`: configuracion raiz y valores no secretos del staging.
- `bootstrap/state/`: bucket cifrado/versionado para los estados Terraform.
- `modules/`: guia de los modulos previstos; se agregaran al codificar recursos.
- `backend.hcl.example`: backend remoto para el estado de staging.
- `.gitignore`: excluye estado, configuracion local y planes de Terraform.

## Requisitos

- Terraform >= 1.10 (para `use_lockfile` en el backend S3).
- AWS CLI configurado con permisos adecuados para la cuenta `209479293733` en
  `us-east-1`.
- Credenciales de MongoDB Atlas disponibles mediante variables de entorno; nunca
  guardarlas en `.tfvars`, el repositorio ni el estado.

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

Los repositorios ECR se configuran con etiquetas inmutables. Publicar cada version
con una etiqueta unica (por ejemplo, un SHA de commit o numero de version); no
volver a publicar `latest` ni reutilizar una etiqueta ya existente. Antes de aplicar
este cambio a repositorios existentes, revisar el plan y coordinar la actualizacion
de los procesos de despliegue que todavia dependan de etiquetas mutables.

El archivo `backend.hcl.example` usa la clave `staging/terraform.tfstate`; el estado
del bootstrap usa `bootstrap/state.tfstate`, ambos en el mismo bucket.

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

## Estado y secretos

El backend usa bloqueo nativo S3 (`use_lockfile = true`); no requiere una tabla
DynamoDB. Mantener versionado y cifrado del bucket de estado. El estado puede contener
valores sensibles aunque las variables se marquen como `sensitive`; restringir su
lectura y no compartirlo como artefacto.

Los secretos existentes de Secrets Manager se incorporaran sin declarar sus valores
en Terraform. Importar recursos no equivale a importar el valor secreto; evitar
recursos `aws_secretsmanager_secret_version` para secretos gestionados fuera de este
repositorio.