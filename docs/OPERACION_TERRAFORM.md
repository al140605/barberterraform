# Operación de Terraform: estado y staging

Procedimientos para una intervención **autorizada**. Leer primero la
[arquitectura](INFRAESTRUCTURA_STAGING.md), las [decisiones](DECISIONES_ARQUITECTURA.md)
y las [protecciones](PROTECCIONES_GITHUB.md). Una revisión documental no ejecuta
estos pasos ni concede permisos sobre AWS/Atlas.

## Antes de comenzar

1. Registrar tarea, responsable, revisor, commit, ventana y alcance autorizado.
2. Usar un checkout operativo dedicado, limpio y con Terraform 1.16.2 y lockfiles
   versionados. No compartir `.terraform` con el checkout de validación.
3. Verificar identidad con `aws sts get-caller-identity`, cuenta esperada, región,
   workspace y ubicación del estado. Comparar con las variables y backend acordados.
4. Comprobar existencia del bucket y del estado por medios autorizados. Un error
   de permisos no demuestra que un recurso no exista; no crear un duplicado para resolverlo.
5. Preparar respaldo privado del estado si ya existe y confirmar quién puede
   recuperarlo. No publicar el respaldo, plan, JSON ni logs en GitHub.
6. Detenerse si hay operaciones concurrentes, identidad incierta, backend inesperado
   o falta de revisión. No usar `-lock=false`, `force-unlock` ni borrar `.terraform`
   para superar un bloqueo sin investigar su causa.

## Ubicación del estado

| Raíz | Configuración de ejemplo | Clave prevista |
| --- | --- | --- |
| Bootstrap | [bootstrap/state/backend.hcl.example](../bootstrap/state/backend.hcl.example) | `bootstrap/state.tfstate` |
| Staging | [backend.hcl.example](../backend.hcl.example) | `staging/terraform.tfstate` |
| Efímero | [environments/ephemeral/backend.hcl.example](../environments/ephemeral/backend.hcl.example) | `env:/<workspace>/ephemeral/terraform.tfstate` para workspaces no default. |

El bucket se acuerda y comprueba; los ejemplos no acreditan su existencia. El bloqueo
S3 usa `use_lockfile=true`. Lectura de recursos y permisos del backend son ámbitos
distintos: generar un plan puede necesitar escribir y retirar el archivo de bloqueo.

## Bootstrap de un bucket nuevo

Usar esta sección solo si se confirmó que el bucket y el estado de bootstrap no
existen y se autorizó crearlos. Si ya existen, preparar su adopción o consultar su
estado; no volver a aplicar un bootstrap vacío.

La raíz declara backend S3. Para la primera creación necesita un backend local
realmente inicializado: `init -backend=false` sirve para validate, pero no inicializa
el backend necesario para plan/apply. En un directorio nuevo, sin estado previo,
se puede usar un override local explícito, ignorado por Git.

Desde `bootstrap/state`, comprobar que no existe otro `backend_override.tf` antes
de crear uno; no sobrescribir configuración ajena:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
# Revisar aws_account_id y state_bucket_name antes de continuar.
Set-Content -LiteralPath backend_override.tf -Value 'terraform { backend "local" {} }'
terraform init -input=false -lockfile=readonly
terraform plan -out=bootstrap.tfplan
```

El plan esperado contiene cinco recursos: bucket, bloqueo de acceso público,
versionado, cifrado AES256 y política que exige TLS. No debe proponer recursos
ajenos, reemplazos ni eliminaciones. Con revisión y autorización registradas:

```powershell
terraform apply bootstrap.tfplan
```

Conservar el estado local y una copia privada verificada. Si la aplicación falla
parcialmente, conservar el estado y revisar el entorno; no repetirla a ciegas.

### Migrar el estado del bootstrap a S3

Comprobar bucket, cifrado, versionado, permisos y destino antes de retirar el override.
Copiar y revisar el ejemplo de backend. Mantener un respaldo privado fuera del
checkout y no eliminar el estado local mientras la migración no esté comprobada.

```powershell
Copy-Item backend.hcl.example backend.hcl
# Revisar bucket, key, region, encrypt y use_lockfile.
Remove-Item -LiteralPath backend_override.tf
terraform init -migrate-state -backend-config=backend.hcl -lockfile=readonly
```

La migración puede pedir confirmación. Revisar cada origen y destino; no usar
`-force-copy` ni sustituir por `-reconfigure` para silenciar preguntas.
Después comprobar ubicación, workspace y lista de recursos del estado esperado.
Acordar la conservación o eliminación privada de copias locales después de verificar
recuperación; no incluirlas en Git ni en artefactos de CI.

## Preparar la adopción de staging

Desde la raíz del repositorio, copiar y revisar los ejemplos sin sobrescribir
archivos existentes:

```powershell
Copy-Item backend.hcl.example backend.hcl
Copy-Item environments/staging/terraform.tfvars.example environments/staging/terraform.tfvars
```

Completar valores de cuenta y Atlas por el canal acordado. Las credenciales de AWS
y las llaves API de Atlas provienen del entorno o gestor autorizado; no se escriben
en `.tfvars`, ejemplos o documentación. El proveedor de Atlas se usa porque ya hay
recursos declarados, aunque un comentario antiguo de providers.tf sugiera lo contrario.

```powershell
terraform -chdir=environments/staging init -input=false -lockfile=readonly -backend-config=../../backend.hcl
terraform -chdir=environments/staging workspace show
terraform -chdir=environments/staging validate
terraform -chdir=environments/staging plan -out=staging.tfplan
```

La raíz contempla **45 importaciones declaradas**. El número pendiente depende del
estado real; un recurso incorporado puede no aparecer como nueva importación.
Revisar la raíz completa, no asumir que el plan se limita a ECR y logs.

### Criterios para revisar el plan

| Área | Qué comprobar antes de considerar apply |
| --- | --- |
| ECR y logs | Identidad de los tres repositorios y tres grupos; conservar compatibilidad de etiquetas y retención. |
| Red y ALB | VPC y subredes esperadas; sin reemplazos o eliminación de grupos, listeners y target groups. |
| ECS | Clúster y dos servicios correctos; respetar la frontera con despliegue y escala de aplicaciones. |
| Secretos | Solo contenedores de Secrets Manager; nunca versiones con valores de secretos. |
| CloudFront y S3 | Distribuciones, orígenes y buckets correctos; conservar separación de uploads públicos y recibos privados. |
| Atlas | Clúster y cuatro usuarios esperados, sin crear duplicados, rotar contraseñas o cambiar privilegios inadvertidamente. |
| Todo el plan | Revisar importaciones, actualizaciones, reemplazos, eliminaciones, outputs, drift y etiquetas del proveedor. |

Detenerse ante acciones fuera del alcance, diferencias sin explicar o sustituciones
sobre recursos con datos. `prevent_destroy` ayuda con eliminación/reemplazo mientras
la declaración existe, pero no bloquea actualizaciones en sitio ni acceso externo.

Las etiquetas `Project`, `Environment` y `ManagedBy` pueden introducir cambios en
sitio durante la adopción. Deben identificarse y aprobarse expresamente; no son
un detalle que se ignore por tratarse de una importación.

## Aplicación autorizada

El plan local se conserva privadamente y solo se aplica tras su revisión específica:

```powershell
terraform -chdir=environments/staging apply staging.tfplan
```

No mezclar este procedimiento con el workflow manual: `Terraform Apply` genera su
propio plan después de la aprobación del entorno. No aplica el binario de otra
ejecución. Esa diferencia y sus requisitos se explican en [CI](CI_TERRAFORM.md).

## Verificación y recuperación

Registrar commit, identidad, backend/workspace, resultado y responsable. Comprobar
recursos esperados, estado actualizado y funcionamiento por el equipo competente.
El mensaje de apply no acredita por sí solo salud de aplicaciones o integridad de datos.

Ante un fallo parcial, detener la concurrencia y conservar estado y evidencia privada.
Identificar qué se aplicó realmente antes de proponer una corrección. Un `git revert`
solo cambia código; no revierte automáticamente AWS, Atlas ni estado. Restaurar una
versión de estado exige verificar correspondencia con recursos actuales y una
intervención aparte. No usar `destroy` como mecanismo de rollback de staging.

## Referencias

- [Terraform init y migración](https://developer.hashicorp.com/terraform/cli/commands/init).
- [Backend y configuración parcial](https://developer.hashicorp.com/terraform/language/backend).
- [Archivos override](https://developer.hashicorp.com/terraform/language/files/override).
- [Ambiente efímero y retirada controlada](AMBIENTE_EFIMERO.md).
