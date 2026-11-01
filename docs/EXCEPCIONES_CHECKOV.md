# Registro de excepciones de Checkov

Revisión local: 28-oct-2026. Base de código: commit `28d0af3` (PR #11).
Herramienta: Checkov 3.4.0, framework Terraform, sin descargar módulos externos.
Se conservan las exclusiones inline y la configuración original; no se cambia infraestructura.

## Qué significan los números

- 51 anotaciones inline, con 37 IDs diferentes.
- 107 resultados omitidos, correspondientes a 36 controles distintos.
- 80 resultados aprobados, cero fallos y cero errores de parseo sobre 57 recursos.

Una anotación puede expandirse por for_each a varias instancias. Una regla inline
puede no producir un resultado en esta versión. Por eso 107 omisiones no son 107
comentarios ni una medida de seguridad aprobada. Checkov no acredita controles de
Atlas ni verifica el entorno remoto. El reporte JSON de aquella revisión se conservó localmente;
no es un artefacto público del repositorio porque incluye código y metadatos.
Para una nueva evaluación, generar evidencia propia con [PRUEBAS.md](PRUEBAS.md).

## Criterio de revisión

Este registro documenta propuestas de clasificación, no aceptación del riesgo.
KikeGonRam coordina el acuerdo con quienes mantienen infraestructura y aplicaciones
para definir responsable, fecha y evidencia por cambio operativo; esas
asignaciones siguen pendientes. El acuerdo se coordina en [#14](https://github.com/al140605/barberterraform/issues/14)
y las protecciones previas al plan en [#13](https://github.com/al140605/barberterraform/issues/13).
Revisar antes del primer plan conectado y cada
vez que cambien recursos, arquitectura o versión de Checkov.

No retirar skips para mejorar una cifra ni agregar exclusiones generales. Para
comprobar un falso positivo, usar una copia aislada y retirar solo la anotación
estudiada, repetir análisis y comparar recursos/controles. Su retirada definitiva
requiere evidencia reproducible y PR propio.

## Catálogo de controles

La columna de omisiones se refiere a esta corrida, no al número de anotaciones.

| Control | Omisiones | Clasificación propuesta | Riesgo y criterio de salida |
| --- | ---: | --- | --- |
| `CKV2_AWS_20` | 1 | Deuda de transporte | CloudFront hacia ALB usa HTTP. Evaluar certificado y migración a HTTPS con plan y pruebas. |
| `CKV2_AWS_28` | 1 | Deuda de protección | No hay WAF en ALB. La prefix list limita a servidores de CloudFront, no a nuestras distribuciones. Evaluar protección del origen. |
| `CKV2_AWS_32` | 3 | Control por comprobar | Cabeceras delegadas a aplicaciones. Verificar respuestas reales por dominio y ruta antes de aceptar equivalencia. |
| `CKV2_AWS_47` | 3 | Justificación insuficiente | PHP/Nuxt no prueba ausencia de dependencias Java ni sustituye protección WAF. Revisar cobertura de componentes y reglas. |
| `CKV2_AWS_5` | 6 | Análisis por revisar | Seis omisiones: grupos asociados por expresiones, grupo heredado y grupo efímero aislado. Reproducir sin cada skip en copia antes de declarar falso positivo. ECS ya está declarado. |
| `CKV2_AWS_57` | 12 | Deuda de rotación | 12 secretos sin rotación automática declarada. Identificar emisor, consumidor y procedimiento privado de rotación. |
| `CKV2_AWS_61` | 2 | Decisión de retención | Definir recuperación y conservación antes del ciclo de vida; evitar eliminar versiones necesarias del estado. |
| `CKV2_AWS_62` | 2 | Diseño por confirmar | No hay consumidor de eventos declarado. Reevaluar si se incorpora procesamiento asíncrono. |
| `CKV_AWS_103` | 3 | Dependencia de transporte | La política TLS del listener se revisará con la migración HTTPS. No implica TLS extremo a extremo. |
| `CKV_AWS_131` | 1 | Deuda de endurecimiento | Evaluar descarte de encabezados inválidos con pruebas de compatibilidad. |
| `CKV_AWS_136` | 3 | Compatibilidad temporal | ECR AES256. Revisar reemplazo y migración a KMS; no recrear repositorios usados por despliegues. |
| `CKV_AWS_144` | 2 | Diseño por confirmar | Una región; versionado del estado no sustituye réplica ni recuperación probada. Definir RPO/RTO. |
| `CKV_AWS_145` | 2 | Decisión de cifrado | AES256 declarado. Evaluar requisitos y permisos de KMS; no cambiar cifrado sin plan. |
| `CKV_AWS_149` | 12 | Decisión de cifrado | 12 contenedores de secretos sin clave propia. Evaluar política KMS, consumidores y recuperación. |
| `CKV_AWS_150` | 1 | Deuda de protección | prevent_destroy no bloquea borrado por consola/API ni protege un recurso retirado de configuración. Evaluar protección nativa ALB. |
| `CKV_AWS_158` | 4 | Decisión de cifrado | Logs sin clave KMS propia. ECS ya está declarado: el motivo inline pendiente de incorporarlo quedó antiguo. |
| `CKV_AWS_18` | 2 | Deuda de observabilidad | Faltan logs de acceso S3. Definir destino, retención y acceso antes de implementar. |
| `CKV_AWS_2` | 3 | Deuda de transporte | Listeners HTTP. Evaluar HTTPS de origen; HTTPS al usuario no cifra este tramo. |
| `CKV_AWS_21` | 1 | Deuda de recuperación | Versionado no declarado en buckets de aplicación. Definir retención, costo y recuperación; difiere del bucket de estado versionado. |
| `CKV_AWS_23` | 5 | Deuda de trazabilidad | Reglas sin descripción. Añadir descripciones modifica AWS y requiere plan; no hacerlo en mantenimiento documental. |
| `CKV_AWS_260` | 1 | Retirada por evaluar | Grupo heredado con entrada pública. El código aún lo referencia desde tareas; verificar ENI/asociaciones reales antes de retirar. |
| `CKV_AWS_283` | 0 | Anotación sin resultado | Presente en código, sin omisión reportada por Checkov 3.4.0 en esta corrida. Revisar aplicabilidad en copia; no contar como control evaluado. |
| `CKV_AWS_305` | 3 | Aplicabilidad por revisar | La excepción se expande a frontend y API (spark se eliminó), pero el motivo solo cita Nuxt. Revisar la raíz de cada origen. |
| `CKV_AWS_310` | 3 | Decisión de disponibilidad | Un origen ALB; definir disponibilidad y recuperación antes de añadir failover. |
| `CKV_AWS_333` | 2 | Decisión de red | Servicios con IP pública. Confirmar necesidad, rutas y grupos; analizar endpoints o NAT con costo y permisos. |
| `CKV_AWS_338` | 4 | Decisión de retención | 90 días en staging y 7 en efímero; confirmar requisitos y costo, sin extrapolar a producción. |
| `CKV_AWS_374` | 3 | Diseño por confirmar | Sin georrestricción. Confirmar alcance de servicio; no usar geobloqueo como autenticación. |
| `CKV_AWS_378` | 3 | Deuda de transporte | Target groups HTTP. Migrar exige compatibilidad TLS de las tareas y comprobaciones de salud. |
| `CKV_AWS_382` | 5 | Deuda de red | Salida amplia. La ausencia de NAT no demuestra que el ALB necesite salida universal; revisar destinos y puertos por grupo. |
| `CKV_AWS_51` | 3 | Compatibilidad temporal | ECR mutable por latest. Coordinar etiquetas SHA, task definitions y rollback antes de exigir inmutabilidad. |
| `CKV_AWS_54` | 1 | Compatibilidad de publicación | uploads permite política pública; receipts conserva bloqueo. Revisar exposición y alternativa privada con OAC sin romper URLs. |
| `CKV_AWS_56` | 1 | Compatibilidad de publicación | Excepción de bloqueo público aplicable a uploads. Confirmar alcance de solo lectura y separación de recibos. |
| `CKV_AWS_65` | 1 | Decisión de observabilidad | Container Insights desactivado. Definir métricas, costo y alertas requeridas. |
| `CKV_AWS_68` | 3 | Deuda de protección | CloudFront sin WAF declarado. Evaluar reglas, cobertura y costo. |
| `CKV_AWS_70` | 1 | Compatibilidad de publicación | Política pública GetObject en uploads. Confirmar que no contiene documentos privados; no publicar evidencia con datos reales. |
| `CKV_AWS_86` | 3 | Deuda de observabilidad | CloudFront sin logs declarados. Elegir modalidad de logging antes de asumir que siempre requiere ACL. |
| `CKV_AWS_91` | 1 | Deuda de observabilidad | ALB sin logs de acceso declarados. Diseñar destino, política y retención. |

## Referencias exactas en código

El enlace apunta al archivo; la línea identifica la anotación en esta revisión.
Los motivos originales se conservan en el código y deben contrastarse con el catálogo.

| Archivo | Línea | Control |
| --- | ---: | --- |
| [bootstrap/state/main.tf](../bootstrap/state/main.tf) | 15 | `CKV_AWS_144` |
| [bootstrap/state/main.tf](../bootstrap/state/main.tf) | 16 | `CKV_AWS_145` |
| [bootstrap/state/main.tf](../bootstrap/state/main.tf) | 17 | `CKV_AWS_18` |
| [bootstrap/state/main.tf](../bootstrap/state/main.tf) | 18 | `CKV2_AWS_61` |
| [bootstrap/state/main.tf](../bootstrap/state/main.tf) | 19 | `CKV2_AWS_62` |
| [environments/ephemeral/main.tf](../environments/ephemeral/main.tf) | 62 | `CKV_AWS_338` |
| [environments/ephemeral/main.tf](../environments/ephemeral/main.tf) | 63 | `CKV_AWS_158` |
| [environments/ephemeral/main.tf](../environments/ephemeral/main.tf) | 92 | `CKV2_AWS_5` |
| [environments/staging/alb.tf](../environments/staging/alb.tf) | 37 | `CKV_AWS_150` |
| [environments/staging/alb.tf](../environments/staging/alb.tf) | 38 | `CKV_AWS_91` |
| [environments/staging/alb.tf](../environments/staging/alb.tf) | 39 | `CKV_AWS_131` |
| [environments/staging/alb.tf](../environments/staging/alb.tf) | 40 | `CKV2_AWS_28` |
| [environments/staging/alb.tf](../environments/staging/alb.tf) | 41 | `CKV2_AWS_20` |
| [environments/staging/alb.tf](../environments/staging/alb.tf) | 70 | `CKV_AWS_378` |
| [environments/staging/alb.tf](../environments/staging/alb.tf) | 89 | `CKV_AWS_2` |
| [environments/staging/alb.tf](../environments/staging/alb.tf) | 90 | `CKV_AWS_103` |
| [environments/staging/cdn.tf](../environments/staging/cdn.tf) | 89 | `CKV_AWS_86` |
| [environments/staging/cdn.tf](../environments/staging/cdn.tf) | 90 | `CKV_AWS_68` |
| [environments/staging/cdn.tf](../environments/staging/cdn.tf) | 91 | `CKV_AWS_310` |
| [environments/staging/cdn.tf](../environments/staging/cdn.tf) | 92 | `CKV_AWS_374` |
| [environments/staging/cdn.tf](../environments/staging/cdn.tf) | 93 | `CKV2_AWS_32` |
| [environments/staging/cdn.tf](../environments/staging/cdn.tf) | 94 | `CKV2_AWS_47` |
| [environments/staging/cdn.tf](../environments/staging/cdn.tf) | 95 | `CKV_AWS_305` |
| [environments/staging/ecs.tf](../environments/staging/ecs.tf) | 37 | `CKV_AWS_65` |
| [environments/staging/ecs.tf](../environments/staging/ecs.tf) | 102 | `CKV_AWS_333` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 53 | `CKV_AWS_382` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 54 | `CKV_AWS_23` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 55 | `CKV2_AWS_5` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 87 | `CKV_AWS_260` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 88 | `CKV_AWS_382` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 89 | `CKV2_AWS_5` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 90 | `CKV_AWS_23` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 123 | `CKV_AWS_382` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 124 | `CKV_AWS_23` |
| [environments/staging/network.tf](../environments/staging/network.tf) | 125 | `CKV2_AWS_5` |
| [environments/staging/resources.tf](../environments/staging/resources.tf) | 33 | `CKV_AWS_51` |
| [environments/staging/resources.tf](../environments/staging/resources.tf) | 34 | `CKV_AWS_136` |
| [environments/staging/resources.tf](../environments/staging/resources.tf) | 52 | `CKV_AWS_338` |
| [environments/staging/resources.tf](../environments/staging/resources.tf) | 53 | `CKV_AWS_158` |
| [environments/staging/secrets.tf](../environments/staging/secrets.tf) | 29 | `CKV_AWS_149` |
| [environments/staging/secrets.tf](../environments/staging/secrets.tf) | 30 | `CKV2_AWS_57` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 20 | `CKV_AWS_18` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 21 | `CKV_AWS_21` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 22 | `CKV_AWS_144` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 23 | `CKV2_AWS_61` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 24 | `CKV2_AWS_62` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 25 | `CKV_AWS_145` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 55 | `CKV_AWS_54` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 56 | `CKV_AWS_56` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 84 | `CKV_AWS_70` |
| [environments/staging/storage.tf](../environments/staging/storage.tf) | 85 | `CKV_AWS_283` |

## Orden propuesto para el seguimiento

1. Verificar protecciones del entorno de apply y condiciones OIDC por job, sin
   activar plan o apply. La configuración del propietario es evidencia separada.
2. Revisar grupo heredado, salida de ALB y protección del origen. Su estado real
   requiere lectura autorizada; no se certificó exposición explotable en esta revisión.
3. Definir recuperación de archivos/estado y rotación de secretos con sus responsables.
4. Acordar logs, métricas, WAF, cifrado y transporte HTTPS según riesgo y presupuesto.
5. Reproducir supuestos falsos positivos y corregir motivos antiguos o demasiado amplios.

Ninguna de estas propuestas autoriza una intervención en producción ni cambia el backlog.

## Fuentes técnicas

- [AWS: restringir acceso al ALB desde CloudFront](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/restrict-access-to-load-balancer.html).
- [GitHub: OIDC con AWS y condición sub de un entorno](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).
- [Configuración de Checkov del proyecto](../.checkov.yaml).

[Índice de documentación](README.md) · [Decisiones de arquitectura](DECISIONES_ARQUITECTURA.md) ·
[Evidencias y alcance de la revisión](EVIDENCIAS.md).
