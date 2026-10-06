"""Portable owned-resource orchestration for the real recurring worker regression."""
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
MODES = ('normal', 'omit-command', 'omit-class', 'command-failure', 'sdk-failure')
PASSWORD = 'synthetic-66-owned-only'


class OwnedRecurringRun:
    """Own one physical server, child process group and private scratch directory."""

    def __init__(self, timeout):
        self.timeout = timeout
        self.nonce = secrets.token_hex(6)
        self.scratch = None
        self.child = None
        self.cid = None
        self.name = f'railsstarter66-recurring-{self.nonce}'
        self.image = None
        self.volumes = []
        self.prior_volumes = set()
        self.port = None
        self.resource = None
        self.docker_endpoint = None
        self.report = {'nonce': self.nonce, 'command': ['bin/test-recurring-worker'],
                       'timeout_seconds': timeout, 'success': False, 'cases': [],
                       'commands': [], 'cleanup': {}}
        self.result_file = ROOT / 'tmp/recurring-worker-results' / (self.nonce + '.json')

    def invoke(self, command, timeout=30, check=True, env=None):
        if command[0] == 'docker' and self.docker_endpoint:
            command = ['docker', '--host', self.docker_endpoint, *command[1:]]
            env = self.base_environment()
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout, env=env)
        self.report['commands'].append({'command': command, 'exit': result.returncode,
                                        'stdout': result.stdout, 'stderr': result.stderr})
        if check and result.returncode:
            raise RuntimeError(f'Command failed ({result.returncode}): {command[0:3]}: {result.stderr}')
        return result

    def docker_json(self, *args):
        return json.loads(self.invoke(['docker', *args]).stdout)

    def preflight(self):
        self.ruby = shutil.which('ruby')
        if not self.ruby or not shutil.which('docker'):
            raise RuntimeError('Installed current Ruby/Bundler and working Docker are required')
        expected = (ROOT / '.ruby-version').read_text().strip()
        version = self.invoke([self.ruby, '-e', 'print RUBY_VERSION'], env=self.base_environment()).stdout
        if version != expected:
            raise RuntimeError(f'Ruby {expected} on PATH required, found {version}')
        self.report['prerequisites'] = {'ruby_executable': self.ruby, 'ruby_version': version}
        subprocess.run([self.ruby, '-S', 'bundle', 'check'], cwd=ROOT,
                       env=self.base_environment(), check=True, timeout=30,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.validate_docker_endpoint()
        self.invoke(['docker', 'info', '--format', '{{.ServerVersion}}'])
        self.prior_volumes = set(self.invoke(['docker', 'volume', 'ls', '-q']).stdout.splitlines())
        image = self.invoke(['docker', 'image', 'inspect', 'mysql:8.4'], check=False)
        if image.returncode:
            self.invoke(['docker', 'pull', 'mysql:8.4'], timeout=300)
            image = self.invoke(['docker', 'image', 'inspect', 'mysql:8.4'])
        self.image = json.loads(image.stdout)[0]['Id']

    def validate_docker_endpoint(self):
        ambient_host = os.environ.get('DOCKER_HOST')
        if ambient_host and not ambient_host.startswith('unix:///'):
            raise RuntimeError('Remote Docker endpoints are forbidden for isolated runtime tests')
        if ambient_host and not os.environ.get('DOCKER_CONTEXT'):
            endpoint = ambient_host
        else:
            context = os.environ.get('DOCKER_CONTEXT') or self.invoke(['docker', 'context', 'show']).stdout.strip()
            endpoint = self.docker_json('context', 'inspect', context)[0]['Endpoints']['docker']['Host']
        if not endpoint.startswith('unix:///') or not pathlib.Path(endpoint[len('unix://'):]).is_socket():
            raise RuntimeError('A proved local Docker Unix socket is required before MySQL provisioning')
        self.docker_endpoint = endpoint
        self.report['prerequisites']['docker_endpoint'] = endpoint

    def base_environment(self):
        toolchain_keys = ('HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'GEM_HOME', 'GEM_PATH',
                          'BUNDLE_PATH', 'BUNDLE_USER_HOME', 'BUNDLE_APP_CONFIG',
                          'BUNDLE_FROZEN', 'BUNDLE_BUILD__MYSQL2', 'BUNDLER_VERSION')
        env = {key: os.environ[key] for key in toolchain_keys if key in os.environ}
        env['PATH'] = str(pathlib.Path(self.ruby).parent) + ':' + os.environ.get(
            'PATH', '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin')
        env.update(RAILS_ENV='test', RACK_ENV='test', AWS_EC2_METADATA_DISABLED='true')
        return env

    def create_scratch(self):
        tmp = ROOT / 'tmp'
        tmp.mkdir(exist_ok=True)
        if tmp.is_symlink():
            raise RuntimeError('Repository tmp must not be a symlink')
        self.scratch = pathlib.Path(tempfile.mkdtemp(prefix=f'recurring-worker-{self.nonce}-', dir=tmp))
        (self.scratch / '.owner.json').write_text(json.dumps({'nonce': self.nonce, 'root': str(ROOT)}))
        self.report['scratch_directory'] = str(self.scratch)
        sources = ('bin/test-recurring-worker', 'test/runtime/recurring_worker/runner.py',
                   'test/runtime/recurring_worker/run.rb', 'test/runtime/recurring_worker/isolation.rb',
                   'config/queue.yml', 'config/recurring.yml', 'spec/rails_helper.rb',
                   'app/jobs/publish_cloud_watch_metrics_job.rb', 'app/services/cloud_watch_service.rb',
                   'Gemfile', 'Gemfile.lock')
        self.report['source_hashes'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                        for name in sources}
        print(f'RECURRING_WORKER_REPORT={self.result_file}', flush=True)

    def provision(self):
        name = self.name
        command = ['docker', 'run', '-d', '--name', name, '--label', f'railsstarter.nonce={self.nonce}',
                   '--label', 'railsstarter66.owner=bin/test-recurring-worker',
                   '-p', '127.0.0.1::3306', '-e', f'MYSQL_ROOT_PASSWORD={PASSWORD}', self.image]
        self.cid = self.invoke(command, timeout=60).stdout.strip()
        data = self.owned_container()
        mounts = data['Mounts']
        if len(mounts) != 1 or mounts[0]['Type'] != 'volume' or mounts[0]['Destination'] != '/var/lib/mysql':
            raise RuntimeError('Expected uniquely created MySQL anonymous volume')
        self.volumes = [mount['Name'] for mount in mounts]
        if set(self.volumes) & self.prior_volumes:
            raise RuntimeError('MySQL mount is not newly owned')
        bindings = [binding for value in data['NetworkSettings']['Ports'].values()
                    if value for binding in value]
        if len(bindings) != 1 or bindings[0]['HostIp'] != '127.0.0.1':
            raise RuntimeError('Exactly one unique loopback MySQL port required')
        self.port = int(bindings[0]['HostPort'])
        if self.port == 3306 or self.port < 1025:
            raise RuntimeError('Dedicated nondefault MySQL port required')
        self.report['resource'] = {'container_id': self.cid, 'image_id': self.image,
                                   'container_name': name, 'nonce': self.nonce,
                                   'host': '127.0.0.1', 'port': self.port, 'volumes': self.volumes}
        deadline = time.monotonic() + 120
        while True:
            ready = self.mysql('SELECT VERSION(),@@server_uuid,@@hostname,@@port', check=False)
            if ready.returncode == 0:
                identity = ready.stdout.strip()
                if not identity.startswith('8.4.') or identity.split('\t')[2] != self.cid[:12]:
                    raise RuntimeError('Authenticated physical MySQL8.4 identity mismatch')
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('Owned MySQL authenticated TCP readiness timed out')
            time.sleep(0.25)
        prefix = f'railsstarter66_{self.nonce}'
        databases = {role: f'{prefix}{"" if role == "primary" else "_" + role}_test'
                     for role in ('primary', 'queue', 'cache', 'cable')}
        for database in databases.values():
            self.mysql(f'CREATE DATABASE `{database}`')
        names = self.mysql("SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME LIKE 'railsstarter66\\_%' ORDER BY SCHEMA_NAME").stdout.splitlines()
        if sorted(names) != sorted(databases.values()):
            raise RuntimeError('Exactly four explicit test database names required')
        count = self.mysql("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA LIKE 'railsstarter66\\_%'").stdout.strip()
        if count != '0':
            raise RuntimeError('All four schemas must be fresh before Rails boot')
        self.resource = dict(self.report['resource'], database_prefix=prefix, databases=databases,
                             synthetic_password=PASSWORD, server_identity=identity,
                             scratch_directory=str(self.scratch), fresh_table_count=0)
        self.report['resource'] = self.resource
        self.manifest = self.scratch / 'resource.json'
        self.manifest.write_text(json.dumps(self.resource, indent=2))

    def owned_container(self):
        data = self.docker_json('inspect', self.cid)[0]
        labels = data['Config']['Labels']
        if (data['Id'] != self.cid or data['Image'] != self.image or data['Name'] != '/' + self.name or
                labels.get('railsstarter.nonce') != self.nonce or
                labels.get('railsstarter66.owner') != 'bin/test-recurring-worker'):
            raise RuntimeError('Owned container identity mismatch; refusing mutation')
        return data

    def mysql(self, query, check=True):
        self.owned_container()
        return self.invoke(['docker', 'exec', self.cid, 'mysql', '-h127.0.0.1', '-uroot',
                            f'-p{PASSWORD}', '-Nse', query], check=check)

    def environment(self):
        self.owned_container()
        identity = self.mysql('SELECT VERSION(),@@server_uuid,@@hostname,@@port').stdout.strip()
        if identity != self.resource['server_identity']:
            raise RuntimeError('Physical identity changed before Ruby execution')
        env = self.base_environment()
        env.update(DATABASE_NAME=self.resource['database_prefix'], PRIMARY_DB_HOST='127.0.0.1',
                   DATABASE_REPLICA_HOST='127.0.0.1', DATABASE_PORT=str(self.port), DATABASE_USER='root',
                   DATABASE_PASSWORD=PASSWORD, DATABASE_SSL='false', DATABASE_IAM_AUTH='false',
                   AWS_ACCESS_KEY_ID='synthetic-66', AWS_SECRET_ACCESS_KEY='synthetic-66', AWS_REGION='us-east-1',
                   SECRET_KEY_BASE='synthetic-66-owned-secret-key-base-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                   RECURRING_RESOURCE=str(self.manifest), RECURRING_SCRATCH=str(self.scratch))
        for role, database in self.resource['databases'].items():
            env[f'RECURRING_{role.upper()}_TEST_DATABASE'] = database
        return env

    def run_case(self, mode):
        output = self.scratch / (mode + '.json')
        log = self.scratch / (mode + '.log')
        command = [self.ruby, '-S', 'bundle', 'exec', 'ruby', 'test/runtime/recurring_worker/run.rb', mode, str(output)]
        case = {'mode': mode, 'command': command, 'expected_boundary': False}
        self.report['cases'].append(case)
        with log.open('w') as handle:
            self.child = subprocess.Popen(command, cwd=ROOT, env=self.environment(),
                                          stdout=handle, stderr=subprocess.STDOUT, start_new_session=True)
            case['child_pid'] = self.child.pid
            try:
                case['exit'] = self.child.wait(timeout=self.timeout)
            except subprocess.TimeoutExpired:
                case['error'] = 'Actual Ruby runtime child timed out'
                self.stop_child()
                raise RuntimeError(case['error'])
            except BaseException as error:
                case['error'] = f'{type(error).__name__}: {error}'
                self.stop_child()
                raise
            finally:
                case['log'] = log.read_text()
        self.stop_child()
        case['process_group_absent'] = self.report['cleanup']['process_group_absent']
        if not output.is_file():
            raise RuntimeError(f'{mode}: actual runtime result is absent')
        case['result'] = json.loads(output.read_text())
        case['expected_boundary'] = expected_boundary(mode, case['exit'], case['result'])
        if not case['expected_boundary']:
            raise RuntimeError(f'{mode}: actual persisted witnesses do not prove the required boundary')
        print(f'RECURRING_WORKER_CASE={mode}:verified', flush=True)

    @staticmethod
    def group_exists(group):
        try:
            os.killpg(group, 0)
            return True
        except ProcessLookupError:
            return False

    @staticmethod
    def signal_owned_group(group, signum):
        try:
            os.killpg(group, signum)
        except ProcessLookupError:
            pass  # The tracked group exited naturally; final absence is still verified.

    def stop_child(self):
        if not self.child:
            return
        child = self.child
        group = child.pid  # Established by Popen(start_new_session=True), never ambient.
        if child.poll() is None:
            try:
                if os.getpgid(child.pid) != group:
                    raise RuntimeError('Runtime child process group ownership mismatch')
            except ProcessLookupError:
                child.poll()
        if self.group_exists(group):
            self.signal_owned_group(group, signal.SIGTERM)
        try:
            child.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.signal_owned_group(group, signal.SIGKILL)
            child.wait(timeout=10)
        deadline = time.monotonic() + 2
        while self.group_exists(group) and time.monotonic() < deadline:
            time.sleep(0.03)
        if self.group_exists(group):
            self.signal_owned_group(group, signal.SIGKILL)
            deadline = time.monotonic() + 2
            while self.group_exists(group) and time.monotonic() < deadline:
                time.sleep(0.03)
        checks = self.report['cleanup']
        checks['child_absent'] = child.poll() is not None
        checks['process_group_absent'] = not self.group_exists(group)
        if not checks['process_group_absent']:
            raise RuntimeError('Owned runtime descendants remain after shutdown')
        self.child = None

    def absent(self, kind, identity):
        self.invoke(['docker', 'info', '--format', '{{.ServerVersion}}'])
        command = ['docker', 'inspect', identity] if kind == 'container' else ['docker', 'volume', 'inspect', identity]
        observed = self.invoke(command, check=False)
        expected = 'no such object' if kind == 'container' else 'no such volume'
        if observed.returncode == 0 or expected not in observed.stderr.lower() or identity not in observed.stderr:
            raise RuntimeError(f'Exact {kind} absence is unproved: {identity}')
        if kind == 'container':
            inventory = self.invoke(['docker', 'ps', '-a', '--filter', f'label=railsstarter.nonce={self.nonce}', '-q']).stdout
            if inventory.strip():
                raise RuntimeError('Owned nonce container inventory remains')
        else:
            inventory = self.invoke(['docker', 'volume', 'ls', '-q']).stdout.splitlines()
            if identity in inventory:
                raise RuntimeError('Owned volume inventory remains')
        return True

    def clean_container(self):
        checks = self.report['cleanup']
        if not self.cid and self.image:
            recover = self.invoke(['docker', 'inspect', self.name], check=False)
            if recover.returncode == 0:
                self.cid = json.loads(recover.stdout)[0]['Id']
            else:
                checks['container_absent'] = self.absent('container', self.name)
                return
        if not self.cid:
            checks['container_absent'] = True  # No Docker creation command was reached.
            return
        data = self.owned_container()
        bindings = [binding for value in data['NetworkSettings']['Ports'].values() if value for binding in value]
        if not self.port and len(bindings) == 1 and bindings[0]['HostIp'] == '127.0.0.1':
            self.port = int(bindings[0]['HostPort'])
        if not self.volumes:
            mounts = data['Mounts']
            for mount in mounts:
                if (mount['Type'] != 'volume' or mount['Name'] in self.prior_volumes or
                        mount['Destination'] != '/var/lib/mysql'):
                    raise RuntimeError('Cannot prove newly owned volume identity during cleanup')
                self.volumes.append(mount['Name'])
        self.report.setdefault('resource', {}).update(container_id=self.cid, image_id=self.image,
            container_name=self.name, nonce=self.nonce, host='127.0.0.1', port=self.port, volumes=self.volumes)
        self.invoke(['docker', 'stop', self.cid], timeout=30)
        self.owned_container()
        self.invoke(['docker', 'rm', self.cid])
        checks['container_absent'] = self.absent('container', self.cid)

    def clean_volumes(self):
        errors = []
        for volume in self.volumes:
            try:
                attached = self.invoke(['docker', 'ps', '-a', '--filter', f'volume={volume}', '-q']).stdout.strip()
                if attached or volume in self.prior_volumes:
                    raise RuntimeError('Owned volume cleanup identity mismatch')
                self.invoke(['docker', 'volume', 'inspect', volume])
                self.invoke(['docker', 'volume', 'rm', volume])
                self.absent('volume', volume)
            except Exception as error:
                errors.append(str(error))
        self.report['cleanup']['volumes_absent'] = not errors
        if errors:
            raise RuntimeError('; '.join(errors))

    def check_port(self):
        if not self.port:
            self.report['cleanup']['port_absent'] = self.cid is None
            return
        with socket.socket() as connection:
            connection.settimeout(1)
            self.report['cleanup']['port_absent'] = connection.connect_ex(('127.0.0.1', self.port)) != 0

    def clean_scratch(self):
        if self.scratch:
            owner = json.loads((self.scratch / '.owner.json').read_text())
            safe = (self.scratch.parent == ROOT / 'tmp' and not self.scratch.is_symlink() and
                    owner == {'nonce': self.nonce, 'root': str(ROOT)})
            if not safe:
                raise RuntimeError('Scratch cleanup ownership mismatch')
            shutil.rmtree(self.scratch)
            self.report['cleanup']['scratch_absent'] = not self.scratch.exists()
        else:
            self.report['cleanup']['scratch_absent'] = True

    def cleanup(self):
        checks = self.report['cleanup']
        checks.setdefault('child_absent', self.child is None)
        checks.setdefault('process_group_absent', self.child is None)
        errors = []
        stages = (('child', self.stop_child), ('container', self.clean_container),
                  ('volumes', self.clean_volumes), ('port', self.check_port),
                  ('export', self.export), ('scratch', self.clean_scratch))
        for name, action in stages:
            try:
                action()
            except Exception as error:
                errors.append(f'{name}: {type(error).__name__}: {error}')
        required = ('child_absent', 'process_group_absent', 'container_absent',
                    'volumes_absent', 'port_absent', 'scratch_absent')
        if errors or not all(checks.get(key) is True for key in required):
            self.report['cleanup_errors'] = errors
            raise RuntimeError('Owned cleanup absence proof failed: ' + '; '.join(errors))

    def export(self):
        parent = self.result_file.parent
        parent.mkdir(parents=True, exist_ok=True)
        if parent.is_symlink():
            raise RuntimeError('Results directory must not be a symlink')
        temporary = parent / (self.nonce + '.writing')
        temporary.write_text(json.dumps(self.report, indent=2))
        temporary.replace(self.result_file)

    def run(self):
        try:
            self.create_scratch()
            self.preflight()
            self.provision()
            for mode in MODES:
                self.run_case(mode)
            self.report['success'] = True
        except (Exception, KeyboardInterrupt) as error:
            self.report['error'] = f'{type(error).__name__}: {error}'
        finally:
            for name in (signal.SIGINT, signal.SIGTERM):
                signal.signal(name, signal.SIG_IGN)
            try:
                self.cleanup()
            except Exception as error:
                self.report['cleanup_error'] = f'{type(error).__name__}: {error}'
                self.report['success'] = False
            self.export()
        if self.report.get('error') or not all(self.report['cleanup'].values()):
            self.report['success'] = False
            self.export()
        print(f'RECURRING_WORKER_REPORT={self.result_file}', flush=True)
        return 0 if self.report['success'] else 1


def expected_boundary(mode, status, result):
    """Reject arbitrary errors; require exact task-kind/queue/effect failure reasons."""
    if result.get('error') or result.get('remaining_processes') != []:
        return False
    checks = result['completion_checks']
    if not all(checks[key] for key in ('execution_mapping', 'zero_aws_boot', 'genuine_queues')):
        return False
    jobs = result['jobs']
    commands = [job for job in jobs if job['class_name'] == 'SolidQueue::RecurringJob']
    classes = [job for job in jobs if job['class_name'] == 'PublishCloudWatchMetricsJob']
    if not commands or not classes or result['claimed']:
        return False
    command_ids = {job['id'] for job in commands}
    class_ids = {job['id'] for job in classes}
    unfinished = set(result['unfinished'])
    ready = {row['job_id'] for row in result['ready']}
    failed = {row['job_id'] for row in result['failed']}
    command_finished = all(job['finished_at'] for job in commands)
    class_finished = all(job['finished_at'] for job in classes)
    if mode == 'normal':
        return status == 0 and result['success'] is True and all(checks.values())
    if status != 1 or result['success'] is not False or checks['terminal_jobs'] is True and mode != 'sdk-failure':
        return False
    if mode == 'omit-command':
        return (unfinished == ready == command_ids and not failed and not command_finished and class_finished and
                checks['metric_success'] and not checks['command_effect'] and
                valid_omission(result, 'solid_queue_recurring', 'default'))
    if mode == 'omit-class':
        own_ids = {job['active_job_id'] for job in classes}
        own_calls = [call for call in result['aws_calls'] if call['operation'] == 'put_metric_data' and call['active_job_id'] in own_ids]
        return (unfinished == ready == class_ids and not failed and command_finished and not class_finished and
                not checks['metric_success'] and checks['command_effect'] and not own_calls and
                valid_omission(result, 'default', 'solid_queue_recurring'))
    if mode == 'command-failure':
        errors = [str(row['error']) for row in result['failed']]
        return (unfinished == failed == command_ids and not ready and not command_finished and class_finished and
                checks['metric_success'] and not checks['command_effect'] and
                all('66 controlled command failure' in error for error in errors))
    if mode == 'sdk-failure':
        own_ids = {job['active_job_id'] for job in classes}
        rejected = {call['active_job_id'] for call in result['aws_calls']
                    if call['operation'] == 'put_metric_data' and call['successful'] is False}
        return (not unfinished and not ready and not failed and command_finished and class_finished and
                not checks['metric_success'] and checks['command_effect'] and checks['terminal_jobs'] and
                own_ids <= rejected)
    return False


def valid_omission(result, omitted, selected):
    """Require the real descriptor narrowing, in addition to persisted job effects."""
    witness = result.get('queue_omission', {})
    originals = witness.get('original', [])
    workers = result.get('worker_attributes', [])
    return (bool(originals) and all(queues == ['*'] for queues in originals) and
            witness.get('omitted') == omitted and witness.get('selected') == [selected] and
            bool(workers) and all(worker.get('queues') == [selected] for worker in workers))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--timeout', type=float, default=45, help='Real per-case Ruby timeout in seconds (default:45)')
    args = parser.parse_args()
    if not 0 < args.timeout <= 300:
        parser.error('--timeout must be positive and at most300seconds')
    def interrupted(signum, _frame):
        raise InterruptedError(f'Received signal {signum}; owned resource cleanup required')
    for name in (signal.SIGINT, signal.SIGTERM):
        signal.signal(name, interrupted)
    return OwnedRecurringRun(args.timeout).run()
