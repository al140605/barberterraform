# Documentación de Terraform

Las guías describen el código del repositorio y señalan cuándo una comprobación
necesita evidencia de GitHub o del entorno. Revisión documental: **29-oct-2026**.

## Elegir una guía

| Necesito… | Documento |
| --- | --- |
| Entender el proyecto y hacer la primera comprobación | [README principal](../README.md). |
| Conocer recursos, relaciones, variables y salidas | [Arquitectura e inventario](INFRAESTRUCTURA_STAGING.md). |
| Ejecutar pruebas y análisis sin credenciales | [Pruebas y validación local](PRUEBAS.md). |
| Mantener o revisar los workflows | [CI y operaciones manuales](CI_TERRAFORM.md). |
| Preparar bootstrap, estado o importaciones autorizadas | [Operación de Terraform](OPERACION_TERRAFORM.md). |
| Crear, verificar y retirar un entorno de prueba autorizado | [Ambiente efímero](AMBIENTE_EFIMERO.md). |
| Entender las elecciones técnicas y sus límites | [Decisiones de arquitectura](DECISIONES_ARQUITECTURA.md). |
| Revisar reglas, permisos y coordinación del equipo | [Protecciones de GitHub](PROTECCIONES_GITHUB.md). |
| Revisar omisiones de seguridad del analizador | [Excepciones de Checkov](EXCEPCIONES_CHECKOV.md). |
| Consultar resultados verificables e historial de validación | [Evidencias](EVIDENCIAS.md). |

## Fuentes de verdad

| Información | Fuente |
| --- | --- |
| Recursos, variables y dependencias | Archivos `.tf` de cada raíz. |
| Versiones de proveedores y checksums | `.terraform.lock.hcl` de cada raíz. |
| Eventos, permisos y pasos del pipeline | [.github/workflows](../.github/workflows). |
| Condiciones que deben conservarse al cambiar el pipeline | [Pruebas de seguridad](../tests/test_workflow_security.py). |
| Configuración real de GitHub y estado de tareas | Ajustes del repositorio e issues enlazados; no los payloads preparados. |
| Infraestructura existente e importaciones aplicadas | Plan/estado verificados en el entorno autorizado. No se deducen de CI. |

## Mantener las guías

Actualizar instrucciones junto con el cambio que las invalida. Mantener las
versiones operativas en la guía de CI y enlazarlas desde otras páginas, evitando
tablas duplicadas. Conservar observaciones antiguas con fecha y alcance en
EVIDENCIAS.md; no presentarlas como estado actual.

Los procedimientos operativos conservan requisitos, revisión del resultado y
condiciones para detenerse. Las decisiones que requieran acceso a cuentas,
presupuesto o cambios reales se documentan como pendientes, no como autorizadas.

## Políticas

[Contribución](../CONTRIBUTING.md) · [Seguridad](../SECURITY.md) ·
[Código de conducta](../CODE_OF_CONDUCT.md) · [Licencia](../LICENSING.md).
