#!/usr/bin/env python3
"""Boot both immutable AMD64 runtime images against positively owned MySQL."""
import argparse
import json
import os
import pathlib
import re
import secrets
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'test/runtime/deployment_images'))
from resources import cleanup_resources, present
MYSQL = 'mysql@sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242'
PASSWORD = 'synthetic-image-runtime-only'
PORT = 13363
ROLES = ('primary', 'queue', 'cache', 'cable')
AWS_CALLS = {'ssm.get_parameters_by_path': 1, 'cloudformation.list_exports': 1,
             'secretsmanager.list_secrets': 1, 'secretsmanager.get_secret_value': 1}


def validate_receipt(receipt, ruby, minimums, databases):
    """Refuse incomplete observations independently of the child's exit status."""
    runtime = receipt.get('runtime', {})
    if (receipt.get('boot') != 'production' or receipt.get('image_mode') is not True or
            receipt.get('eager_load') is not True or runtime.get('ruby') != ruby['version'] or
            runtime.get('patchlevel') != ruby['patchlevel'] or
            not runtime.get('platform', '').startswith('x86_64-linux')):
        raise RuntimeError('Production AMD64/Ruby boot identity differs')
    extensions = runtime.get('extensions', {})
    if set(extensions) != {'mysql2', 'bootsnap'} or any(
            not value.get('path', '').endswith('.so') or
            not re.fullmatch('[a-f0-9]{64}', value.get('sha256', '')) for value in extensions.values()):
        raise RuntimeError('Loaded native extension identities are missing')
    for name, minimum in minimums.items():
        version = receipt.get('versions', {}).get(name, '')
        if name == 'rubyzip' and version == 'absent from runtime bundle':
            continue
        if not re.fullmatch(r'\d+(?:\.\d+)*', version) or tuple(map(int, version.split('.'))) < tuple(map(int, minimum.split('.'))):
            raise RuntimeError('Runtime gem is missing or below its patched floor')
    if [(value.get('path'), value.get('status')) for value in receipt.get('requests', [])] != [('/', 200), ('/up', 200)]:
        raise RuntimeError('Production home/health response failed')
    if receipt.get('aws_requests') != AWS_CALLS:
        raise RuntimeError('Authored SDK bootstrap call inventory differs')
    if sorted(value.get('name', '') for value in receipt.get('databases', [])) != sorted(databases):
        raise RuntimeError('Runtime database identity inventory differs')


class RuntimeImages:
    """One isolated network namespace, volume and owned child per observation."""
    def __init__(self, reports):
        self.nonce = secrets.token_hex(8)
        self.name = 'railsstarter-image-runtime-' + self.nonce
        self.volume = self.name + '-data'
        self.cid = None
        self.children = {}
        self.pending = set()
        self.volume_created = False
        self.endpoint = None
        self.reports = reports
        self.report = {'nonce': self.nonce, 'images': [], 'success': False, 'cleanup': {}}
        self.env = {key: os.environ[key] for key in ('PATH', 'HOME', 'TMPDIR', 'DOCKER_HOST', 'DOCKER_CONTEXT') if key in os.environ}

    def command(self, *args, timeout=30, check=True):
        if self.endpoint:
            args = ('docker', '--host', self.endpoint, *args)
        else:
            args = ('docker', *args)
        result = subprocess.run(args, env=self.env, capture_output=True, text=True, timeout=timeout)
        if check and result.returncode:
            raise RuntimeError('Docker operation failed: ' + result.stderr[-2000:])
        return result

    def inspect(self, *args):
        return json.loads(self.command(*args).stdout)

    def preflight(self, images):
        if self.env.get('DOCKER_HOST') and not self.env['DOCKER_HOST'].startswith('unix:///'):
            raise RuntimeError('Local Docker Unix socket required')
        context = self.env.get('DOCKER_CONTEXT') or self.command('context', 'show').stdout.strip()
        endpoint = self.inspect('context', 'inspect', context)[0]['Endpoints']['docker']['Host']
        if not endpoint.startswith('unix:///') or not pathlib.Path(endpoint[7:]).is_socket():
            raise RuntimeError('Local Docker Unix socket required')
        self.endpoint = endpoint
        self.command('info', '--format', '{{.ServerVersion}}')
        resolved = []
        for image in images:
            observed = self.inspect('image', 'inspect', image)[0]
            if observed['Architecture'] != 'amd64' or observed['Os'] != 'linux':
                raise RuntimeError('Both actual deployment images must be Linux AMD64')
            resolved.append(observed['Id'])
        self.command('pull', MYSQL, timeout=300)
        observed = self.inspect('image', 'inspect', MYSQL)[0]
        if MYSQL not in observed['RepoDigests']:
            raise RuntimeError('Installed MySQL digest differs')
        return resolved

    def owned_database(self):
        observed = self.inspect('inspect', self.cid)[0]
        mounts = observed['Mounts']
        if (observed['Config']['Labels'].get('runtime-image.nonce') != self.nonce or
                observed['Config']['Image'] != MYSQL or observed['HostConfig']['NetworkMode'] != 'none' or
                len(mounts) != 1 or mounts[0].get('Name') != self.volume or
                mounts[0]['Destination'] != '/var/lib/mysql'):
            raise RuntimeError('MySQL resource ownership differs')
        return observed

    def mysql(self, sql, check=True):
        self.owned_database()
        return self.command('exec', self.cid, 'mysql', '-h127.0.0.1', f'-P{PORT}', '-uroot',
                            f'-p{PASSWORD}', '-NBe', sql, check=check)

    def provision(self):
        if present(self, 'volume', self.volume) or present(self, 'container', self.name):
            raise RuntimeError('Resource name already exists')
        self.volume_created = True
        self.pending.add(self.volume)
        self.command('volume', 'create', '--label', 'runtime-image.nonce=' + self.nonce, self.volume)
        self.pending.discard(self.volume)
        self.cid = self.name
        self.pending.add(self.name)
        allocated = self.command('run', '-d', '--name', self.name, '--hostname', self.name,
                                '--label', 'runtime-image.nonce=' + self.nonce, '--network', 'none',
                                '-v', self.volume + ':/var/lib/mysql', '-e', 'MYSQL_ROOT_PASSWORD=' + PASSWORD,
                                MYSQL, f'--port={PORT}').stdout.strip()
        if not re.fullmatch('[a-f0-9]{64}', allocated):
            raise RuntimeError('MySQL allocation returned no valid container identity')
        self.cid = allocated
        self.pending.discard(self.name)
        deadline = time.monotonic() + 120
        while True:
            result = self.mysql('SELECT VERSION(),@@server_uuid,@@hostname,@@port', check=False)
            if result.returncode == 0:
                identity = result.stdout.strip().split('\t')
                if identity[0] != '8.4.11' or identity[2:] != [self.name, str(PORT)]:
                    raise RuntimeError('Authenticated MySQL identity differs')
                self.report['mysql_identity'] = identity
                return
            if time.monotonic() >= deadline:
                raise RuntimeError('Owned MySQL readiness timeout')
            time.sleep(.25)

    def boot(self, image, index):
        prefix = f'railsstarter_63_smoke_{self.nonce}_{index}'
        databases = [prefix if role == 'primary' else prefix + '_' + role for role in ROLES]
        user = 'image_runtime_' + str(index)
        self.mysql(f"CREATE USER '{user}'@'%' IDENTIFIED BY '{PASSWORD}'")
        for database in databases:
            self.mysql(f"CREATE DATABASE `{database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; "
                       f"GRANT ALL ON `{database}`.* TO '{user}'@'%'")
        grants = self.mysql(f"SHOW GRANTS FOR '{user}'@'%'").stdout.splitlines()
        if len(grants) != 5 or any('*.*' in grant and 'USAGE' not in grant for grant in grants):
            raise RuntimeError('Four-schema least-privilege grants differ')
        environment = {'RAILS_ENV': 'production', 'RACK_ENV': 'production', 'RUNTIME_SMOKE_IMAGE': '1',
                       'RUNTIME_SMOKE_DB': '1', 'DATABASE_NAME': prefix, 'PRIMARY_DB_HOST': '127.0.0.1',
                       'DATABASE_REPLICA_HOST': '127.0.0.1', 'DATABASE_PORT': str(PORT),
                       'DATABASE_USER': user, 'DATABASE_PASSWORD': PASSWORD,
                       'DATABASE_SSL': 'false', 'DATABASE_IAM_AUTH': 'false', 'ALLOWED_HOSTS': 'example.org',
                       'ACTIVE_STORAGE_PRODUCTION_BUCKET': 'authored-runtime-image-only',
                       'ACTIVE_STORAGE_S3_REGION': 'us-east-1'}
        name = self.name + '-' + str(index)
        args = ['create', '--name', name, '--label', 'runtime-image.nonce=' + self.nonce,
                '--network', 'container:' + self.cid]
        for key, value in environment.items():
            args += ['-e', key + '=' + value]
        args += [image, 'bundle', 'exec', 'ruby', 'spec/fixtures/runtime/smoke.rb']
        cid = self.create_child(args, image, name)
        self.owned_child(cid)
        result = self.command('start', '--attach', cid, timeout=180, check=False)
        observed = self.owned_child(cid)
        case = {'image_id': image, 'exit': observed['State']['ExitCode'], 'stdout': result.stdout,
                'stderr': result.stderr, 'databases': databases, 'grants': grants}
        self.report['images'].append(case)
        if result.returncode or observed['State']['Running'] or case['exit'] != 0:
            raise RuntimeError('Actual runtime image smoke failed')
        lines = [line for line in result.stdout.splitlines() if line.startswith('{"runtime_smoke_result":')]
        if len(lines) != 1:
            raise RuntimeError('Actual runtime image receipt is missing or ambiguous')
        receipt = json.loads(lines[0])['runtime_smoke_result']
        fixture = json.loads((ROOT / 'spec/fixtures/runtime/acceptance.json').read_text())
        validate_receipt(receipt, fixture['ruby_runtime'], fixture['minimum_versions'], databases)
        case['receipt'] = receipt
        self.reject_wrong_bootstrap(image, index, args, case)

    def reject_wrong_bootstrap(self, image, index, args, case):
        name = self.name + '-negative-' + str(index)
        recipe = list(args[:-5])
        recipe[recipe.index('--name') + 1] = name
        code = ('require "./spec/fixtures/runtime/smoke"; '
                'DependencySmoke::FIXTURE.fetch("aws").fetch("ssm").fetch("get_parameters_by_path")'
                '.fetch("parameters").first["value"] = "wrong-authored-response"; DependencySmoke.run')
        recipe += [image, 'bundle', 'exec', 'ruby', '-e', code]
        cid = self.create_child(recipe, image, name)
        self.owned_child(cid)
        result = self.command('start', '--attach', cid, timeout=180, check=False)
        observed = self.owned_child(cid)
        case['negative_bootstrap'] = {'exit': observed['State']['ExitCode'],
                                     'stdout': result.stdout, 'stderr': result.stderr}
        if (result.returncode != 1 or observed['State']['Running'] or observed['State']['ExitCode'] != 1 or
                'Authored SSM fixture was not consumed' not in result.stderr):
            raise RuntimeError('Corrupted SDK response did not reach its expected refusal')

    def create_child(self, recipe, image, name):
        if present(self, 'container', name):
            raise RuntimeError('Runtime resource name already exists')
        self.children[name] = image
        self.pending.add(name)
        self.command(*recipe)
        self.pending.discard(name)
        return name

    def owned_child(self, cid):
        observed = self.inspect('inspect', cid)[0]
        if (observed['Config']['Labels'].get('runtime-image.nonce') != self.nonce or
                observed['Config']['Image'] != self.children[cid] or observed['Mounts'] or
                observed['HostConfig']['NetworkMode'] != 'container:' + self.cid):
            raise RuntimeError('Runtime child ownership differs')
        return observed

    def cleanup(self):
        cleanup_resources(self)

    def run(self, images):
        try:
            identities = self.preflight(images)
            self.provision()
            for index, image in enumerate(identities):
                self.boot(image, index)
            self.report['success'] = True
        except Exception as error:
            self.report['error'] = str(error)
        finally:
            try:
                self.cleanup()
            except Exception as error:
                self.report['success'] = False
                self.report['cleanup']['error'] = str(error)
            self.reports.mkdir(parents=True, exist_ok=True)
            (self.reports / 'runtime-images.json').write_text(json.dumps(self.report, indent=2) + '\n')
        print(json.dumps({'success': self.report['success'], 'report': str(self.reports / 'runtime-images.json')}))
        return 0 if self.report['success'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--web-image', required=True)
    parser.add_argument('--worker-image', required=True)
    parser.add_argument('--report-directory', type=pathlib.Path, required=True)
    args = parser.parse_args()
    return RuntimeImages(args.report_directory).run([args.web_image, args.worker_image])


if __name__ == '__main__':
    raise SystemExit(main())
