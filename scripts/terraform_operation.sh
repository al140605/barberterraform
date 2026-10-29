#!/usr/bin/env bash
# Invocado únicamente por jobs manuales protegidos; nunca por validación de PR.
set -euo pipefail
umask 077
operation="${1:-}"
if [[ "$operation" != "plan" && "$operation" != "apply" ]]; then
  echo "Operacion no soportada."
  exit 1
fi
: "${RUNNER_TEMP:?}" "${GITHUB_WORKSPACE:?}" "${GITHUB_STEP_SUMMARY:?}" "${TF_BACKEND_HCL:?}"
plan_dir="$(mktemp -d "$RUNNER_TEMP/terraform-staging.XXXXXX")"
trap 'rm -rf -- "$plan_dir"' EXIT
printf '%s\n' "$TF_BACKEND_HCL" > "$plan_dir/backend.hcl"
if ! terraform init -input=false -lockfile=readonly -backend-config="$plan_dir/backend.hcl" > "$plan_dir/init.log" 2>&1; then
  echo "Fallo la inicializacion; revisar configuracion en un canal privado."
  exit 1
fi
code=0
terraform plan -input=false -no-color -detailed-exitcode -out="$plan_dir/staging.tfplan" > "$plan_dir/plan.log" 2>&1 || code=$?
if [[ "$code" -ne 0 && "$code" -ne 2 ]]; then
  echo "Fallo el plan; no se publica su log."
  exit 1
fi
if ! terraform show -json "$plan_dir/staging.tfplan" > "$plan_dir/plan.json" 2> "$plan_dir/show.log"; then
  echo "No se pudo leer el plan para resumirlo."
  exit 1
fi
python3 "$GITHUB_WORKSPACE/scripts/summarize_plan.py" < "$plan_dir/plan.json" >> "$GITHUB_STEP_SUMMARY"
if [[ "$operation" == "apply" ]]; then
  if ! terraform apply -input=false -no-color "$plan_dir/staging.tfplan" > "$plan_dir/apply.log" 2>&1; then
    echo "Fallo apply; no se publica su log."
    exit 1
  fi
  printf '%s\n' 'Apply termino correctamente. Verificar el entorno antes de declarar una entrega.' >> "$GITHUB_STEP_SUMMARY"
fi
