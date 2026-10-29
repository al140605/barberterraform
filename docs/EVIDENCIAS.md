# Evidencias y límites de verificación

Las referencias documentan resultados de commits concretos. No certifican el
estado actual de AWS/Atlas, no sustituyen una ejecución nueva y no actualizan
el backlog por sí solas. Consulta documental y de GitHub: **29-oct-2026**.

## Base de referencia

| Cambio | Evidencia | Alcance comprobado |
| --- | --- | --- |
| Separación de workflows y dependencias fijadas | [PR #16](https://github.com/al140605/barberterraform/pull/16), fusionado en `ee495f0`. | Código, pruebas de políticas y runner con Terraform ficticio. |
| Validación de main tras #16 | [Ejecución 40828684673](https://github.com/al140605/barberterraform/actions/runs/40828684673). | Seis checks aprobados sobre `ee495f0`; sin ejecución de workflows conectados. |
| Suite completa en Linux previa a la fusión | [Ejecución 40828513444](https://github.com/al140605/barberterraform/actions/runs/40828513444). | 30 pruebas, cero fallos y cero omisiones sobre `c7d14ae`. |
| Bloqueo independiente de apply | [PR #15](https://github.com/al140605/barberterraform/pull/15). | Guardas y payloads preparados; no instalación de reglas administrativas. |
| Catálogo de excepciones | [PR #12](https://github.com/al140605/barberterraform/pull/12). | Revisión estática, sin cambios de recursos ni retirada de skips. |

La actualización documental posterior debe aportar su propio PR y CI. Estos enlaces
son la base revisada, no una afirmación de que todo cambio futuro esté validado.

## Estado de GitHub observado el 29-oct-2026

- Workflows de validación, plan y apply registrados y activos.
- `TERRAFORM_PLAN=false` y `TERRAFORM_APPLY=false`: operaciones conectadas bloqueadas.
- Cero entornos devueltos por la API; `staging-aprobacion` aún no está configurado.
- [#13](https://github.com/al140605/barberterraform/issues/13) abierto, asignado a
  KikeGonRam y al140605 para preparación y aplicación administrativa respectivamente.
- [#14](https://github.com/al140605/barberterraform/issues/14) abierto, coordinado por
  KikeGonRam; responsables técnicos por bloque y fechas por acordar.

El intento de configuración del 28-oct-2026 devolvió HTTP 404 para branch protection
y HTTP 403 para el entorno: `Must have admin rights to Repository`. La cuenta tenía
escritura sin administración. El 404 no demuestra ausencia de protección; puede
ocultar falta de acceso. Los payloads versionados no prueban aplicación de ajustes.

## Historial de checksums (28-oct-2026)

La [primera ejecución remota](https://github.com/al140605/barberterraform/actions/runs/40808978959)
aprobó formato, 15 pruebas y análisis estático, pero validate falló en Linux por
hashes de paquete ausentes en los lockfiles. La validación local en Windows no
había descubierto esa diferencia de plataforma.

La [ejecución de diagnóstico](https://github.com/al140605/barberterraform/actions/runs/40809985048)
generó lockfiles con Terraform para Linux y Windows y aprobó validaciones. Se
incorporaron cuatro hashes manteniendo versiones, constraints y hashes anteriores,
y conservando `-lockfile=readonly`. La rama de diagnóstico no se fusionó.
La [ejecución corregida](https://github.com/al140605/barberterraform/actions/runs/40810363096)
aprobó los seis checks sobre `020fdbc`.

La revisión local también comprobó el resumen contra un plan sintético de
`terraform_data`, formato JSON 1.2, sin proveedor de nube ni apply. No fue un plan
de staging ni prueba de permisos sobre recursos reales.

## Checkov: referencia estática del 28-oct-2026

Checkov 3.4.0 produjo 80 resultados aprobados, cero fallos, 107 omisiones y cero
errores de parseo sobre 57 recursos. Había 51 anotaciones inline de 37 IDs; las
omisiones correspondían a 36 controles. Consultar el
[catálogo y su alcance](EXCEPCIONES_CHECKOV.md). Los reportes completos se mantienen
privados por contener código y metadatos; no se publican estados ni planes.

## Ambiente efímero: registro heredado del 16-oct-2026

El registro anterior del repositorio describe dos intentos reales: con grupo de
seguridad opcional, la creación falló en ese recurso por falta de `ec2:CreateTags`
y se retiró lo creado; con `create_security_group=false`, se crearon y retiraron
cuatro recursos. ECR y logs desaparecieron, ECS quedó `INACTIVE` y se registró
estado vacío. También se reportó rechazo de workspace `default`.

Es evidencia histórica trasladada de la guía anterior, **no reproducida ni
recertificada** durante esta revisión. No demuestra permisos actuales, costo cero,
existencia o ausencia actual del bucket, ni retirada de otros entornos.
Antes de repetir el ciclo, seguir [AMBIENTE_EFIMERO.md](AMBIENTE_EFIMERO.md).

## Relación con Sprint 4

| Tarea | Referencia de responsabilidad del backlog | Qué falta acreditar |
| --- | --- | --- |
| T137 | María Isabel Cruz Flores | Cierre formal con evidencia del alcance de validación aceptado. |
| T138 | Alan Ruiz Vilchis | Plan conectado de staging y revisión correspondiente. |
| T124 | Luis | Estado remoto, adopción real y cualquier operación expresamente autorizada. |
| T125 | María | Correspondencia de Atlas y comprobación de integridad autorizada. |
| T126 / TT15 | Miguel | API y clientes en el entorno acordado, con evidencia funcional. |
| TT14 | Luis | Correspondencia con CloudFront real y verificación HTTPS/TLS. |

La coordinación técnica asumida por KikeGonRam en #13/#14 no reasigna estas historias.
Los comentarios de código, YAML y documentos no sustituyen decisiones del equipo.
