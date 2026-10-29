# Pruebas y validación sin nube

Esta guía cubre comprobaciones de código. Ningún resultado equivale a un plan
conectado, una importación aplicada o una comprobación funcional de UrbanBlade.

## Requisitos

| Herramienta | Uso |
| --- | --- |
| Python 3.12 | Suite del resumen, políticas del workflow y runner simulado. |
| Terraform 1.16.2 | Formato, validación y prueba mock; versión fijada en CI. |
| tflint y Checkov | Análisis de estilo y seguridad; versiones en [CI](CI_TERRAFORM.md). |
| Bash en Linux | Siete regresiones del runner de operaciones. |

Las descargas de dependencias y proveedores necesitan red, pero estas pruebas no
necesitan credenciales AWS/Atlas ni el backend remoto. Usar un checkout de revisión
sin estados, archivos `backend.hcl`, overrides ni credenciales heredadas.

## Suite Python

El resumen de planes usa solo la biblioteca estándar:

```powershell
python -B -m unittest discover -s tests -p test_plan_summary.py -v
```

Para la suite completa, crear un entorno virtual fuera del checkout. Desde la raíz
del repositorio, en PowerShell:

```powershell
$testVenv = Join-Path $env:TEMP 'urbanblade-terraform-tests'
python -m venv $testVenv
$testPython = Join-Path $testVenv 'Scripts/python.exe'
& $testPython -m pip install -r .github/requirements-tests.txt
& $testPython -B -m unittest discover -s tests -v
```

En Linux, usar un entorno virtual propio y su intérprete:

```bash
python3 -m venv /tmp/urbanblade-terraform-tests
/tmp/urbanblade-terraform-tests/bin/python -m pip install -r .github/requirements-tests.txt
/tmp/urbanblade-terraform-tests/bin/python -B -m unittest discover -s tests -v
```

| Archivo | Casos | Qué verifica |
| --- | ---: | --- |
| [test_plan_summary.py](../tests/test_plan_summary.py) | 15 | Importaciones no-op, reemplazos, drift, outputs, datos sensibles y errores de formato. |
| [test_workflow_security.py](../tests/test_workflow_security.py) | 8 | Aislamiento de credenciales, eventos, guardas, roles, concurrencia, SHA de Actions y nombres de checks. |
| [test_terraform_operation.py](../tests/test_terraform_operation.py) | 7 | Runner Bash con Terraform ficticio: limpieza, errores privados y aplicación del mismo archivo generado. |

En Windows son ejecutables 23 casos y se omiten los siete específicos de Linux.
En CI Linux se ejecutan los 30; comprobar la conclusión, no solo el conteo. Los tests del runner llaman un ejecutable ficticio;
no crean recursos, aunque sus argumentos contengan `plan` o `apply`.

## Formato y validación de Terraform

Comprobar primero el formato, sin inicializar nada:

```powershell
terraform fmt -check -recursive
```

Para validate, usar un checkout limpio dedicado a revisión y retirar del proceso
credenciales `AWS_*`, claves de Atlas y valores `TF_VAR_*` heredados. Mantener
configuración de AWS aislada y `AWS_EC2_METADATA_DISABLED=true`. No reutilizar
`.terraform` de un checkout operativo ni migrar su backend para estas pruebas.

```powershell
terraform -chdir=bootstrap/state init -backend=false -input=false -lockfile=readonly
terraform -chdir=bootstrap/state validate
terraform -chdir=environments/staging init -backend=false -input=false -lockfile=readonly
terraform -chdir=environments/staging validate
terraform -chdir=environments/ephemeral init -backend=false -input=false -lockfile=readonly
terraform -chdir=environments/ephemeral validate
```

`-backend=false` omite la inicialización del backend, no es una modalidad para
aplicar recursos. `-lockfile=readonly` conserva versiones y checksums.

La prueba del ambiente efímero usa proveedor mock y requiere workspace `default`.
Comprobar la selección en ese checkout aislado antes de ejecutarla:

```powershell
terraform -chdir=environments/ephemeral workspace show
terraform -chdir=environments/ephemeral test
```

La prueba comprueba que la guarda rechaza `default`; no demuestra que un workspace
real esté creado, vacío o retirado en AWS.

## Análisis estático

Instalar Checkov en un entorno virtual propio con
[requirements-security.txt](../.github/requirements-security.txt). Desde la raíz:

```powershell
tflint --init --config="$PWD/.tflint.hcl"
tflint --chdir=bootstrap/state --config="$PWD/.tflint.hcl"
tflint --chdir=environments/staging --config="$PWD/.tflint.hcl"
tflint --chdir=environments/ephemeral --config="$PWD/.tflint.hcl"
checkov --config-file .checkov.yaml
```

CI trata los errores de tflint como fallos; revisar también sus advertencias.
Checkov conserva las excepciones inline: ver su [catálogo](EXCEPCIONES_CHECKOV.md).
Un análisis sin fallos con omisiones no certifica ausencia de riesgos.

## Revisar un cambio exclusivamente documental

Comprobar enlaces locales y anclas, nombres de archivos, ejemplos, bloques de código,
UTF-8 y ausencia de marcadores de conflicto. Revisar el diff y escanear los documentos
salientes para detectar credenciales. No ejecutar operaciones de nube para validar texto.
CI corre igualmente en todos los PR; comprobar el SHA y conclusión de sus seis jobs.

Los [resultados históricos](EVIDENCIAS.md) aportan referencias, no sustituyen la
validación del commit que se desea incorporar.
