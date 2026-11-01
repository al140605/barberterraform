# Control de costos de staging

Describe cómo se vigila y se limita el costo de AWS en staging. Revisión: **31-oct-2026**. El código está en
[costos.tf](../environments/staging/costos.tf); si esta guía y el código difieren, gana el código.

## Por qué existe

Una cuenta nueva recibe un crédito gratuito que **oculta el costo real** en la factura. Cuando se agota, el cobro llega completo más el IVA
(16 %). En staging, el cómputo de Fargate es lo más caro (cada tarea de 0.5 vCPU y 1 GB cuesta del orden de 18 USD al mes), seguido de las
direcciones IPv4 públicas (unos 3.65 USD al mes cada una, también las de las tareas), el balanceador y los secretos. Dos tareas por servicio
duplican esos costos aunque casi no haya tráfico.

## Qué hay

| Recurso | Qué hace |
| --- | --- |
| `aws_budgets_budget.mensual` | Presupuesto mensual con avisos por correo al 50, 80 y 100 % del gasto real y al 100 % del pronóstico. |
| `aws_appautoscaling_target.ecs` (frontend y barber) | Rango de tareas: mínimo 1, máximo 2. |
| `aws_appautoscaling_policy.cpu` (frontend y barber) | Sube a 2 tareas cuando la CPU promedio pasa de 60 % y baja con calma (5 min) para no oscilar. |

- **El presupuesto mide el uso real, sin restar créditos** (`include_credit = false`), porque el crédito fue justo lo que ocultó el costo. Incluye
  impuestos y soporte. Es gratuito: los dos primeros presupuestos de una cuenta no se cobran.
- **No hay correos en el repositorio** (es público). Solo se crea el presupuesto si se pasa `budget_alert_emails` al aplicar, con `-var` o con un
  `terraform.tfvars` que Git ignora. El límite se ajusta con `budget_limit_usd` (por defecto 120): conviene fijarlo cerca del gasto esperado de
  un mes completo más un margen.
- **Los despliegues no se cortan** con una sola tarea: los servicios usan mínimo sano 100 % y máximo 200 %, así que la tarea nueva arranca antes
  de parar la vieja.
- Ollama queda fuera del autoescalado. Spark se eliminó de staging el 31-oct-2026.

## Aplicar

Crear el presupuesto y el autoescalado necesita permisos que el usuario de despliegue no tiene (IAM del servicio vinculado y Budgets), así que se aplica con
una identidad administradora y credenciales temporales, con `-target`, como el resto de staging:

```powershell
cd environments/staging
terraform plan "-var=aws_account_id=<cuenta>" "-var=atlas_project_id=000000000000000000000000" "-var=atlas_cluster_name=placeholder" `
  '-var=budget_alert_emails=["correo@ejemplo.com"]' "-target=aws_budgets_budget.mensual" "-target=aws_appautoscaling_policy.cpu" "-out=costos.tfplan"
```

El plan debe mostrar **5 por crear** (el presupuesto, 2 objetivos y 2 políticas de autoescalado) y nada más. Si propone importaciones, cambios o borrados de
otros recursos, no se aplica.

## Después de aplicar

- Con el autoescalado activo, el número de tareas lo decide la carga: un valor fijo puesto a mano con `update-service --desired-count` queda dentro
  del rango y puede ser corregido por la política.
- Para tener el doble de capacidad en una demostración, subir `autoscaling_min_tasks` a 2 y aplicar de nuevo (o fijarlo temporalmente a mano), y bajarlo después.
- Revisar cada mes **Facturas** y **Cost Explorer**, filtrando por «Tipo de cargo» sin créditos, para ver el gasto de uso real.

## Límites

- La CPU es la única señal de escalado; un servicio saturado de memoria o de conexiones no escalaría por eso.
- El balanceador, las direcciones IPv4 y los secretos cuestan lo mismo con 1 que con 2 tareas, salvo las IPv4 de las tareas.
- No se midió la CPU real antes de elegir el rango (el usuario de despliegue no tiene permisos de CloudWatch): conviene revisarla una semana después.
