"""Regresiones de límites de confianza del pipeline; no acceden a la nube."""

from pathlib import Path
import re
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]


def workflow(filename):
    # BaseLoader conserva 'on' y booleanos como strings, evitando YAML 1.1.
    return yaml.load((ROOT / '.github/workflows' / filename).read_text(encoding='utf-8'), Loader=yaml.BaseLoader)


class WorkflowSecurityTests(unittest.TestCase):
    def test_pr_validation_has_no_cloud_identity_or_secrets(self):
        doc = workflow('terraform.yml')
        self.assertEqual(doc['permissions'], {'contents': 'read'})
        text = (ROOT / '.github/workflows/terraform.yml').read_text(encoding='utf-8')
        self.assertNotIn('secrets.', text)
        self.assertNotIn('id-token:', text)
        self.assertNotIn('terraform_operation.sh', text)
        self.assertNotIn('configure-aws-credentials', text)
        self.assertNotIn('environment', doc)

    def test_all_prs_are_validated_without_path_filters(self):
        doc = workflow('terraform.yml')
        self.assertEqual(doc['on']['pull_request'], {'branches': ['main']})
        self.assertIn('workflow_call', doc['on'])
        self.assertNotIn('workflow_run', doc['on'])

    def test_cloud_workflows_are_manual_and_revalidate_without_inherited_secrets(self):
        for filename in ('terraform-plan.yml', 'terraform-apply.yml'):
            with self.subTest(filename=filename):
                doc = workflow(filename)
                self.assertEqual(set(doc['on']), {'workflow_dispatch'})
                self.assertEqual(doc['permissions'], {'contents': 'read'})
                call = doc['jobs']['validacion']
                self.assertEqual(call['uses'], './.github/workflows/terraform.yml')
                self.assertEqual(call['permissions'], {'contents': 'read'})
                self.assertNotIn('secrets', call)
                self.assertNotIn('secrets: inherit', str(doc))

    def test_cloud_jobs_require_main_flags_and_successful_validation(self):
        for operation in ('plan', 'apply'):
            doc = workflow(f'terraform-{operation}.yml')
            job = doc['jobs'][operation]
            self.assertEqual(job['needs'], 'validacion')
            for guarded in (job, doc['jobs']['validacion']):
                condition = guarded['if']
                self.assertIn("github.ref == 'refs/heads/main'", condition)
                self.assertIn("vars.TERRAFORM_PLAN == 'true'", condition)
                self.assertNotIn('||', condition)
                if operation == 'apply':
                    self.assertIn("vars.TERRAFORM_APPLY == 'true'", condition)
                    self.assertIn("inputs.confirmar == 'APLICAR staging'", condition)
            self.assertEqual(job['permissions'], {'contents': 'read', 'id-token': 'write'})

    def test_apply_requires_environment_and_uses_a_separate_role(self):
        plan = workflow('terraform-plan.yml')['jobs']['plan']
        apply = workflow('terraform-apply.yml')['jobs']['apply']
        self.assertEqual(apply['environment'], 'staging-aprobacion')
        for job, role in ((plan, 'AWS_PLAN_ROLE_ARN'), (apply, 'AWS_APPLY_ROLE_ARN')):
            aws = [step for step in job['steps'] if step.get('uses', '').startswith('aws-actions/')]
            self.assertEqual(len(aws), 1)
            self.assertEqual(aws[0]['with']['role-to-assume'], '${{ secrets.' + role + ' }}')

    def test_operations_share_serialization_but_validation_has_its_own_group(self):
        plan = workflow('terraform-plan.yml')['concurrency']
        apply = workflow('terraform-apply.yml')['concurrency']
        self.assertEqual(plan, apply)
        self.assertEqual(plan['cancel-in-progress'], 'false')
        self.assertNotEqual(plan['group'], workflow('terraform.yml')['concurrency']['group'])

    def test_external_actions_are_pinned_and_cloud_files_are_not_uploaded(self):
        for path in (ROOT / '.github/workflows').glob('*.yml'):
            doc = workflow(path.name)
            for job in doc['jobs'].values():
                for step in job.get('steps', []):
                    uses = step.get('uses', '')
                    if uses and not uses.startswith('./'):
                        self.assertRegex(uses, r'^[\w.-]+/[\w.-]+@[a-f0-9]{40}$')
                        self.assertNotIn('upload-artifact', uses)
        self.assertEqual(yaml.load((ROOT / '.github/dependabot.yml').read_text(encoding='utf-8'), Loader=yaml.BaseLoader)['version'], '2')

    def test_required_validation_check_names_remain_compatible(self):
        doc = workflow('terraform.yml')
        names = []
        for job in doc['jobs'].values():
            if 'strategy' in job:
                for directory in job['strategy']['matrix']['dir']:
                    names.append(job['name'].replace('${{ matrix.dir }}', directory))
            else:
                names.append(job['name'])
        import json
        protection = json.loads((ROOT / '.github/protections/main-protection.json').read_text(encoding='utf-8'))
        self.assertEqual(set(protection['required_status_checks']['contexts']), set(names))


if __name__ == '__main__':
    unittest.main()
