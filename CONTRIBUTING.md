# Contribuir a Terraform de UrbanBlade

Los cambios se preparan en una rama y se revisan por PR hacia `main`. Antes de
empezar, consultar [README](README.md), [documentación](docs/README.md),
[seguridad](SECURITY.md) y el estado de Git. Conservar trabajo ajeno y separar cambios
que tengan alcances o riesgos distintos.

## Preparar un PR

1. Partir de una referencia `main` actualizada y crear una rama específica.
2. Revisar el código, los lockfiles y las guías afectadas. No incorporar estados,
   planes, archivos locales de backend ni credenciales.
3. Comprobar el diff y añadir únicamente rutas revisadas; no usar staging global
   en un árbol con cambios de otras tareas.
4. Crear un commit con autoría humana configurada, sin atribuciones de herramientas.
5. Publicar cuando exista autorización, con título y descripción en español que
   expliquen problema, cambio, evidencia y pendientes.
6. Revisar los seis checks del SHA exacto y la revisión independiente que corresponda.
   No forzar merge ni saltar protecciones; una política preparada no prueba que esté aplicada.

No usar push forzado, reescribir historial publicado o eliminar ramas de otras tareas.
No confundir publicación, CI, fusión y aplicación de infraestructura.

## Evidencia según el cambio

| Cambio | Validación pertinente |
| --- | --- |
| Markdown | Enlaces y anclas locales, ejemplos contrastados con código, formato, conflictos y revisión de secretos. No ejecutar nube para comprobar texto. |
| Workflows o scripts | Pruebas de políticas/runner, sintaxis y CI sobre el SHA nuevo; verificar que PR sigue sin secretos. |
| Recursos Terraform | Formato, validate, análisis y pruebas pertinentes; plan conectado solo con autorización del entorno. |
| Lockfiles/dependencias | Procedencia, versiones/checksums, compatibilidad, diff y CI; no borrar controles para obtener verde. |

Los comandos locales y sus límites están en [PRUEBAS.md](docs/PRUEBAS.md).
Mantener documentación junto con cambios que la invaliden, enlazar fuentes y
registrar observaciones históricas con fecha. Actualizar decisiones cuando cambie
una frontera de gestión, permisos o ciclo de vida.

## Operaciones y seguridad

Un PR aprobado o CI verde no autoriza plan conectado, importación, apply, destroy,
migración de estado ni cambios de IAM. Seguir [OPERACION_TERRAFORM.md](docs/OPERACION_TERRAFORM.md)
y registrar la autorización específica. Los workflows manuales permanecen bloqueados
mientras no se acuerden permisos, protecciones y revisión del plan.

Buscar duplicados antes de abrir [issues](https://github.com/al140605/barberterraform/issues).
Incluir entorno, resultado esperado y criterio de aceptación sin datos privados.
Los reportes de vulnerabilidades siguen [SECURITY.md](SECURITY.md); conducta e
incidentes personales siguen [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Licencia de las contribuciones

El proyecto adopta [GPL-3.0-only](LICENSE). Debes tener derecho a aportar el material
bajo esa licencia y conservar avisos de terceros. No se exige cesión de autoría.
El [alcance de licencia](LICENSING.md) no concede acceso a cuentas o datos ni permiso
para aplicar infraestructura. No modificar el texto oficial de LICENSE al editar guías.
