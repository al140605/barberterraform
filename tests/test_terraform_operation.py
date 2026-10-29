"""Ejercita el runner Bash con Terraform ficticio; jamás usa proveedores reales."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PRIVATE = 'SYNTHETIC_PRIVATE_VALUE'
FAKE = '''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ['FAKE_CALLS'], 'a') as out:
    out.write(json.dumps(args) + '\\n')
mode = os.environ['FAKE_FAILURE']
if args[0] == mode:
    print('SYNTHETIC_PRIVATE_VALUE', file=sys.stderr)
    sys.exit(1)
if args[0] == 'plan':
    target = next(a.split('=', 1)[1] for a in args if a.startswith('-out='))
    pathlib.Path(target).write_text('SYNTHETIC_PRIVATE_VALUE')
    sys.exit(2)
if args[0] == 'show':
    if mode == 'summary':
        print('SYNTHETIC_PRIVATE_VALUE')
    else:
        print(json.dumps({'format_version': '1.2', 'errored': False, 'resource_changes': []}))
'''


@unittest.skipUnless(sys.platform == 'linux', 'El runner de operaciones usa Bash en Linux; CI ejecuta estos casos.')
class TerraformOperationTests(unittest.TestCase):
    def run_operation(self, operation, failure=''):
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            binary = temp / 'bin'
            binary.mkdir()
            fake = binary / 'terraform'
            fake.write_text(FAKE, encoding='utf-8')
            fake.chmod(0o755)
            calls = temp / 'calls.jsonl'
            env = os.environ.copy()
            env.update(PATH=str(binary) + os.pathsep + env['PATH'], RUNNER_TEMP=str(temp),
                       GITHUB_WORKSPACE=str(ROOT), GITHUB_STEP_SUMMARY=str(temp / 'summary.md'),
                       TF_BACKEND_HCL=PRIVATE, FAKE_CALLS=str(calls), FAKE_FAILURE=failure)
            result = subprocess.run(['bash', str(ROOT / 'scripts/terraform_operation.sh'), operation],
                                    cwd=temp, env=env, capture_output=True, text=True)
            self.assertNotIn(PRIVATE, result.stdout + result.stderr)
            self.assertEqual(list(temp.glob('terraform-staging.*')), [])
            recorded = [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
            return result, recorded

    def test_plan_never_applies_and_cleans_sensitive_files(self):
        result, calls = self.run_operation('plan')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[0] for c in calls], ['init', 'plan', 'show'])
        self.assertIn('-lockfile=readonly', calls[0])

    def test_apply_uses_exactly_the_saved_plan(self):
        result, calls = self.run_operation('apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = next(c for c in calls if c[0] == 'plan')
        saved = next(arg.split('=', 1)[1] for arg in plan if arg.startswith('-out='))
        self.assertEqual(calls[-1], ['apply', '-input=false', '-no-color', saved])

    def test_init_failure_never_plans_or_applies(self):
        result, calls = self.run_operation('apply', 'init')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([c[0] for c in calls], ['init'])

    def test_plan_failure_never_applies(self):
        result, calls = self.run_operation('apply', 'plan')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('apply', [c[0] for c in calls])

    def test_show_failure_never_applies(self):
        result, calls = self.run_operation('apply', 'show')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('apply', [c[0] for c in calls])

    def test_invalid_summary_never_applies(self):
        result, calls = self.run_operation('apply', 'summary')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('apply', [c[0] for c in calls])

    def test_apply_error_does_not_publish_private_log(self):
        result, calls = self.run_operation('apply', 'apply')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls[-1][0], 'apply')


if __name__ == '__main__':
    unittest.main()
