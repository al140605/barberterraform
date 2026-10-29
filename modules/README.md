# Propuesta de módulos

Las tres raíces actuales declaran recursos directamente. Este directorio no contiene
módulos ejecutables ni acredita que la infraestructura ya esté importada.

Las responsabilidades candidatas a extraer son red, ALB, ECS/ECR, almacenamiento,
CloudFront y Atlas. Su separación solo se justifica si reduce duplicación, permite
pruebas independientes o facilita mantenimiento. No hace falta crear módulos vacíos.

Una extracción futura debe conservar direcciones mediante moved blocks o una
migración de estado revisada, mantener providers y versiones en las raíces y exponer
únicamente inputs/outputs necesarios. El plan debe comprobar que la reorganización
no propone crear, reemplazar ni destruir recursos existentes.

ACM, DNS, roles IAM, task definitions y acceso de red Atlas no pasan a estar gestionados
por aparecer en esta propuesta. Incorporarlos requiere alcance y evidencia propios.
La VPC predeterminada continúa siendo un data source.

Consultar el [inventario declarado](../docs/INFRAESTRUCTURA_STAGING.md) y el
[registro de excepciones](../docs/EXCEPCIONES_CHECKOV.md). Esta propuesta no autoriza
mover estado ni modificar infraestructura.
