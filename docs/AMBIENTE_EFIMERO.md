# Ambiente efímero de prueba (T032)

Un ambiente **desechable** para comprobar el ciclo completo *crear → verificar → destruir* con Terraform sin tocar
staging. Vive en `environments/ephemeral/` y cada ambiente es un **workspace** de Terraform.

## Por qué existe una raíz aparte

`environments/staging` describe recursos reales con nombres fijos (`urbanblade-staging`, `urbanblade/barber`, ...) y
todos llevan `prevent_destroy`. Reutilizarlo para un ambiente de prueba chocaría con esos nombres y `terraform destroy`
fallaría. Por eso el efímero:

- toma su nombre del workspace, que **debe empezar por `eph-`** (`eph-t032`); con `default` o cualquier otro nombre no
  se crea nada (guarda `terraform_data.guard`);
- no usa `prevent_destroy` y el ECR lleva `force_delete`, de modo que `destroy` pueda borrarlo todo;
- guarda su estado en el mismo bucket pero en `env:/<workspace>/ephemeral/terraform.tfstate`, sin mezclarse con staging;
- no incluye ALB, NAT ni secretos (cuestan dinero o se retienen al borrarse).

## Qué crea (5 recursos, sin costo mientras no corran tareas)

| Recurso | Nombre |
| --- | --- |
| `terraform_data.guard` | validación del workspace |
| `aws_ecr_repository.ephemeral` | `urbanblade-ephemeral/<workspace>` (inmutable, con escaneo, cifrado KMS) |
| `aws_cloudwatch_log_group.ephemeral` | `/ecs/urbanblade-<workspace>/app` (7 días) |
| `aws_ecs_cluster.ephemeral` | `urbanblade-<workspace>` (sin servicios ni tareas) |
| `aws_security_group.ephemeral` | `urbanblade-<workspace>-tasks` (sin entrada; salida solo 443) |

Todo lleva las etiquetas `Environment=<workspace>`, `Ephemeral=true` y `ManagedBy=Terraform`.

## Procedimiento

Requiere credenciales AWS de la cuenta `209479293733`. **`apply` y `destroy` solo con la orden explícita del
propietario y el plan revisado.** Desde la raíz del repositorio (PowerShell):

```powershell
cd environments/ephemeral
Copy-Item terraform.tfvars.example terraform.tfvars
Copy-Item backend.hcl.example backend.hcl        # editar: poner el ID de la cuenta en el nombre del bucket
terraform init -backend-config=backend.hcl
terraform workspace new eph-t032

# 1) Plan: debe decir "Plan: 5 to add, 0 to change, 0 to destroy" y nada más.
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
aws ec2 describe-security-groups --filters Name=group-name,Values=urbanblade-eph-t032-tasks --region us-east-1
```

### Destruir y comprobar que no queda nada

```powershell
# 3) El plan de destrucción debe decir "Plan: 0 to add, 0 to change, 5 to destroy" y solo mencionar recursos eph-t032.
terraform plan -destroy -out eph-destroy.tfplan
terraform apply eph-destroy.tfplan

# 4) Verificación: ninguno debe aparecer (los describe fallan con "not found" o devuelven listas vacías).
aws resourcegroupstaggingapi get-resources --tag-filters Key=Environment,Values=eph-t032 --region us-east-1 --query 'ResourceTagMappingList[].ResourceARN'

# 5) Limpiar el workspace
terraform workspace select default
terraform workspace delete eph-t032
Remove-Item eph.tfplan, eph-destroy.tfplan
```

## Qué debe comprobar la prueba (criterio de aceptación de T032)

1. El plan inicial crea **exactamente 5** recursos y no toca nada existente.
2. Staging no cambia: `terraform -chdir=environments/staging plan` sigue sin diferencias nuevas.
3. `destroy` elimina exactamente esos 5 recursos y el barrido por etiqueta `Environment=eph-t032` queda vacío.
4. Con el workspace `default` el plan **falla** con el mensaje de la guarda (comprobación negativa). Se puede comprobar
   sin credenciales de AWS: `terraform -chdir=environments/ephemeral test` (proveedor simulado en `tests/guard.tftest.hcl`).

## Qué no hace

No prueba ECS con servicios, ALB ni secretos. Si más adelante se quiere un ambiente efímero con aplicación completa,
conviene extraer módulos a `modules/` y reutilizarlos desde staging y desde este ambiente.
