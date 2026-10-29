# Protecciones de GitHub y responsabilidades

Repositorio: al140605/barberterraform. Revisión: 28-oct-2026.

## Estado comprobado

KikeGonRam tiene escritura, sin administración. El intento autorizado de configurar
main devolvió HTTP 404 y el de crear staging-aprobacion devolvió HTTP 403 con
Must have admin rights to Repository. No se instalaron esas protecciones.
La lectura 404 de branch protection no demuestra por sí sola ausencia de reglas:
el acceso insuficiente también puede ocultarlas. La lista de rulesets fue vacía.

El workflow está habilitado. TERRAFORM_PLAN=false y TERRAFORM_APPLY=false mantienen
las operaciones conectadas desactivadas. Los PR a main ejecutan todos los controles
sin filtros de rutas, igual que los push a main. La validación se separa de
terraform-plan.yml y terraform-apply.yml, ambos manuales y bloqueados.
El bloqueo independiente de apply ya se incorporó en el PR #15; su separación
en workflows estará vigente cuando se fusione el nuevo cambio.

## Reglas preparadas para main

[main-protection.json](../.github/protections/main-protection.json) exige:

- PR con una aprobación, descarte de revisiones antiguas y aprobación del último
  push por otra persona. La autoría no sustituye la revisión independiente.
- Seis checks de validación satisfactorios y rama actualizada con main.
- Conversaciones resueltas; reglas también para administradores.
- Sin push forzado ni eliminación de la rama.

Se requieren los seis checks de validación, nunca plan/apply: estos últimos se
omiten intencionalmente. No se requiere CODEOWNERS porque no se ha acordado uno.
Los filtros de rutas se eliminan para PR, evitando checks obligatorios pendientes
cuando solo cambia documentación. No usar skip ci en cambios que deban fusionarse.

## Reglas preparadas para staging-aprobacion

[staging-environment.json](../.github/protections/staging-environment.json) configura
revisión por KikeGonRam o al140605, prevención de autoaprobación y sin bypass de
administradores. Basta una aprobación elegible, no se exigen ambas. La persona que
inicie la ejecución necesita la aprobación de la otra. No equivale a una revisión
independiente si alguien usa las dos cuentas; cada persona debe usar su propia identidad.

El entorno usa ramas seleccionadas. Es imprescindible crear además la política
[staging-main-branch.json](../.github/protections/staging-main-branch.json) para
permitir exclusivamente la rama main, sin habilitar tags. Comprobar el resultado
completo antes de considerar cualquier activación.

## Aplicación por una identidad con permisos

Estos comandos modifican ajustes de GitHub, no infraestructura. Los debe ejecutar
el propietario desde su propia sesión; no compartir cuentas, contraseñas ni tokens.
Comprobar la identidad con gh api user y confirmar permisos antes de escribir.

```powershell
gh api --method PUT repos/al140605/barberterraform/branches/main/protection --input .github/protections/main-protection.json
gh api --method PUT repos/al140605/barberterraform/environments/staging-aprobacion --input .github/protections/staging-environment.json
# Consultar políticas antes de agregar main; evitar duplicados.
gh api repos/al140605/barberterraform/environments/staging-aprobacion/deployment-branch-policies
gh api --method POST repos/al140605/barberterraform/environments/staging-aprobacion/deployment-branch-policies --input .github/protections/staging-main-branch.json
```

Tras aplicar, consultar branch protection, el entorno y sus políticas. Confirmar
los seis contextos de check, una aprobación independiente, reglas sin bypass y
solo main sin tags. Conservar evidencia depurada en #13. No ejecutar un apply
para probar las protecciones ni crear un entorno desprotegido desde un workflow.
Los payloads son una propuesta versionada; su presencia no prueba aplicación.

## Responsabilidades de esta preparación

| Actividad | Responsable de coordinación | Límite |
| --- | --- | --- |
| Preparar PR, validar controles y reunir evidencia | Luis / KikeGonRam | No acredita permisos administrativos. |
| Aplicar reglas de GitHub | Propietario al140605 | Pendiente de una sesión autorizada con administración. |
| Acordar responsables y fechas por excepción | Luis / KikeGonRam | Seguimiento en #14; no reasigna historias del backlog. |
| Revisión independiente y autorización de operaciones | Persona distinta de quien solicita el cambio | Debe quedar registrada antes de fusionar/aplicar según corresponda. |

No se configuraron credenciales ni confianza IAM/OIDC. Antes de habilitar plan, configurar AWS_PLAN_ROLE_ARN y AWS_APPLY_ROLE_ARN
como roles separados y revisar identidad AWS, subject OIDC real, permisos de lectura y bloqueo del backend.
Apply requiere revisión operativa propia, protecciones aplicadas, ambas variables
habilitadas expresamente y autorización específica; este mantenimiento no la concede.

## Referencias

- [Seguimiento de protecciones #13](https://github.com/al140605/barberterraform/issues/13).
- [Coordinación de excepciones #14](https://github.com/al140605/barberterraform/issues/14).
- [GitHub: entornos](https://docs.github.com/en/rest/deployments/environments).
- [GitHub: checks obligatorios y filtros](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
