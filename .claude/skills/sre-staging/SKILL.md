---
name: sre-staging
description: Mapa de staging de UrbanBlade para diagnosticar con consultas de solo lectura: recursos de AWS, nombres de alarmas, logs, URL y límites de permisos. Úsalo cuando suene una alarma, falle el sitio o la API, o se pida revisar la salud y el costo.
---
<!-- Generado desde urbanblade-equipo. No editar aquí: cambia el origen y vuelve a sincronizar. -->

# SRE de staging

Procedimiento completo: `docs/referencia/RUNBOOK_INCIDENTES_STAGING.md` del backend. Alarmas y panel: `docs/ALARMAS.md` del repo de Terraform.

## Mapa
| Cosa | Valor |
| --- | --- |
| Región y clúster | `us-east-1`, `urbanblade-staging` |
| Servicios de ECS | `uba-stg-barber`, `uba-stg-frontend` (autoescalado de 1 a 2 tareas, CPU al 60 %) |
| Logs | `/ecs/urbanblade-staging/barber`, `/ecs/urbanblade-staging/frontend-urban` |
| Sitio y API | `https://urbanblade.com.mx` (salud en `/api/health`) y `https://api.urbanblade.com.mx` (salud en `/up`) |
| Alarmas | `urbanblade-staging-<barber o frontend>-<sin-hosts-saludables, errores-5xx, latencia-p95, memoria-alta>` y `urbanblade-staging-alb-errores-5xx` |
| Aviso y panel | tema SNS `urbanblade-staging-alarmas` y panel de CloudWatch `urbanblade-staging` |
| Presupuesto | 120 USD al mes (alertas por correo) |
| ECR | `urbanblade/barber`, `urbanblade/frontend-urban`; etiquetas `sha-<corto>`, `latest` y `rollback-<fecha>-pre-<sha>` |

## Primer vistazo (solo lectura)
```powershell
aws ecs describe-services --cluster urbanblade-staging --services uba-stg-barber uba-stg-frontend --query "services[].[serviceName,runningCount,desiredCount,deployments[0].rolloutState]" --output table
aws cloudwatch describe-alarms --alarm-name-prefix urbanblade-staging- --state-value ALARM --query "MetricAlarms[].AlarmName"
aws logs tail /ecs/urbanblade-staging/barber --since 30m
```

## Qué puede y qué no puede la identidad de trabajo
El usuario `staging-deploy` lee ECS, ECR y logs, pero **no** puede leer el panel (`cloudwatch:GetDashboard`), cambiar el estado de una alarma (`SetAlarmState`), ver las suscripciones de SNS ni leer Route 53. Si necesitas algo de eso, dilo: lo hace el propietario con su sesión.

## Límites
Solo consultas de lectura. No hagas `update-service`, `put-image`, `set-alarm-state` ni cambios de IAM, redes, secretos o DNS. Propón el comando y quién debe ejecutarlo.
