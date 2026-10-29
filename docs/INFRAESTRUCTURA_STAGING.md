# Infraestructura de staging (T029)

Inventario derivado del código de staging, revisado el 28-oct-2026. Describe la
arquitectura declarada y los recursos previstos para importación; no certifica
el estado remoto ni la configuración actual de AWS/Atlas. Algunos identificadores
están en los archivos Terraform: son metadatos de infraestructura, no credenciales.
No publicar estados, planes completos, contraseñas ni valores de secretos.

## Diagrama

```mermaid
flowchart LR
    U([Usuarios]) -->|HTTPS| CF["CloudFront<br/>frontend · API · spark<br/>(T120: declarado)"]
    CF -->|"HTTP 80 / 8080 / 8501<br/>solo rangos de CloudFront"| ALB

    subgraph TF ["Declarado para adopción con Terraform"]
        ALB["ALB urbanblade-staging<br/>3 listeners HTTP"]
        ALB -->|80| TGF["target group frontend :3000"]
        ALB -->|8080| TGB["target group barber :80"]
        ALB -->|8501| TGS["target group spark :8501"]
        TGF --> SF["ECS uba-stg-frontend"]
        TGB --> SB["ECS uba-stg-barber"]
        SF -.->|imagen| ECR[("ECR<br/>barber · frontend-urban · spark")]
        SB -.->|imagen| ECR
        SF -.->|logs| LOG["CloudWatch Logs<br/>/ecs/urbanblade-staging/*"]
        SB -.->|logs| LOG
        SB -.->|"12 secretos"| SEC["Secrets Manager<br/>urbanblade/staging/barber/*"]
        SG["Grupos de seguridad<br/>3 de CloudFront + tareas + heredado"] -.-> ALB
        SG -.-> SF
        SG -.-> SB
        SB -->|archivos| UP[("S3 uploads<br/>lectura pública") ]
        SB -->|recibos| RC[("S3 receipts<br/>privado") ]
        ATLAS[("MongoDB Atlas M0<br/>(T118: declarado)")]
    end

    TGS --> SS["ECS uba-stg-spark<br/>(fuera de Terraform)"]
    SB -->|"IP pública"| ATLAS
```

Línea continua = tráfico; punteada = uso o pertenencia. Los recursos del recuadro llevan `prevent_destroy`, salvo la
asociación de proveedores de capacidad del clúster ECS.

## Inventario declarado

| Raíz | Recurso | Cantidad | Origen |
| --- | --- | --- | --- |
| `bootstrap/state` | Bucket de estado (bloqueo público, versionado, cifrado, solo TLS) | 5 recursos | base |
| `environments/staging` | ECR (barber, frontend-urban, spark) y grupos de logs | 3 + 3 importaciones | base |
| `environments/staging` | Grupos de seguridad | 5 importaciones | T024 |
| `environments/staging` | ALB, target groups y listeners | 1 + 3 + 3 importaciones | T024 |
| `environments/staging` | Clúster ECS, proveedores de capacidad y servicios (barber, frontend) | 1 + 1 + 2 importaciones | T026 |
| `environments/staging` | Secretos de barber (solo el contenedor, nunca el valor) | 12 importaciones | T026 |
| `environments/staging` | Distribuciones de CloudFront (frontend, api, spark) | 3 importaciones | T120 |
| `environments/staging` | Buckets S3 `uploads` y `receipts` (cifrado, bloqueo público, propiedad) y política pública de `uploads` | 2 + 6 + 1 importaciones | T120 |
| `environments/staging` | Clúster Atlas M0 y 4 usuarios de base de datos (sin contraseñas) | 1 + 4 importaciones declaradas | T118 |
| `environments/ephemeral` | Ambiente desechable por workspace `eph-*` | 5 recursos nuevos | T032 |

Staging suma **51 importaciones** (6 + 12 + 16 + 12 + 5; la incorporación al estado no se acredita aquí). Lo que **no** está en Terraform todavía: certificados ACM, la
lista de acceso de red de Atlas, el bucket S3 de respaldos, el servicio ECS y secretos de `spark`, así como el servicio, ECR, logs y secretos
de `ollama` (ECR y logs de `spark` sí están declarados),
roles IAM y la contraseña de cada usuario de Atlas. La VPC predeterminada se lee, no se administra.

## Variables (`environments/staging/variables.tf`)

| Variable | Tipo | Valor por defecto | Para qué sirve |
| --- | --- | --- | --- |
| `project_name` | string | `urbanblade` | Etiqueta `Project` de todos los recursos. |
| `environment` | string | `staging` | Etiqueta `Environment`. |
| `aws_region` | string | `us-east-1` | Región del proveedor. |
| `aws_account_id` | string | sin valor (obligatoria) | Cuenta esperada: el proveedor se niega a operar en otra. |
| `atlas_project_id` | string | sin valor (obligatoria) | ID del proyecto; 24 caracteres hexadecimales. |
| `atlas_cluster_name` | string | sin valor (obligatoria) | Nombre real del clúster. |
| `atlas_region` | string | `US_EAST_1` | Región de Atlas; debe coincidir con el clúster. |

Se definen en `terraform.tfvars` (copiado de `terraform.tfvars.example`; el archivo real está en `.gitignore`).
Credenciales de AWS y de Atlas **siempre** por variables de entorno, nunca en `.tfvars`.

## Salidas (`terraform -chdir=environments/staging output`)

| Salida | Contenido |
| --- | --- |
| `aws_account_id`, `aws_region`, `environment` | Cuenta verificada, región y ambiente. |
| `vpc_id`, `subnet_ids` | VPC predeterminada y subredes (por zona). |
| `ecr_repository_urls`, `log_group_names` | URL de cada ECR y grupos de logs. |
| `security_group_ids` | Un grupo de CloudFront por puerto, el de las tareas y el heredado. |
| `alb_dns_name`, `alb_arn`, `alb_listeners`, `target_group_arns` | ALB, qué puerto reenvía a qué target group y sus ARN. |
| `ecs_cluster_name`, `ecs_service_names` | Clúster y servicios ECS. |
| `barber_secret_names` | Nombres (nunca valores) de los secretos de barber. |
| `atlas_cluster_name`, `atlas_database_usernames` | Clúster y usuarios de Atlas (nunca contraseñas ni cadenas de conexión). |
| `cloudfront_distributions`, `s3_bucket_names` | ID, dominio y alias de cada distribución; nombres de los buckets. |

Estas salidas exponen metadatos, no valores de secretos. Que un output no esté
marcado sensitive no convierte el estado completo en información publicable.
Terraform solo declara los contenedores de Secrets Manager, sin secret_version.

## Evidencia por nivel

1. **Local:** formato, validate en tres raíces, prueba mock y pruebas del resumen;
   procedimiento y límites en [CI_TERRAFORM.md](CI_TERRAFORM.md).
2. **CI:** URL de la ejecución y SHA exacto, con todos los controles requeridos aprobados.
   Un workflow desactivado no aporta esa evidencia.
3. **Plan conectado, solo con autorización:** backend correcto, identidad verificada,
   lectura de recursos y permisos necesarios para el bloqueo del estado. Un rol de
   lectura de recursos no implica que pueda bloquear el backend S3.
4. **Revisión:** examinar importaciones, cambios en sitio, reemplazos, eliminaciones,
   outputs y drift. Las etiquetas del proveedor pueden proponer cambios en sitio;
   deben quedar identificados y aprobados. Un recurso ya importado puede no aparecer
   como una nueva importación. Conservar el plan completo únicamente en un canal privado.
5. **Estado y operación:** outputs solo reflejan el estado disponible; no sustituyen
   un plan actualizado ni una comprobación funcional. Una aplicación autorizada
   necesita su propia evidencia; no se realizó durante esta revisión.

## Hallazgos del código (pendientes de contraste con el entorno)

- Los listeners del ALB son HTTP: CloudFront publica el HTTPS y habla HTTP con el origen.
- Un grupo de seguridad heredado acepta `0.0.0.0/0` en 80, 8080 y 8501, el código no lo asocia al ALB, pero aún aparece en las
  reglas del grupo de las tareas. Su uso real necesita verificación autorizada.
- El ALB no tiene protección contra borrado, registros de acceso ni WAF.

El [registro de excepciones de Checkov](EXCEPCIONES_CHECKOV.md) detalla alcance,
riesgos y criterios de revisión. Los motivos inline no acreditan aceptación del riesgo.
