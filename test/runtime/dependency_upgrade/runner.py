"""Run dependency boundaries on a uniquely owned, digest-pinned MySQL server.

The optional baseline uses a separately installed frozen Gemfile. Neither path
loads schemas over preservation witnesses. Every child and volume is owned by
this invocation, including when a boundary fails.
"""
import argparse
import hashlib
import json
import os
import pathlib
import secrets
import shutil
import signal
import socket
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[3]
IMAGE = 'mysql@sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242'
PASSWORD = 'synthetic-80-owned-only'
ROLES = ('primary', 'queue', 'cache', 'cable')


class OwnedUpgrade:
    """Own the physical server and retain failed probes with positive cleanup."""

    def __init__(self):
        self.nonce = secrets.token_hex(6)
        self.name = f'railsstarter80-{self.nonce}'
        self.volume = self.name + '-data'
        self.cid = None
        self.volume_created = False
        self.child = None
        self.scratch = None
        self.endpoint = None
        self.groups = []
        self.private_ignored = False
        self.report = {'nonce': self.nonce, 'commands': [], 'success': False, 'cleanup': {}}

    def environment(self):
        keys = ('HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'PATH', 'GEM_HOME', 'GEM_PATH',
                'BUNDLE_PATH', 'BUNDLE_APP_CONFIG', 'BUNDLE_USER_HOME',
                'BUNDLE_FROZEN', 'BUNDLE_BUILD__MYSQL2', 'BUNDLER_VERSION')
        return {key: os.environ[key] for key in keys if key in os.environ}

    def invoke(self, command, timeout=30, env=None, check=True):
        if command[0] == 'docker' and self.endpoint:
            command = ['docker', '--host', self.endpoint, *command[1:]]
        self.child = subprocess.Popen(command, cwd=ROOT, env=env or self.environment(),
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                      text=True, start_new_session=True)
        pid = self.child.pid
        try:
            output, error = self.child.communicate(timeout=timeout)
            code = self.child.returncode
        except BaseException:
            os.killpg(pid, signal.SIGTERM)
            try:
                output, error = self.child.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(pid, signal.SIGKILL)
                output, error = self.child.communicate(timeout=5)
            self.report['commands'].append({'command': command, 'exit': self.child.returncode,
                                            'stdout': output, 'stderr': error, 'interrupted': True})
            raise
        finally:
            self.child = None
            try:
                os.killpg(pid, 0)
                os.killpg(pid, signal.SIGKILL)
                absent = False
            except ProcessLookupError:
                absent = True
            self.groups.append({'pid': pid, 'absent': absent})
        self.report['commands'].append({'command': command, 'exit': code,
                                        'stdout': output, 'stderr': error})
        if check and code:
            raise RuntimeError(f'Boundary failed: {command[:3]}\n{error}\n{output}')
        return output, code

    def docker_json(self, *args):
        return json.loads(self.invoke(['docker', *args])[0])

    def preflight(self):
        self.invoke(['git', 'check-ignore', '--quiet', str(ROOT / 'tmp' / (self.name + '-result.json'))])
        self.private_ignored = True
        for key, value in os.environ.items():
            if (key in ('RAILS_ENV', 'RACK_ENV') and value != 'test') or key.endswith('DATABASE_URL'):
                raise RuntimeError('Unsafe ambient application configuration')
        if os.environ.get('DOCKER_HOST') and not os.environ['DOCKER_HOST'].startswith('unix:///'):
            raise RuntimeError('Remote Docker endpoint forbidden')
        context = os.environ.get('DOCKER_CONTEXT') or self.invoke(['docker', 'context', 'show'])[0].strip()
        self.endpoint = self.docker_json('context', 'inspect', context)[0]['Endpoints']['docker']['Host']
        if not self.endpoint.startswith('unix:///') or not pathlib.Path(self.endpoint[7:]).is_socket():
            raise RuntimeError('Local Docker Unix socket required')
        self.invoke(['docker', 'info', '--format', '{{.ServerVersion}}'])
        image = self.docker_json('image', 'inspect', IMAGE)[0]
        if IMAGE not in image['RepoDigests']:
            raise RuntimeError('Required installed MySQL digest missing')
        self.report['image'] = {'id': image['Id'], 'digests': image['RepoDigests']}
        self.invoke(['ruby', '-S', 'bundle', 'check'])
        (ROOT / 'tmp').mkdir(exist_ok=True)
        if (ROOT / 'tmp').is_symlink():
            raise RuntimeError('Scratch root must not be a symlink')
        self.scratch = pathlib.Path(tempfile.mkdtemp(prefix=self.name + '-', dir=ROOT / 'tmp'))
        self.report['scratch'] = str(self.scratch)

    def owned_container(self):
        data = self.docker_json('inspect', self.cid)[0]
        labels = data['Config']['Labels']
        if labels.get('dependency80.nonce') != self.nonce or data['Config']['Image'] != IMAGE:
            raise RuntimeError('Container ownership mismatch')
        mounts = data['Mounts']
        if len(mounts) != 1 or mounts[0]['Name'] != self.volume or mounts[0]['Destination'] != '/var/lib/mysql':
            raise RuntimeError('Unexpected MySQL mount')
        return data

    def mysql(self, sql, check=True):
        self.owned_container()
        return self.invoke(['docker', 'exec', self.cid, 'mysql', '-h127.0.0.1', '-uroot',
                            f'-p{PASSWORD}', '-NBe', sql], check=check)

    def provision(self, environment='test'):
        if self.invoke(['docker', 'volume', 'inspect', self.volume], check=False)[1] == 0:
            raise RuntimeError('Owned volume must be absent')
        self.invoke(['docker', 'volume', 'create', '--label', f'dependency80.nonce={self.nonce}', self.volume])
        self.volume_created = True
        self.cid = self.invoke(['docker', 'run', '-d', '--name', self.name,
                               '--label', f'dependency80.nonce={self.nonce}',
                               '--hostname', self.name, '-p', '127.0.0.1::3306',
                               '-v', f'{self.volume}:/var/lib/mysql',
                               '-e', f'MYSQL_ROOT_PASSWORD={PASSWORD}', IMAGE])[0].strip()
        data = self.owned_container()
        ports = data['NetworkSettings']['Ports']['3306/tcp']
        if len(ports) != 1 or ports[0]['HostIp'] != '127.0.0.1':
            raise RuntimeError('Exact loopback binding required')
        port = int(ports[0]['HostPort'])
        if not 1025 <= port <= 65535 or port == 3306:
            raise RuntimeError('Nondefault owned port required')
        deadline = time.monotonic() + 120
        while True:
            output, code = self.mysql('SELECT VERSION(),@@server_uuid,@@hostname,@@port', check=False)
            if code == 0:
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('MySQL readiness timeout')
            time.sleep(.25)
        identity = output.strip().split('\t')
        if identity[0] != '8.4.11' or identity[2:] != [self.name, '3306']:
            raise RuntimeError('Exact authenticated MySQL8.4.11 identity required')
        prefix = f'railsstarter80_{self.nonce}' + ('_test' if environment == 'development' else '')
        databases = {role: prefix + ('' if role == 'primary' else '_' + role) +
                     ('_test' if environment == 'test' else '') for role in ROLES}
        self.mysql(f"CREATE USER 'dependency80'@'%' IDENTIFIED BY '{PASSWORD}'")
        for database in databases.values():
            self.mysql(f"CREATE DATABASE `{database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; "
                       f"GRANT ALL ON `{database}`.* TO 'dependency80'@'%'")
        grants = self.mysql("SHOW GRANTS FOR 'dependency80'@'%'")[0].splitlines()
        if len(grants) != 5 or any('*.*' in grant and 'USAGE' not in grant for grant in grants):
            raise RuntimeError('Exact four-schema least privilege grants required')
        self.resource = {'nonce': self.nonce, 'container_id': self.cid, 'image': IMAGE,
                         'host': '127.0.0.1', 'port': port, 'identity': identity,
                         'prefix': prefix, 'databases': databases, 'grants': grants,
                         'scratch': str(self.scratch), 'environment': environment}
        (self.scratch / 'resource.json').write_text(json.dumps(self.resource))
        self.report['resource'] = self.resource

    def app_environment(self, overrides=None):
        env = self.environment()
        env.update(RAILS_ENV=self.resource['environment'], RACK_ENV=self.resource['environment'],
                   DEPENDENCY80_ENVIRONMENT=self.resource['environment'], DATABASE_NAME=self.resource['prefix'],
                   PRIMARY_DB_HOST='127.0.0.1', DATABASE_REPLICA_HOST='127.0.0.1',
                   DATABASE_PORT=str(self.resource['port']), DATABASE_USER='dependency80',
                   DATABASE_PASSWORD=PASSWORD, DATABASE_SSL='false', DATABASE_IAM_AUTH='false',
                   AWS_BOOTSTRAP_ENABLED='false', AWS_EC2_METADATA_DISABLED='true',
                   AWS_CONFIG_FILE=os.devnull, AWS_SHARED_CREDENTIALS_FILE=os.devnull,
                   AWS_ACCESS_KEY_ID='synthetic-80', AWS_SECRET_ACCESS_KEY='synthetic-80',
                   AWS_REGION='us-east-1', DEPENDENCY80_RESOURCE=str(self.scratch / 'resource.json'))
        env.update(overrides or {})
        return env

    def ruby(self, script, *args, overrides=None, timeout=90):
        return self.invoke(['ruby', '-rbundler/setup', str(ROOT / 'test/runtime/dependency_upgrade' / script), *args],
                           timeout=timeout, env=self.app_environment(overrides))[0]

    def rejection_controls(self):
        controls = ({'RAILS_ENV': 'production'}, {'RACK_ENV': 'development'},
                    {'QUEUE_DATABASE_URL': 'mysql2://foreign.invalid/foreign'},
                    {'DATABASE_REPLICA_HOST': 'foreign.invalid'}, {'DATABASE_PORT': '3306'},
                    {'DATABASE_NAME': 'foreign'}, {'DATABASE_IAM_AUTH': 'true'},
                    {'DATABASE_SSL': 'true'}, {'_DATABASE_NAME': 'foreign'})
        results = []
        code = "require './test/runtime/dependency_upgrade/resource'; DependencyResource.validate!"
        for overrides in controls:
            output, status = self.invoke(['ruby', '-rbundler/setup', '-e', code], check=False,
                                         env=self.app_environment(overrides))
            error = self.report['commands'][-1]['stderr']
            if not status or 'Mysql2::Error' in error:
                raise RuntimeError('Unsafe input control missed pre-adapter rejection')
            results.append({'inputs': list(overrides), 'rejected': True, 'stderr': error})
        self.report['rejection_controls'] = results

    def cleanup(self):
        if self.cid:
            self.owned_container()
            self.invoke(['docker', 'rm', '-f', self.cid])
            self.report['cleanup']['container_absent'] = self.invoke(['docker', 'inspect', self.cid], check=False)[1] != 0
        if self.volume_created:
            volume = self.docker_json('volume', 'inspect', self.volume)[0]
            if volume['Labels'].get('dependency80.nonce') != self.nonce:
                raise RuntimeError('Volume cleanup ownership mismatch')
            self.invoke(['docker', 'volume', 'rm', self.volume])
            self.report['cleanup']['volume_absent'] = self.invoke(['docker', 'volume', 'inspect', self.volume], check=False)[1] != 0
        self.report['cleanup']['children_reaped'] = self.child is None
        self.report['process_groups'] = self.groups
        self.report['cleanup']['process_groups_absent'] = all(group['absent'] for group in self.groups)
        if hasattr(self, 'resource'):
            try:
                with socket.create_connection((self.resource['host'], self.resource['port']), timeout=1):
                    self.report['cleanup']['database_port_closed'] = False
            except ConnectionRefusedError:
                self.report['cleanup']['database_port_closed'] = True
        if not all(self.report['cleanup'].values()):
            raise RuntimeError('Owned resource cleanup did not positively complete')
        if self.scratch:
            shutil.rmtree(self.scratch)
            self.report['cleanup']['scratch_absent'] = not self.scratch.exists()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-gemfile', type=pathlib.Path)
    parser.add_argument('--baseline-bundle-path', type=pathlib.Path)
    parser.add_argument('--development', action='store_true', help='Real WebConsole and proxy fixture on newly owned test schemas')
    args = parser.parse_args()
    if bool(args.baseline_gemfile) != bool(args.baseline_bundle_path):
        parser.error('Both installed baseline inputs are required together')
    os.umask(0o077)
    run = OwnedUpgrade()
    report = ROOT / 'tmp' / (run.name + '-result.json')
    try:
        run.preflight()
        run.provision('development' if args.development else 'test')
        if args.development:
            run.report['prepare'] = run.ruby('transition.rb', 'prepare')
            run.report['boundaries'] = run.ruby('boundaries.rb', timeout=90)
        else:
            run.rejection_controls()
            baseline = {'BUNDLE_GEMFILE': str(args.baseline_gemfile.resolve()),
                        'BUNDLE_PATH': str(args.baseline_bundle_path.resolve()),
                        'DEPENDENCY80_BASELINE_SCHEMAS': str(args.baseline_gemfile.resolve().parent / 'db')} if args.baseline_gemfile else None
            run.report['seed'] = run.ruby('transition.rb', 'seed', overrides=baseline)
            if baseline:
                run.report['upgrade'] = run.ruby('transition.rb', 'upgrade')
            run.report['runtime'] = run.ruby('runtime.rb')
        run.report['success'] = True
    except Exception as error:
        run.report['error'] = str(error)
    finally:
        try:
            run.cleanup()
        except Exception as error:
            run.report['cleanup']['error'] = str(error)
            run.report['success'] = False
        if run.private_ignored:
            report.parent.mkdir(exist_ok=True)
            report.write_text(json.dumps(run.report, indent=2) + '\n')
        print(json.dumps({'report': str(report) if run.private_ignored else None,
                          'success': run.report['success'], 'cleanup': run.report['cleanup']}))
    return 0 if run.report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
