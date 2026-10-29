# UrbanBlade · Terraform

[![Validación](https://github.com/al140605/barberterraform/actions/workflows/terraform.yml/badge.svg?branch=main)](https://github.com/al140605/barberterraform/actions/workflows/terraform.yml)

Infraestructura como código para UrbanBlade en **AWS y MongoDB Atlas**. El repositorio
separa el estado compartido, la adopción de recursos de staging y un entorno efímero
de pruebas. Incluye validación sin credenciales y flujos manuales para plan y apply.

## Empezar sin acceso a nube

Requiere Git y Python 3.12. Desde un checkout nuevo:

```powershell
git clone https://github.com/al140605/barberterraform.git
cd barberterraform
python -B -m unittest discover -s tests -p test_plan_summary.py -v
```

Este primer control ejecuta **15 pruebas del resumen de planes** con datos sintéticos.
No instala proveedores, no necesita AWS/Atlas y no aplica infraestructura.
La [guía de pruebas](docs/PRUEBAS.md) explica cómo ejecutar la suite completa de
30 casos, validar las tres raíces y analizar el código.

## Qué contiene

| Ruta | Responsabilidad |
| --- | --- |
| [bootstrap/state](bootstrap/state) | Bucket S3 del estado, cifrado, versionado, bloqueo público y política TLS. |
| [environments/staging](environments/staging) | Declaraciones e importaciones de AWS y Atlas existentes. |
| [environments/ephemeral](environments/ephemeral) | Recursos desechables aislados por workspace `eph-*`. |
| [modules](modules/README.md) | Criterios de modularización futura; no contiene módulos ejecutables. |
| [.github/workflows](.github/workflows) | Validación, plan y apply con permisos separados. |
| [scripts](scripts) y [tests](tests) | Resumen seguro, runner de operaciones y regresiones sin nube. |
| [docs](docs/README.md) | Arquitectura, pruebas, procedimientos, decisiones y evidencias. |

Staging declara ECR, CloudWatch Logs, red, ALB, ECS, contenedores de secretos,
CloudFront, S3 y Atlas. Los bloques de importación **no prueban su incorporación
al estado remoto**. El [inventario](docs/INFRAESTRUCTURA_STAGING.md) detalla alcance,
variables, salidas y recursos que quedan fuera.

## Validación y operaciones

| Flujo | Entrada | Permisos y límites |
| --- | --- | --- |
| **Terraform Validacion** | Todo PR y push a `main`; manual o reutilizable. | Sin secretos ni identidad de nube; seis checks y 30 casos en Linux. |
| **Terraform Plan** | Despacho manual desde `main`. | Revalida; exige `TERRAFORM_PLAN=true` y rol específico de plan. |
| **Terraform Apply** | Despacho manual desde `main`. | Revalida; exige ambas variables en `true`, confirmación y entorno de aprobación. |

Los flujos manuales comparten exclusión mutua sobre staging. Un PR o push nunca
inicia plan ni apply. Los detalles de versiones, permisos y dependencias están en
[CI_TERRAFORM.md](docs/CI_TERRAFORM.md).

En la revisión del **29-oct-2026**, `TERRAFORM_PLAN` y `TERRAFORM_APPLY` permanecen en
`false`. Las protecciones administrativas siguen pendientes del propietario.
Consultar [protecciones y responsabilidades](docs/PROTECCIONES_GITHUB.md) y las
[evidencias](docs/EVIDENCIAS.md) para distinguir código, CI y estado operativo.

## Trabajar con infraestructura

Usar Terraform **1.16.2**, la versión verificada en CI; las raíces declaran mínimo
1.10.0. Conservar los lockfiles de proveedores. Para operaciones conectadas se
requieren identidad, cuenta, backend, workspace y permisos revisados previamente.

Los procedimientos de [bootstrap, estado y adopción de staging](docs/OPERACION_TERRAFORM.md)
y del [ambiente efímero](docs/AMBIENTE_EFIMERO.md) están separados del inicio rápido.
Su documentación no autoriza ejecutar operaciones sobre AWS/Atlas.

Estados, planes, logs sin depurar y credenciales son material privado. Reportar
vulnerabilidades por el canal indicado en [SECURITY.md](SECURITY.md).

## Documentación y colaboración

Consultar el [índice de documentación](docs/README.md), las
[decisiones de arquitectura](docs/DECISIONES_ARQUITECTURA.md) y el
[registro de excepciones de Checkov](docs/EXCEPCIONES_CHECKOV.md).

Los cambios se preparan en una rama y se revisan mediante PR con evidencia del
commit evaluado. Ver [CONTRIBUTING.md](CONTRIBUTING.md) y el
[código de conducta](CODE_OF_CONDUCT.md).

## Licencia

**GNU GPLv3, versión 3 únicamente — GPL-3.0-only.**
El texto íntegro está en [LICENSE](LICENSE); el alcance y los componentes de
terceros se describen en [LICENSING.md](LICENSING.md).
