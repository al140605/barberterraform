"""Regression tests for the public Terraform plan summary (T138)."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "summarize_plan.py"
spec = importlib.util.spec_from_file_location("summary", SCRIPT)
summary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(summary)


def plan(*resources, **extra):
    return {"format_version": "1.2", "resource_changes": list(resources), **extra}


def resource(address, actions, importing=None):
    change = {"actions": actions, "before": {"password": "PRIVATE_TEST_VALUE"},
              "after": {"password": "PRIVATE_TEST_VALUE"}}
    if importing:
        change["importing"] = {"id": importing}
    return {"address": address, "change": change}


class PlanSummaryTests(unittest.TestCase):
    def test_import_with_noop_is_not_reported_as_no_changes(self):
        result = summary.summarize(plan(resource("aws_s3_bucket.existing", ["no-op"], "PRIVATE_IMPORT_ID")))
        self.assertIn("Importar", result)
        self.assertNotIn("Sin acciones", result)
        self.assertNotIn("PRIVATE_IMPORT_ID", result)
        self.assertNotIn("PRIVATE_TEST_VALUE", result)

    def test_import_and_update_are_both_visible(self):
        result = summary.summarize(plan(resource("aws_s3_bucket.existing", ["update"], "PRIVATE_IMPORT_ID")))
        self.assertIn("Importar + actualizar", result)

    def test_replacements_are_distinct_from_simple_updates(self):
        for actions in (["delete", "create"], ["create", "delete"]):
            with self.subTest(actions=actions):
                self.assertIn("Reemplazar", summary.summarize(plan(resource("aws_s3_bucket.changed", actions))))

    def test_empty_plan_does_not_claim_remote_infrastructure_is_verified(self):
        result = summary.summarize(plan())
        self.assertIn("Sin acciones sobre recursos", result)
        self.assertNotIn("coincide", result)

    def test_output_only_change_is_counted_without_name_or_value(self):
        result = summary.summarize(plan(output_changes={
            "PRIVATE_OUTPUT_NAME": {"actions": ["update"], "after": "PRIVATE_OUTPUT_VALUE"}}))
        self.assertIn("Outputs con cambios: 1", result)
        self.assertNotIn("PRIVATE_OUTPUT", result)

    def test_drift_is_counted_without_values(self):
        result = summary.summarize(plan(resource_drift=[{"change": {"after": "PRIVATE_DRIFT"}}]))
        self.assertIn("Recursos con drift detectado: 1", result)
        self.assertNotIn("PRIVATE_DRIFT", result)

    def test_string_instance_keys_are_redacted(self):
        result = summary.summarize(plan(resource(
            'module.team["PRIVATE_ACCOUNT"].aws_iam_user.user["PRIVATE_USER"]', ["update"])))
        self.assertNotIn("PRIVATE_ACCOUNT", result)
        self.assertNotIn("PRIVATE_USER", result)
        self.assertIn("clave", result)

    def test_metadata_cannot_inject_html_or_markdown_rows(self):
        result = summary.summarize(plan(resource("aws_test.x<script>\n|BAD\x60", ["create"])))
        self.assertNotIn("<script>", result)
        self.assertNotIn("\n|BAD", result)
        self.assertNotIn("|BAD", result)

    def test_unknown_actions_fail_closed(self):
        with self.assertRaises(summary.PlanError):
            summary.summarize(plan(resource("aws_test.x", ["unknown-action"])))

    def test_invalid_or_errored_plan_is_rejected(self):
        for value in ([], {}, plan(errored=True), plan(resource_changes={}), plan(output_changes=[])):
            with self.subTest(value=value):
                with self.assertRaises(summary.PlanError):
                    summary.summarize(value)

    def test_noop_resources_do_not_hide_real_changes(self):
        result = summary.summarize(plan(
            resource("aws_test.unchanged", ["no-op"]),
            resource("aws_test.created", ["create"]),
            resource("aws_test.deleted", ["delete"])))
        self.assertNotIn("aws_test.unchanged", result)
        self.assertIn("Crear", result)
        self.assertIn("Eliminar", result)

    def test_forget_is_not_described_as_deletion(self):
        result = summary.summarize(plan(resource("aws_test.detached", ["forget"])))
        self.assertIn("Retirar del estado", result)
        self.assertNotIn("Eliminar", result)

    def test_incomplete_plan_is_identified(self):
        self.assertIn("Plan incompleto", summary.summarize(plan(complete=False)))

    def test_cli_invalid_json_does_not_echo_input(self):
        run = subprocess.run([sys.executable, str(SCRIPT)], input="PRIVATE_BAD_INPUT",
                             capture_output=True, text=True)
        self.assertNotEqual(0, run.returncode)
        self.assertNotIn("PRIVATE_BAD_INPUT", run.stdout + run.stderr)

    def test_cli_accepts_a_synthetic_plan_without_cloud_access(self):
        run = subprocess.run([sys.executable, str(SCRIPT)],
                             input=json.dumps(plan(resource("aws_test.sample", ["create"]))),
                             capture_output=True, text=True)
        self.assertEqual(0, run.returncode, run.stderr)
        self.assertIn("Crear", run.stdout)


if __name__ == "__main__":
    unittest.main()
