# Alarmas de disponibilidad de staging

Definidas en [`environments/staging/alarmas.tf`](../environments/staging/alarmas.tf). Antes solo existían las alarmas del autoescalado: nadie recibía aviso si el sitio se caía. Estas alarmas avisan por correo (SNS) y se acompañan de un panel de CloudWatch.

Como el presupuesto de [COSTOS.md](COSTOS.md), no dependen de los recursos importados de staging: se nombran por cadena y se aplican con `-target`. Los correos no se versionan (repositorio público): se pasan al aplicar y, sin ellos, no se crea nada.

## Qué se vigila

| Alarma | Condición | Si se dispara |
| --- | --- | --- |
| `<servicio>-sin-hosts-saludables` | Ningún host saludable en el target group durante 3 minutos seguidos (los datos faltantes cuentan como fallo). | El servicio está caído o no pasa su chequeo de salud. Ver la reversión de [DESPLIEGUE_OIDC.md](DESPLIEGUE_OIDC.md). |
| `<servicio>-errores-5xx` | 10 o más errores 5xx de la aplicación en 5 minutos. | Revisar los logs `/ecs/urbanblade-staging/<servicio>`. |
| `alb-errores-5xx` | 5 o más errores 5xx generados por el balanceador (502, 503, 504) en 5 minutos. | El ALB no llegó a ninguna tarea. |
| `<servicio>-latencia-p95` | p95 del tiempo de respuesta mayor que 3 s durante 15 minutos. | Lentitud sostenida; mirar CPU, memoria y la base de datos. |
| `<servicio>-memoria-alta` | Memoria media mayor que 85 % durante 15 minutos. | Posible fuga: el autoescalado reacciona a CPU, no a memoria. |

`<servicio>` es `frontend` o `barber`. Para evitar ruido, la falta de datos en las alarmas de errores cuenta como «sin error», y un despliegue normal (que reemplaza la tarea en menos de 3 minutos) no dispara la de caída. Cada alarma avisa también cuando vuelve a la normalidad.

## Aplicar

Con una sesión de administrador, desde `environments/staging`. Los correos se pasan por variable de entorno, sin guardarlos en archivos:

```powershell
$env:TF_VAR_alarm_alert_emails = '["correo@dominio.com"]'
terraform plan -out=alarmas.tfplan `
  "-target=aws_sns_topic.alarmas" "-target=aws_sns_topic_subscription.alarmas_correo" `
  "-target=aws_cloudwatch_metric_alarm.sin_hosts_saludables" "-target=aws_cloudwatch_metric_alarm.errores_5xx" `
  "-target=aws_cloudwatch_metric_alarm.errores_5xx_alb" "-target=aws_cloudwatch_metric_alarm.latencia" `
  "-target=aws_cloudwatch_metric_alarm.memoria" "-target=aws_cloudwatch_dashboard.staging"
```

El plan debe mostrar solo **recursos nuevos**: 1 tema, una suscripción por correo, 9 alarmas (2 de caída, 2 de 5xx de aplicación, 1 del balanceador, 2 de latencia y 2 de memoria) y 1 panel. Si propone importaciones, cambios o borrados de otros recursos, no se aplica. Después `terraform apply alarmas.tfplan`.

**Paso manual obligatorio:** AWS envía a cada correo un mensaje de confirmación de SNS; hasta que se pulse «Confirm subscription» no llegan avisos (a diferencia de AWS Budgets, que no lo pide).

## Comprobar

1. Confirmar la suscripción y abrir el panel `urbanblade-staging` en CloudWatch.
2. Probar el canal con una alarma de prueba: `aws cloudwatch set-alarm-state --alarm-name <nombre> --state-value ALARM --state-reason prueba`. Vuelve sola a `OK` en la siguiente evaluación.
3. No apagar un servicio de staging solo para probar la de caída.

## Límites

- El tema SNS no se cifra con KMS: CloudWatch no puede publicar en un tema cifrado con la clave administrada por AWS. El contenido son nombres de alarmas, no datos sensibles.
- Los identificadores del ALB y de los target groups están escritos en el archivo. Si se recrean, hay que actualizarlos.
- Costo: 9 alarmas estándar nuevas más las 4 del autoescalado; las alarmas cuestan unos 0,10 USD al mes cada una por encima de la capa gratuita, y el panel entra en los 3 gratuitos de CloudWatch. Se espera menos de 1 USD al mes; verificarlo en [COSTOS.md](COSTOS.md) tras el primer mes.
