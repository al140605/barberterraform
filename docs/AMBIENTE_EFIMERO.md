# Ambiente efímero de prueba

Raíz: [environments/ephemeral](../environments/ephemeral). Permite comprobar un ciclo
crear → verificar → retirar sobre recursos desechables, con nombres y estado separados
de staging. El procedimiento conectado exige autorización para creación **y retirada**.
La prueba mock de CI no requiere ninguna de esas operaciones.

## Alcance y aislamiento

El nombre proviene del workspace y debe cumplir `^eph-[a-z0-9][a-z0-9-]{1,18}$`.
La guarda `terraform_data.guard` rechaza `default` y los nombres incompatibles;
todos los recursos creados dependen de ella. Esto no evita lecturas de data sources
ni sustituye comprobar cuenta, backend y permisos.

| Recurso por defecto | Configuración |
| --- | --- |
| `terraform_data.guard` | Guarda local del workspace; no es un recurso AWS. |
| ECR | `urbanblade-ephemeral/<workspace>`, inmutable, escaneo, cifrado KMS y `force_delete=true`. |
| CloudWatch Log Group | `/ecs/urbanblade-<workspace>/app`, retención de siete días. |
| Clúster ECS | `urbanblade-<workspace>`, sin servicios ni tareas. |

Por defecto hay **cuatro recursos Terraform**, tres de ellos AWS.
`create_security_group=true` añade un quinto: grupo sin entrada y con salida HTTPS.
La configuración consulta la VPC predeterminada; incluso sin crear el grupo necesita
permisos de lectura de datos de red.

Las etiquetas AWS incluyen `Project`, `Environment=<workspace>`, `Ephemeral=true` y
`ManagedBy=Terraform`. No se incluyen ALB, NAT, secretos ni una aplicación desplegada.
No se presupone costo cero: revisar presupuesto, almacenamiento, imágenes y consumo
antes de crear o prolongar un entorno. ECR puede eliminar imágenes al retirarlo.

## Prueba sin credenciales

Seguir [PRUEBAS.md](PRUEBAS.md) para inicializar sin backend y ejecutar la prueba
mock desde un checkout de revisión con workspace `default`. Esta prueba verifica
la guarda; no crea recursos ni certifica el ciclo de vida en AWS.

## Preparación para un ciclo conectado

1. Registrar responsable, cuenta, nombre único `eph-*`, backend, presupuesto y
   autorización explícita para crear y retirar sus recursos.
2. Usar un checkout operativo dedicado y comprobar identidad AWS, región y permisos.
   No reutilizar estado o directorios de staging.
3. Revisar el backend real. No asumir que el bucket existe o falta por una nota
   antigua; comprobarlo con acceso autorizado.
4. Mantener `create_security_group=false` salvo que se haya autorizado el quinto
   recurso y sus permisos, incluido `ec2:CreateTags`.

Los antecedentes de permisos del 16-oct-2026 están en [EVIDENCIAS.md](EVIDENCIAS.md).
No prueban que la identidad actual tenga las mismas restricciones.

Desde `environments/ephemeral`, sin archivos locales previos que se vayan a sobrescribir:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
Copy-Item backend.hcl.example backend.hcl
# Revisar variables y bucket; la clave debe seguir siendo ephemeral/terraform.tfstate.
terraform init -input=false -lockfile=readonly -backend-config=backend.hcl
terraform workspace new eph-t032
terraform workspace show
```

Usar un nombre de prueba único si `eph-t032` ya existe; no seleccionar un workspace
ajeno ni asumir que está vacío. En S3, un workspace no default usa por defecto
`env:/<workspace>/ephemeral/terraform.tfstate`.

### Alternativa local, solo cuando esté acordada

Para un ensayo nuevo, sin estado previo ni backend inicializado, se puede acordar
un backend local mediante un override ignorado por Git. Confirmar que el archivo
no existe antes de crearlo:

```powershell
Set-Content -LiteralPath backend_override.tf -Value 'terraform { backend "local" {} }'
terraform init -input=false -lockfile=readonly
terraform workspace new eph-t032
```

Con backend local, los estados de workspaces no default viven en
`terraform.tfstate.d/<workspace>/terraform.tfstate`. No moverlos a S3 ni cambiar el
backend de un entorno existente como parte de este procedimiento. Su custodia y
recuperación se acuerdan antes de crear recursos.

## Plan y creación autorizada

```powershell
terraform plan -out=eph.tfplan
```

Por defecto se esperan cuatro altas Terraform y ninguna modificación/eliminación.
Con el grupo opcional aprobado se esperan cinco. Revisar nombres, cuenta, workspace,
etiquetas y ausencia de recursos de staging. Si el estado ya contiene recursos,
el plan puede ser distinto: investigar y detenerse antes de asumir que es un ensayo nuevo.

Tras revisar el plan y confirmar autorización para ese ciclo:

```powershell
terraform apply eph.tfplan
terraform output
```

## Verificación de solo lectura

Los nombres siguientes corresponden al ejemplo `eph-t032`:

```powershell
aws ecr describe-repositories --repository-names urbanblade-ephemeral/eph-t032 --region us-east-1
aws ecs describe-clusters --clusters urbanblade-eph-t032 --region us-east-1 --query 'clusters[0].status'
aws logs describe-log-groups --log-group-name-prefix /ecs/urbanblade-eph-t032/ --region us-east-1
```

En Git Bash usar `MSYS_NO_PATHCONV=1` para que no se reescriban rutas como `/ecs/...`.
PowerShell no necesita esa variable. Depurar outputs antes de compartir evidencia.

## Retirada autorizada y comprobación

Confirmar de nuevo backend, cuenta y workspace. Esta sección solo retira recursos
del entorno efímero acordado; nunca usarla sobre staging o bootstrap.

```powershell
terraform plan -destroy -out=eph-destroy.tfplan
```

Revisar el plan completo: solo los recursos del workspace propio y el número
correspondiente al estado real. Con los cuatro recursos por defecto se esperan
cuatro retiradas, incluida la guarda local. ECR puede contener imágenes que
`force_delete` eliminará; confirmar que ninguna debe conservarse.

```powershell
terraform apply eph-destroy.tfplan
terraform state list
aws ecr describe-repositories --repository-names urbanblade-ephemeral/eph-t032 --region us-east-1
aws logs describe-log-groups --log-group-name-prefix /ecs/urbanblade-eph-t032/ --region us-east-1
aws ecs describe-clusters --clusters urbanblade-eph-t032 --region us-east-1 --query 'clusters[0].status'
```

Comprobar ausencia de recursos administrados en el estado y de ECR/logs en AWS.
Pueden quedar data sources; no equivalen a recursos pendientes de destrucción.
ECS puede conservar temporalmente un registro `INACTIVE`: contrastarlo con la
respuesta y fallos del servicio, no interpretar por sí sola una etiqueta o nombre
como recurso operativo. Si se creó el grupo opcional, verificar también su retirada.

Solo después de verificar la limpieza y conservar evidencia depurada:

```powershell
terraform workspace select default
terraform workspace delete eph-t032
```

Retirar únicamente planes y override de este ensayo cuando su conservación ya no
sea necesaria, sin borrar estado o backups de otros workspaces. Si hubo un fallo
parcial, conservar el estado y revisar los recursos antes de repetir operaciones.
No forzar la eliminación del workspace para esconder recursos pendientes.

## Criterios de aceptación

- Creación limitada al workspace acordado, con cuatro recursos por defecto o cinco
  si el grupo opcional se autorizó; sin cambios en staging.
- Identidad, backend y plan revisados; verificación real de los recursos previstos.
- Retirada y comprobación de estado y AWS, con evidencia de errores si los hubo.
- Guarda rechaza `default` en prueba mock y no se confunde con creación real exitosa.

El historial previo se conserva en [EVIDENCIAS.md](EVIDENCIAS.md). No acredita una
nueva ejecución ni autorización para repetirla.
