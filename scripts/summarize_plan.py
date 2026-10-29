#!/usr/bin/env python3
"""Render a value-free Markdown summary from terraform show -json on stdin."""
import html
import json
import re
import sys

LABELS = {
    ("no-op",): "Sin acciones",
    ("create",): "Crear",
    ("update",): "Actualizar",
    ("delete",): "Eliminar",
    ("read",): "Leer",
    ("forget",): "Retirar del estado",
    ("delete", "create"): "Reemplazar (eliminar y crear)",
    ("create", "delete"): "Reemplazar (crear y eliminar)",
    ("create", "forget"): "Reemplazar (crear y retirar del estado)",
}


class PlanError(ValueError):
    """Invalid input; messages must never include plan values."""


def action_label(change):
    if not isinstance(change, dict):
        raise PlanError("Cambio de recurso inválido.")
    actions = change.get("actions")
    if not isinstance(actions, list) or not all(isinstance(a, str) for a in actions):
        raise PlanError("Lista de acciones inválida.")
    key = tuple(actions)
    if key not in LABELS:
        raise PlanError("Acciones no soportadas; revisar el formato de Terraform.")
    label = LABELS[key]
    if "importing" in change:
        if not isinstance(change["importing"], dict):
            raise PlanError("Importación inválida.")
        return "Importar" if key == ("no-op",) else "Importar + " + label.lower()
    return None if key == ("no-op",) else label


def safe_address(value):
    if not isinstance(value, str) or not value or len(value) > 2000:
        raise PlanError("Dirección de recurso inválida.")
    # String instance keys can contain user/account names. Keep only the structure.
    value = re.sub(r'\["(?:\\.|[^"\\])*"\]', '["clave"]', value)
    value = "".join(c if ord(c) >= 32 else " " for c in value)
    return html.escape(value, quote=False).replace("|", "&#124;").replace("`", "&#96;")


def summarize(document):
    if not isinstance(document, dict):
        raise PlanError("El plan debe ser un objeto JSON.")
    version = document.get("format_version")
    if not isinstance(version, str) or version.split(".")[0] != "1":
        raise PlanError("Versión del formato de plan no soportada.")
    if document.get("errored"):
        raise PlanError("Terraform indicó que el plan tiene errores.")
    resources = document.get("resource_changes", [])
    outputs = document.get("output_changes", {})
    drift = document.get("resource_drift", [])
    if not isinstance(resources, list) or not isinstance(outputs, dict) or not isinstance(drift, list):
        raise PlanError("Estructura de cambios inválida.")

    rows = []
    for resource in resources:
        if not isinstance(resource, dict):
            raise PlanError("Recurso inválido.")
        label = action_label(resource.get("change"))
        if label:
            rows.append((safe_address(resource.get("address")), label))
    output_count = sum(action_label(change) is not None for change in outputs.values())
    lines = [
        "## Plan de Terraform · staging",
        "",
        "Resumen de acciones; se omiten valores, IDs de importación y claves de instancia.",
        "",
    ]
    if document.get("complete") is False:
        lines += ["Plan incompleto: revisar límites y acciones diferidas antes de aprobar.", ""]
    if rows:
        lines += ["| Recurso | Acción |", "| --- | --- |"]
        lines += [f"| `{address}` | {label} |" for address, label in rows]
        lines += [""]
    else:
        lines += ["Sin acciones sobre recursos en este plan.", ""]
    lines += [
        f"Recursos con acciones o importaciones: {len(rows)}.",
        f"Outputs con cambios: {output_count}.",
        f"Recursos con drift detectado: {len(drift)}.",
        "",
        "Este resumen no aplica cambios ni acredita un despliegue o permisos remotos.",
        "",
    ]
    return "\n".join(lines)


def main():
    try:
        document = json.load(sys.stdin)
        text = summarize(document)
    except (ValueError, OSError, UnicodeError):
        print("No se pudo resumir el plan; revisar el formato en un entorno privado.", file=sys.stderr)
        return 1
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
