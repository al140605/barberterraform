# Despliegue a staging con OIDC

Describe cómo los workflows de `barber` y `frontend_Urbanblade` publican en AWS sin llaves de larga duración, y cómo se
mantiene el rol que lo permite. Revisión: **31-oct-2026**. El código vive en
[oidc_despliegue.tf](../environments/staging/oidc_despliegue.tf); si esta guía y el código difieren, gana el código.

## Cómo funciona

1. Un workflow `Desplegar a staging` se lanza a mano, solo desde `main`, y su job declara `environment: staging`.
2. GitHub emite un token OIDC firmado para ese job. Su `sub` identifica al repositorio y al entorno.
3. AWS valida el token contra el proveedor OIDC de GitHub y, si el `sub` y la audiencia cumplen la política de confianza,
   entrega credenciales temporales (una hora como máximo) del rol `urbanblade-staging-github-deploy`.
4. El entorno `staging` de GitHub exige la aprobación del propietario antes de que el job pueda pedir ese token.

No hay llaves de AWS en GitHub. La única variable es `AWS_DEPLOY_ROLE_ARN` (el ARN del rol, que no es un secreto), definida
en el entorno `staging` de cada repositorio.

## Qué crea Terraform

| Recurso | Función |
| --- | --- |
| `aws_iam_openid_connect_provider.github` | Proveedor OIDC de `token.actions.githubusercontent.com`. Es único por cuenta; se crea solo si no se pasa `github_oidc_provider_arn`. |
| `aws_iam_role.github_deploy` | Rol que asumen los workflows. Sesión máxima de una hora. |
| `aws_iam_role_policy.github_deploy` | Permisos mínimos del rol (siguiente sección). |

## Permisos del rol

- Iniciar sesión en ECR (`ecr:GetAuthorizationToken`, que no admite restricción por recurso).
- Leer y escribir imágenes y etiquetas **solo** en los repositorios `urbanblade/barber` y `urbanblade/frontend-urban`, y leer el
  resultado de su escaneo de vulnerabilidades (`ecr:DescribeImageScanFindings`).
- `ecs:UpdateService` y `ecs:DescribeServices` **solo** sobre `uba-stg-barber` y `uba-stg-frontend`.
- `ecs:ListTasks` y `ecs:DescribeTasks` limitados al clúster `urbanblade-staging`.

No puede leer secretos, tocar IAM, S3 ni la red, ni registrar definiciones de tarea. Los ARN de ECR y ECS se calculan por nombre
en el archivo, no por referencia a los recursos importados, para que este rol se pueda planear y aplicar sin arrastrar la
adopción del resto de staging.

## Política de confianza y subject inmutable

Los repositorios usan el subject inmutable de GitHub (`use_immutable_subject`), que incluye los IDs numéricos del propietario
y del repositorio:

```text
repo:<propietario>@<id>/<repositorio>@<id>:environment:staging
```

La variable `github_deploy_sub_prefixes` contiene el prefijo de cada repositorio autorizado y el entorno se añade desde
`github_deploy_environment`. Solo se acepta el formato inmutable: el formato por nombre permitiría que un repositorio borrado
y recreado con el mismo nombre heredara el acceso. Para obtener el prefijo de un repositorio:

```powershell
gh api repos/<propietario>/<repositorio>/actions/oidc/customization/sub --jq .sub_claim_prefix
```

Si se añade un repositorio nuevo, o se recrea uno existente, hay que añadir o actualizar su prefijo y aplicar el cambio. Una
condición con comodines no es válida: la validación de la variable la rechaza.

## Aplicar o cambiar el rol

El estado remoto vive en el bucket creado por [bootstrap/state](../bootstrap/state) (procedimiento en
[OPERACION_TERRAFORM.md](OPERACION_TERRAFORM.md)). Crear un proveedor OIDC o un rol requiere permisos de IAM que el usuario
de despliegue de staging no tiene a propósito, así que se aplica con una identidad administradora y credenciales temporales,
solo durante el `apply`.

```powershell
cd environments/staging
terraform init -reconfigure "-backend-config=bucket=<bucket-de-estado>" "-backend-config=key=staging/terraform.tfstate" `
  "-backend-config=region=us-east-1" "-backend-config=encrypt=true" "-backend-config=use_lockfile=true"
terraform plan "-var=aws_account_id=<cuenta>" "-var=atlas_project_id=000000000000000000000000" `
  "-var=atlas_cluster_name=placeholder" "-target=aws_iam_role_policy.github_deploy" "-out=oidc.tfplan"
terraform apply "oidc.tfplan"
```

- **Usar siempre `-target`** mientras el resto de staging no esté adoptado en el estado: un plan sin `-target` arrastra
  importaciones con cambios en sitio sobre ECR, ECS, balanceador y red. Los valores `atlas_*` son marcadores: con `-target`
  no se evalúan.
- En Windows PowerShell 5.1 hay que entrecomillar el argumento completo (`"-target=..."`); si no, el punto parte el argumento.
- El plan debe mostrar solo recursos de IAM. Si propone importaciones, cambios o borrados de otros recursos, no se aplica.
- Un plan guardado caduca si el estado cambia después de crearlo; hay que generarlo de nuevo.

## Higiene de las imágenes en ECR

[ecr_ciclo_de_vida.tf](../environments/staging/ecr_ciclo_de_vida.tf) añade dos cosas, también aplicables con `-target`:

| Recurso | Qué hace |
| --- | --- |
| `aws_ecr_lifecycle_policy.deploy` (barber y frontend-urban) | Borra las imágenes **sin etiqueta con más de 14 días**, conserva las **20** etiquetas `sha-*` y las **10** `rollback-*` más recientes. No toca `latest` ni las etiquetas ajenas (por ejemplo las de despliegues manuales antiguos). |
| `aws_ecr_registry_scanning_configuration.basic_on_push` | Escaneo básico (gratuito) de cada imagen al subirla. Es una configuración de la cuenta y la región: aplica a todos los repositorios, también spark. |

Por qué hace falta: cada despliegue vuelve a subir `latest` y la imagen anterior queda sin etiqueta; además el pipeline deja una
etiqueta `rollback-*` por despliegue. Sin política, a 31-oct-2026 había 211 imágenes de barber (81.8 GB) y 235 de frontend-urban
(14.8 GB), tres cuartas partes sin etiqueta. Simulada con los datos reales, la política libera unos 58 GB y 8.5 GB sin borrar ninguna
imagen con `latest` ni con otra etiqueta.

Es seguro porque las definiciones de tarea (barber:12, frontend:6) usan `...:latest` y una imagen sin etiqueta no la necesita ninguna
tarea; la reversión usa las etiquetas `rollback-*`, que se conservan. ECR aplica las políticas de forma asíncrona (puede tardar hasta
un día) y borra de verdad: no hay papelera. Para cambiar los límites, editar `ecr_lifecycle_policy` y aplicar de nuevo.

Los workflows de despliegue muestran el resumen de vulnerabilidades por severidad (crítica, alta, media…) en el resumen de la
ejecución. Es **informativo**: nunca bloquea ni revierte un despliegue, y si el escaneo al subir aún no está activo, el paso avisa y
sigue. Para aplicar esta parte, el rol necesita su permiso nuevo, así que se incluye el rol en el mismo `apply`:

```powershell
terraform plan "-var=aws_account_id=<cuenta>" "-var=atlas_project_id=000000000000000000000000" "-var=atlas_cluster_name=placeholder" `
  "-target=aws_iam_role_policy.github_deploy" "-target=aws_ecr_lifecycle_policy.deploy" `
  "-target=aws_ecr_registry_scanning_configuration.basic_on_push" "-out=ecr.tfplan"
```

El plan debe mostrar 3 por crear (dos políticas y la configuración de escaneo) y 1 por cambiar (la política del rol), y nada más.

## Estado y límites actuales

- El estado remoto de staging contiene únicamente estos tres recursos de IAM. ECR, ECS, red, CloudFront, S3 y Atlas siguen
  declarados con bloques `import`, sin adoptar. Adoptarlos requiere su propia revisión del plan.
- Las definiciones de tarea de ECS usan la etiqueta `latest`, que es mutable. Los workflows publican también `sha-<corto>` y
  `rollback-<fecha>-pre-<sha>`, pero pasar a etiquetas inmutables exige registrar definiciones de tarea nuevas.
- El rol solo despliega backend y frontend. ollama queda fuera.

## Primeros despliegues

| Servicio | Resultado |
| --- | --- |
| frontend-urban (`fdef30c`) | Primer intento rechazado por el subject (formato por nombre en la confianza); corregido y repetido con éxito. |
| barber (`f5fff40`) | Éxito al primer intento tras la corrección. |

El primer fallo no publicó nada: el job se detuvo en el paso de credenciales, antes de tocar ECR o ECS.
