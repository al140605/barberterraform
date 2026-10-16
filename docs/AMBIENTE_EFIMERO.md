# Ambiente efímero de prueba (T032)

Un ambiente **desechable** para comprobar el ciclo completo *crear → verificar → destruir* con Terraform sin tocar
staging. Vive en `environments/ephemeral/` y cada ambiente es un **workspace** de Terraform.

## Por qué existe una raíz aparte

`environments/staging` describe recursos reales con nombres fijos (`urbanblade-staging`, `urbanblade/barber`, ...) y
todos llevan `prevent_destroy`. Reutilizarlo para un ambiente de prueba chocaría con esos nombres y `terraform destroy`
fallaría. Por eso el efímero:

- toma su nombre del workspace, que **debe empezar por `eph-`** (`eph-t032`); con `default` o cualquier otro nombre no
  se crea nada (guarda `terraform_data.guard`, de la que dependen todos los recursos);
- no usa `prevent_destroy` y el ECR lleva `force_delete`, de modo que `destroy` pueda borrarlo todo;
- guarda su estado en `env:/<workspace>/ephemeral/terraform.tfstate` del bucket de estado, sin mezclarse con staging;
- no incluye ALB, NAT ni secretos (cuestan dinero o se retienen al borrarse).

## Qué crea (4 recursos, sin costo mientras no corran tareas)

| Recurso | Nombre |
| --- | --- |
| `terraform_data.guard` | validación del workspace (local, no existe en AWS) |
| `aws_ecr_repository.ephemeral` | `urbanblade-ephemeral/<workspace>` (inmutable, con escaneo, cifrado KMS) |
| `aws_cloudwatch_log_group.ephemeral` | `/ecs/urbanblade-<workspace>/app` (7 días) |
| `aws_ecs_cluster.ephemeral` | `urbanblade-<workspace>` (sin servicios ni tareas) |

Opcional, con `create_security_group = true`: `aws_security_group.ephemeral` (`urbanblade-<workspace>-tasks`, sin
entrada). **Requiere el permiso `ec2:CreateTags`**, porque `default_tags` etiqueta el grupo; el usuario `staging-deploy`
no lo tiene y la creación falla con `403 UnauthorizedOperation` (ver "Resultado de la ejecución"). Por eso es `false`
por defecto.

Todo lleva las etiquetas `Environment=<workspace>`, `Ephemeral=true` y `ManagedBy=Terraform`.

## Procedimiento

Requiere credenciales AWS de la cuenta `209479293733`. **`apply` y `destroy` solo con la orden explícita del
propietario y el plan revisado.** Desde la raíz del repositorio (PowerShell):

```powershell
cd environments/ephemeral
Copy-Item terraform.tfvars.example terraform.tfvars
```

**Estado.** El diseño usa el bucket de estado (`backend.hcl.example`), pero ese bucket lo crea `bootstrap/state` y a
la fecha **aún no existe** en la cuenta. Mientras no se aplique el bootstrap, usar estado local con un archivo de
sustitución que git ignora (`*_override.tf`):

```powershell
Set-Content backend_override.tf 'terraform { backend "local" {} }'
terraform init
```

Con el bucket ya creado: `Copy-Item backend.hcl.example backend.hcl` (poner el ID de cuenta) y
`terraform init -backend-config=backend.hcl`.

```powershell
terraform workspace new eph-t032

# 1) Plan: debe decir "Plan: 4 to add, 0 to change, 0 to destroy" con nombres que contengan eph-t032.
terraform plan -out eph.tfplan
# 2) Crear (aplica el plan guardado, nunca apply a ciegas)
terraform apply eph.tfplan
terraform output
```

### Verificar que existe (solo lectura)

```powershell
aws ecr describe-repositories --repository-names urbanblade-ephemeral/eph-t032 --region us-east-1
aws ecs describe-clusters --clusters urbanblade-eph-t032 --region us-east-1 --query 'clusters[0].status'
aws logs describe-log-groups --log-group-name-prefix /ecs/urbanblade-eph-t032/ --region us-east-1
```

En Git Bash exportar antes `MSYS_NO_PATHCONV=1`; si no, reescribe `/ecs/...` como una ruta de Windows y AWS rechaza el
prefijo. En PowerShell no hace falta.

### Destruir y comprobar que no queda nada

```powershell
# 3) El plan de destrucción debe decir "0 to add, 0 to change, 4 to destroy" y solo mencionar recursos eph-t032.
terraform plan -destroy -out eph-destroy.tfplan
terraform apply eph-destroy.tfplan

# 4) Verificación (ver nota sobre ECS):
aws ecr describe-repositories --repository-names urbanblade-ephemeral/eph-t032 --region us-east-1   # RepositoryNotFoundException
aws logs describe-log-groups --log-group-name-prefix /ecs/urbanblade-eph-t032/ --region us-east-1    # lista vacía
aws ecs describe-clusters --clusters urbanblade-eph-t032 --region us-east-1 --query 'clusters[0].status'  # INACTIVE
terraform state list                                                                                  # solo data sources

# 5) Limpiar el workspace y los archivos locales
terraform workspace select default
terraform workspace delete eph-t032
Remove-Item eph.tfplan, eph-destroy.tfplan, backend_override.tf
```

**Nota sobre ECS:** AWS conserva un tiempo los clústeres borrados con estado `INACTIVE`, y por eso el barrido por
etiqueta (`aws resourcegroupstaggingapi get-resources --tag-filters Key=Environment,Values=eph-t032`) sigue
listándolo. No es un resto: no cobra ni se puede usar, y un clúster nuevo con el mismo nombre se puede crear.

## Criterio de aceptación de T032

1. El plan inicial crea **exactamente 4** recursos, con nombres `eph-t032`, y no toca nada existente.
2. `destroy` elimina exactamente esos 4 recursos; ECR y logs desaparecen, ECS queda `INACTIVE` y el estado queda vacío.
3. Con el workspace `default` el plan **falla** con el mensaje de la guarda. Se comprueba con `terraform plan` real y,
   sin credenciales de AWS, con `terraform -chdir=environments/ephemeral test` (proveedor simulado). La prueba solo es
   válida con el workspace `default` seleccionado.
4. Staging no cambia: este ambiente tiene su propia raíz y su propio estado.

## Resultado de la ejecución (2026-10-16)

| Intento | Resultado |
| --- | --- |
| 1 (con grupo de seguridad) | `apply` creó 4 de 5. El grupo de seguridad falló con `403`: `staging-deploy` no tiene `ec2:CreateTags`. Se destruyó lo creado y se comprobó que no quedaban restos. |
| 2 (`create_security_group = false`) | Plan `4 to add`; `apply` creó los 4 y se verificó en AWS (ECR inmutable con escaneo y KMS, clúster `ACTIVE` sin servicios ni tareas, logs a 7 días). Plan de destrucción `4 to destroy`; ECR y logs desaparecieron, el clúster quedó `INACTIVE` y `terraform state list` quedó vacío. |
| Guarda | `terraform plan` en `default` falló con el mensaje de la guarda; `terraform test` pasa. |

**Consecuencia probable para staging (no probada):** `default_tags` etiqueta todo. Al importar los grupos de seguridad
(T024) el primer plan propondrá actualizar sus etiquetas, y con `staging-deploy` esa actualización muy probablemente
fallaría por la misma falta de `ec2:CreateTags` (y quizá permisos de etiquetado equivalentes en el ALB). Conviene
revisarlo en el `plan` real antes de aplicar T024: conceder el permiso o importar esos recursos sin `default_tags`.

## Qué no hace

No prueba ECS con servicios, ALB ni secretos. Si más adelante se quiere un ambiente efímero con aplicación completa,
conviene extraer módulos a `modules/` y reutilizarlos desde staging y desde este ambiente.
