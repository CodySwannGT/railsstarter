#!/usr/bin/env python3
"""Real two-process attachment acceptance, using owned MySQL and byte-backed SDK stubs."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import secrets
import shutil
import subprocess
import tarfile
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
IMAGE = 'mysql@sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242'
PAYLOAD = '73 actual bytes: cross-instance attachment persistence\n'
BUNDLE_KEYS = ('PATH', 'HOME', 'LANG', 'GEM_HOME', 'GEM_PATH', 'BUNDLE_PATH', 'BUNDLE_USER_HOME',
               'BUNDLE_APP_CONFIG', 'BUNDLE_FROZEN', 'BUNDLE_BUILD__MYSQL2', 'BUNDLER_VERSION')
OWNED = ['Gemfile', 'Gemfile.lisa', 'Gemfile.lock',
         'config/storage.yml', 'config/environments/staging.rb', 'config/environments/production.rb',
         'lib/upload_storage.rb', 'lib/active_storage/service/upload_build_only_service.rb', 'db/schema.rb']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def private_write(path, data):
    path.write_bytes(data if isinstance(data, bytes) else data.encode())
    path.chmod(0o600)


def extract_snapshot(data, destination):
    """Validate the complete archive before writes, including direct file aliases.

    Explicit extraction works on Python versions without tar extraction filters.
    Links are created last and may only name a recorded regular file, never
    another link, a directory, or a path containing traversal components.
    """
    if destination.is_symlink() or not destination.is_dir() or any(destination.iterdir()):
        raise RuntimeError('Snapshot destination must be an empty regular directory')

    def relative_path(name):
        if (not name or PurePosixPath(name).is_absolute() or '\\' in name or '\0' in name or
                any(part in ('', '.', '..') for part in name.split('/'))):
            raise RuntimeError('Unsafe git snapshot archive path')
        return PurePosixPath(name)

    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        members = {}
        aliases = {}
        for member in archive.getmembers():
            path = relative_path(member.name.rstrip('/') if member.isdir() else member.name)
            if path in members or member.type not in (tarfile.REGTYPE, tarfile.AREGTYPE, tarfile.DIRTYPE, tarfile.SYMTYPE):
                raise RuntimeError('Duplicate or unsupported git snapshot archive member')
            members[path] = member
        for path, member in members.items():
            if any(parent in members and not members[parent].isdir() for parent in path.parents):
                raise RuntimeError('Git snapshot archive traverses a file or link parent')
            if member.issym():
                target = path.parent / relative_path(member.linkname)
                if target not in members or not members[target].isfile():
                    raise RuntimeError('Git snapshot alias must name a recorded regular file')
                aliases[path] = member.linkname
        # No archive member has been extracted until every member and alias passes.
        for path, member in members.items():
            target = destination / str(path)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as source, target.open('xb') as output:
                    shutil.copyfileobj(source, output)
                target.chmod(member.mode & 0o777)
        for path, linkname in aliases.items():
            target = destination / str(path)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(linkname)


class Journey:
    def __init__(self, ruby, evidence):
        self.ruby = ruby
        self.env = {key: os.environ[key] for key in BUNDLE_KEYS if key in os.environ}
        self.nonce = secrets.token_hex(6)
        self.evidence = evidence or ROOT / 'tmp' / ('active-storage-evidence-' + self.nonce)
        if self.evidence.exists():
            raise RuntimeError('Evidence directory must be new')
        self.evidence.mkdir(parents=True, mode=0o700)
        self.evidence.chmod(0o700)
        self.logs = []
        self.resources = []
        self.report = {'cases': {}, 'processes': [], 'resources': [], 'source_hashes': {}, 'cleanup': []}
        paths = OWNED + [str(path.relative_to(ROOT)) for path in (ROOT / 'db/migrate').glob('*active_storage*.rb')]
        paths += [str(path.relative_to(ROOT)) for path in (ROOT / 'test/runtime/active_storage').glob('*') if path.is_file()]
        self.report['source_hashes'] = {path: digest((ROOT / path).read_bytes()) for path in paths}
        self.archive = subprocess.check_output(['git', 'archive', 'HEAD'], cwd=ROOT)

    def command(self, args, data=None, env=None, cwd=None, check=True):
        process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   env=env, cwd=cwd or ROOT)
        try:
            stdout, stderr = process.communicate(data, timeout=120)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                stdout, stderr = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                stdout, stderr = process.communicate()
            raise RuntimeError('Owned child timeout, terminated and reaped')
        log = stdout + b'\n' + stderr
        name = 'command-%03d.log' % len(self.logs)
        private_write(self.evidence / name, log)
        self.logs.append({'command': args, 'exit': process.returncode, 'pid': process.pid,
                          'reaped': process.poll() is not None, 'file': name, 'sha256': digest(log)})
        if check and process.returncode:
            raise RuntimeError('Required command failed: ' + str(args[:3]) + '; evidence ' + name)
        return process.returncode, stdout

    def provision(self, profile):
        nonce = secrets.token_hex(6)
        resource = {'nonce': nonce, 'source_root': str(ROOT), 'profile': profile,
                    'container_name': 'railsstarter73-' + nonce, 'volume_name': 'railsstarter73-' + nonce + '-mysql',
                    'image_digest': IMAGE, 'host': '127.0.0.1', 'database_user': 'storage73_' + nonce}
        self.resources.append(resource)  # Partial provision is still owned and cleaned on failure.
        _, data = self.command(['docker', 'image', 'inspect', IMAGE, '--format',
                                '{"id":{{json .Id}},"digests":{{json .RepoDigests}}}'])
        image = json.loads(data)
        if IMAGE not in image['digests']:
            raise RuntimeError('Exact named MySQL image unavailable')
        resource['image_id'] = image['id']
        for kind, name in [('container', resource['container_name']), ('volume', resource['volume_name'])]:
            code, _ = self.command(['docker', kind, 'inspect', name], check=False)
            if code == 0:
                raise RuntimeError('Nonce resource already exists; never reuse foreign resources')
        self.command(['docker', 'volume', 'create', '--label', 'railsstarter73.nonce=' + nonce, resource['volume_name']])
        resource['volume_created'] = True
        docker_env = dict(os.environ, MYSQL_ROOT_PASSWORD='synthetic-root-' + nonce)
        _, data = self.command(['docker', 'run', '-d', '--name', resource['container_name'], '--hostname', resource['container_name'],
                                '--label', 'railsstarter73.nonce=' + nonce, '--env', 'MYSQL_ROOT_PASSWORD',
                                '--publish', '127.0.0.1::3306', '--mount',
                                'type=volume,source=' + resource['volume_name'] + ',target=/var/lib/mysql', IMAGE], env=docker_env)
        resource['container_id'] = data.decode().strip()
        self.inspect_owned(resource)
        for _ in range(90):
            code, identity = self.mysql(resource, 'SELECT VERSION(),@@server_uuid,@@hostname,@@port;', check=False)
            if code == 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('Required owned MySQL access unavailable')
        resource['server_identity'] = identity.decode().strip().split('\t')
        if resource['server_identity'][0] != '8.4.11' or resource['server_identity'][2:] != [resource['container_name'], '3306']:
            raise RuntimeError('Wrong physical MySQL identity')
        prefix = ('railsstarter73_' if profile == 'test' else 'railsstarter73_test_') + nonce
        resource['database_prefix'] = prefix
        resource['databases'] = {role: (prefix + ('_test' if role == 'primary' else '_' + role + '_test')
                                       if profile == 'test' else prefix + ('' if role == 'primary' else '_' + role))
                                 for role in ['primary', 'queue', 'cache', 'cable']}
        sql = "CREATE USER '%s'@'%%' IDENTIFIED BY 'synthetic-app-%s';\n" % (resource['database_user'], nonce)
        for database in resource['databases'].values():
            sql += 'CREATE DATABASE `%s` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;\n' % database
            sql += "GRANT ALL PRIVILEGES ON `%s`.* TO '%s'@'%%';\n" % (database.replace('_', '\\_'), resource['database_user'])
        self.mysql(resource, sql)
        # This actual mysql2 preflight is independent of Rails and all fixture schema writes.
        code = '''require "json";require "mysql2";r=JSON.parse(STDIN.read);rows={};r.fetch("databases").each do |role,db|
 c=Mysql2::Client.new(host:r.fetch("host"),port:r.fetch("port"),username:r.fetch("database_user"),password:"synthetic-app-"+r.fetch("nonce"),database:db)
 id=c.query("SELECT VERSION() v,@@server_uuid uuid,@@hostname hostname,@@port port,DATABASE() db").first
 raise "Physical or logical mismatch" unless [id["v"],id["uuid"],id["hostname"],id["port"].to_s]==r.fetch("server_identity") && id["db"]==db
 raise "Not fresh" unless c.query("SHOW TABLES").count.zero?
 g=c.query("SHOW GRANTS").map(&:values).flatten;raise "Unexpected grants" unless g.length==5 && g.grep(/ON \\*\\.\\*/).all?{|v|v.start_with?("GRANT USAGE ON")}
 raise "Wrong scoped database grants" unless r.fetch("databases").values.all?{|name|g.any?{|grant|grant.include?("`"+name.gsub("_", "\\\\_")+"`.*")}};rows[role]={identity:id,grants:g,fresh:true};c.close;end;puts JSON.generate(rows)'''
        _, data = self.command([self.ruby, '-rbundler/setup', '-e', code], json.dumps(resource).encode(), env=self.env)
        resource['host_preflight'] = json.loads(data)
        resource['scratch'] = str(ROOT / 'tmp' / ('storage-acceptance-' + nonce))
        scratch = Path(resource['scratch'])
        scratch.mkdir(mode=0o700)
        private_write(scratch / '.owner.json', json.dumps({'nonce': nonce, 'source_root': str(ROOT)}))
        (scratch / 'objects').mkdir(mode=0o700)
        self.report['resources'].append(resource)
        return resource

    def inspect_owned(self, resource):
        fmt = '{"id":{{json .Id}},"image":{{json .Image}},"hostname":{{json .Config.Hostname}},"labels":{{json .Config.Labels}},"ports":{{json .NetworkSettings.Ports}},"mounts":{{json .Mounts}}}'
        _, data = self.command(['docker', 'inspect', resource['container_id'], '--format', fmt])
        actual = json.loads(data)
        if (actual['id'] != resource['container_id'] or actual['image'] != resource['image_id'] or
                actual['hostname'] != resource['container_name'] or actual['labels'].get('railsstarter73.nonce') != resource['nonce']):
            raise RuntimeError('Physical container ownership mismatch')
        mounts = [mount for mount in actual['mounts'] if mount['Destination'] == '/var/lib/mysql']
        if len(mounts) != 1 or mounts[0]['Name'] != resource['volume_name']:
            raise RuntimeError('Owned volume mismatch')
        ports = actual['ports']['3306/tcp']
        if len(ports) != 1 or ports[0]['HostIp'] != '127.0.0.1' or int(ports[0]['HostPort']) == 3306:
            raise RuntimeError('Unsafe physical loopback port')
        resource['port'] = int(ports[0]['HostPort'])
        return actual

    def mysql(self, resource, sql, check=True):
        return self.command(['docker', 'exec', '-i', resource['container_id'], 'sh', '-c',
                             'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql --protocol=TCP --host=127.0.0.1 -uroot --batch --skip-column-names'],
                            sql.encode(), check=check)

    def snapshot(self, resource, name, disk=False):
        app = Path(resource['scratch']) / name
        app.mkdir(mode=0o700)
        extract_snapshot(self.archive, app)
        paths = OWNED + [str(path.relative_to(ROOT)) for path in (ROOT / 'db/migrate').glob('*active_storage*.rb')]
        for path in paths:
            target = app / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / path, target)
        if disk:
            for environment in ['staging', 'production']:
                path = app / ('config/environments/' + environment + '.rb')
                text = path.read_text()
                if 'UploadStorage.service_for(Rails.env)' not in text:
                    raise RuntimeError('Disk mutation did not reach deployed selection')
                path.write_text(text.replace('UploadStorage.service_for(Rails.env)', ':local'))
        return app

    def app(self, resource, name, mode='attach', profile='staging', prepare=False, owner_id=None, settings=None, disk=False):
        app = self.snapshot(resource, name, disk=disk)
        env = dict(self.env, RAILS_ENV=profile, RACK_ENV=profile, DATABASE_NAME=resource['database_prefix'],
                   DATABASE_USER=resource['database_user'], DATABASE_PASSWORD='synthetic-app-' + resource['nonce'],
                   DATABASE_PORT=str(resource['port']), PRIMARY_DB_HOST='127.0.0.1', DATABASE_REPLICA_HOST='127.0.0.1',
                   DATABASE_SSL='false', DATABASE_IAM_AUTH='false', AWS_EC2_METADATA_DISABLED='true',
                   AWS_BOOTSTRAP_ENABLED='false', SECRET_KEY_BASE='synthetic-73-' + resource['nonce'] + '0' * 64,
                   DISABLE_BOOTSNAP_COMPILE_CACHE='1', ALLOWED_HOSTS='owned73.invalid', REQUEST_INGRESS_PROFILE='direct')
        if profile in ['staging', 'production']:
            env.update(ACTIVE_STORAGE_STAGING_BUCKET='synthetic-staging-uploads-73',
                       ACTIVE_STORAGE_PRODUCTION_BUCKET='synthetic-production-uploads-73', ACTIVE_STORAGE_S3_REGION='us-east-1')
        if mode == 'assets':
            env.pop('SECRET_KEY_BASE')
            env['SECRET_KEY_BASE_DUMMY'] = '1'
            for key in list(env):
                if key.startswith('ACTIVE_STORAGE_'):
                    env.pop(key)
        for key, value in (settings or {}).items():
            if value is None:
                env.pop(key, None)
            else:
                env[key] = value
        output = Path(resource['scratch']) / (name + '.json')
        request = {'resource': resource, 'root': str(app), 'output': str(output), 'mode': mode, 'prepare': prepare,
                   'object_store': str(Path(resource['scratch']) / 'objects'), 'payload': PAYLOAD, 'owner_id': owner_id}
        code, _ = self.command([self.ruby, '-rbundler/setup', str(ROOT / 'test/runtime/active_storage/app.rb')],
                               json.dumps(request).encode(), env=env, cwd=app, check=False)
        if not output.is_file():
            raise RuntimeError('Application failed without its required boundary record: ' + name)
        result = json.loads(output.read_bytes())
        result['exit'] = code
        result['result_sha256'] = digest(output.read_bytes())
        private_write(self.evidence / (name + '.json'), output.read_bytes())
        if mode == 'migration':
            for filename in ['engine-schema.rb', 'host-schema.rb', 'roundtrip-schema.rb']:
                path = Path(resource['scratch']) / filename
                if path.exists():
                    private_write(self.evidence / filename, path.read_bytes())
        if mode == 'prepare':
            path = Path(resource['scratch']) / 'suite-primary-schema.rb'
            if path.exists():
                private_write(self.evidence / path.name, path.read_bytes())
        self.report['processes'].append({'name': name, 'pid': result['pid'], 'root': result['root'], 'reaped': True})
        self.report['cases'][name] = result
        if result.get('transports') != 0:
            raise RuntimeError('Provider transport attempted in actual app: ' + name)
        return result

    def replace_storage(self, first):
        record = next(item for item in self.report['processes'] if item['pid'] == first['pid'])
        if not record['reaped']:
            raise RuntimeError('First app has not been positively reaped')
        root = Path(first['root'])
        for relative in ['storage', 'tmp/storage']:
            path = root / relative
            if path.is_symlink():
                raise RuntimeError('Local storage is a symlink')
            if path.exists():
                shutil.rmtree(path)
            path.mkdir(parents=True, mode=0o700)

    def persistence(self, first, second, expected_bucket):
        if not first.get('success') or first.get('service_class') != 'ActiveStorage::Service::S3Service':
            raise AssertionError('PERSISTENCE_DETECTOR: expected actual S3 adapter')
        if not second.get('success'):
            raise AssertionError('PERSISTENCE_DETECTOR: second app could not read exact stored bytes')
        if first['pid'] == second['pid'] or first['root'] == second['root']:
            raise AssertionError('PERSISTENCE_DETECTOR: instances were not independent')
        if first['key'] != second['key'] or first['owner_id'] != second['owner_id']:
            raise AssertionError('PERSISTENCE_DETECTOR: persisted attachment identity changed')
        if second['download_sha256'] != digest(PAYLOAD.encode()) or second['download_bytes'] != len(PAYLOAD.encode()):
            raise AssertionError('PERSISTENCE_DETECTOR: byte mismatch')
        for result, operation in [(first, 'put_object'), (second, 'get_object')]:
            calls = [call for call in result.get('api_requests', []) if call['operation'] == operation]
            if not result.get('sdk_stubbed') or len(calls) != 1 or calls[0]['params']['key'] != first['key'] or calls[0]['params']['bucket'] != expected_bucket:
                raise AssertionError('PERSISTENCE_DETECTOR: missing exact real SDK request')
        callback = first['s3_requests'][0]
        if callback['sha256'] != digest(PAYLOAD.encode()) or callback['bytes'] != len(PAYLOAD.encode()):
            raise AssertionError('PERSISTENCE_DETECTOR: actual put bytes differ')

    def archive_controls(self):
        """Public default regression controls; no private receipt or donor input."""
        def fixture(entries):
            data = io.BytesIO()
            with tarfile.open(fileobj=data, mode='w') as archive:
                for name, kind, content in entries:
                    member = tarfile.TarInfo(name)
                    member.type = kind
                    member.mode = 0o755
                    if kind == tarfile.REGTYPE:
                        member.size = len(content)
                        archive.addfile(member, io.BytesIO(content))
                    else:
                        member.linkname = content
                        archive.addfile(member)
            return data.getvalue()

        records = {}
        with tempfile.TemporaryDirectory(prefix='archive-controls-', dir=self.evidence) as scratch:
            root = Path(scratch)
            outside = root / 'outside'
            private_write(outside, b'outside must remain unchanged')
            base = [('innocent', tarfile.REGTYPE, b'validation must precede this write'),
                    ('Dockerfile.local', tarfile.REGTYPE, b'FROM synthetic-archive-control\n')]
            positive = fixture(base + [('worker.Dockerfile.local', tarfile.SYMTYPE, 'Dockerfile.local'),
                                       ('nested/file', tarfile.REGTYPE, b'nested bytes'),
                                       ('nested/alias', tarfile.SYMTYPE, 'file')])
            destination = root / 'positive'
            destination.mkdir(mode=0o700)
            extract_snapshot(positive, destination)
            alias = destination / 'worker.Dockerfile.local'
            if (not alias.is_symlink() or os.readlink(alias) != 'Dockerfile.local' or
                    alias.read_bytes() != base[1][2] or (destination / 'nested/alias').read_bytes() != b'nested bytes' or
                    (destination / 'Dockerfile.local').stat().st_mode & 0o777 != 0o755):
                raise AssertionError('Contained alias bytes/mode were not preserved')
            private_write(self.evidence / 'archive-contained-alias.tar', positive)
            records['contained-alias'] = {'archive_sha256': digest(positive), 'target_sha256': digest(alias.read_bytes()),
                                          'linkname': os.readlink(alias), 'passed': True}
            shutil.rmtree(destination)
            negatives = {
                'absolute-link': [('alias', tarfile.SYMTYPE, str(outside))],
                'escaping-link': [('alias', tarfile.SYMTYPE, '../outside')],
                'traversing-link': [('alias', tarfile.SYMTYPE, 'nested/../Dockerfile.local')],
                'absolute-member': [(str(outside), tarfile.REGTYPE, b'unsafe')],
                'traversing-member': [('../outside', tarfile.REGTYPE, b'unsafe')],
                'duplicate': [('Dockerfile.local', tarfile.REGTYPE, b'duplicate')],
                'duplicate-directory': [('dir', tarfile.DIRTYPE, ''), ('dir/', tarfile.DIRTYPE, '')],
                'hardlink': [('alias', tarfile.LNKTYPE, 'Dockerfile.local')],
                'fifo': [('pipe', tarfile.FIFOTYPE, '')],
                'character-device': [('device', tarfile.CHRTYPE, '')],
                'block-device': [('device', tarfile.BLKTYPE, '')],
                'link-parent': [('alias/child', tarfile.REGTYPE, b'unsafe'), ('alias', tarfile.SYMTYPE, 'Dockerfile.local')],
                'file-parent': [('Dockerfile.local/child', tarfile.REGTYPE, b'unsafe')],
                'missing-target': [('alias', tarfile.SYMTYPE, 'absent')],
                'link-chain': [('first', tarfile.SYMTYPE, 'Dockerfile.local'), ('second', tarfile.SYMTYPE, 'first')],
                'directory-target': [('dir', tarfile.DIRTYPE, ''), ('alias', tarfile.SYMTYPE, 'dir')],
            }
            for name, entries in negatives.items():
                data = fixture(base + entries)
                private_write(self.evidence / ('archive-' + name + '.tar'), data)
                destination = root / name
                destination.mkdir(mode=0o700)
                try:
                    extract_snapshot(data, destination)
                except RuntimeError as error:
                    records[name] = {'archive_sha256': digest(data), 'rejected': str(error)}
                else:
                    raise AssertionError('Unsafe archive accepted: ' + name)
                if any(destination.iterdir()) or outside.read_bytes() != b'outside must remain unchanged' or set(root.iterdir()) != {outside, destination}:
                    raise AssertionError('Archive wrote before validation or outside destination: ' + name)
                destination.rmdir()
                records[name]['empty_destination'] = True
                records[name]['outside_unchanged'] = True
        self.report['archive_controls'] = records
        self.report['archive_control_scratch_absent'] = not root.exists()

    def run(self):
        self.archive_controls()
        deployed = self.provision('staging')
        first = self.app(deployed, 'staging-first', prepare=True)
        self.replace_storage(first)
        second = self.app(deployed, 'staging-second', mode='read', owner_id=first.get('owner_id'))
        self.persistence(first, second, 'synthetic-staging-uploads-73')
        # Independent server-side SQL readback is not a cached in-process Blob.
        self.inspect_owned(deployed)
        _, data = self.mysql(deployed, 'USE `%s`; SELECT b.id,b.key,b.service_name,b.byte_size,a.record_id,a.record_type FROM active_storage_blobs b JOIN active_storage_attachments a ON a.blob_id=b.id;' % deployed['databases']['primary'])
        private_write(self.evidence / 'independent-metadata.tsv', data)
        if first['key'].encode() not in data or b'55' not in data or b'StorageWitness' not in data:
            raise AssertionError('Independent real metadata rows were not observed')
        self.report['independent_metadata_sha256'] = digest(data)
        prod_first = self.app(deployed, 'production-first', profile='production')
        self.replace_storage(prod_first)
        prod_second = self.app(deployed, 'production-second', mode='read', profile='production', owner_id=prod_first.get('owner_id'))
        self.persistence(prod_first, prod_second, 'synthetic-production-uploads-73')
        # Falsify the same read detector using only the bytes produced by the actual first put.
        object_path = Path(deployed['scratch']) / 'objects' / digest(('synthetic-staging-uploads-73\0' + first['key']).encode())
        stored = object_path.read_bytes()
        object_path.unlink()
        missing = self.app(deployed, 'missing-stored-object', mode='read', owner_id=first['owner_id'])
        if missing.get('success') or missing['error']['class'] != 'ActiveStorage::FileNotFoundError':
            raise AssertionError('Missing stored-object control did not reach real get_object')
        private_write(object_path, b'73 deliberately corrupted bytes')
        corrupt = self.app(deployed, 'corrupt-stored-object', mode='read', owner_id=first['owner_id'])
        if corrupt.get('success') or corrupt['error']['message'] != 'Stored object content mismatch':
            raise AssertionError('Corrupt stored-object control did not fail')
        private_write(object_path, stored)  # Restore actual put bytes, never seed a successful fake response.
        restored = self.app(deployed, 'restored-object', mode='read', owner_id=first['owner_id'])
        self.persistence(first, restored, 'synthetic-staging-uploads-73')
        denied = self.app(deployed, 'access-denied', mode='denied')
        if denied.get('success') or denied['error']['class'] != 'Aws::S3::Errors::AccessDenied' or denied.get('disk_files') or not denied.get('api_requests') or not any(row.get('record_id') == denied.get('owner_id') for row in denied.get('failure_metadata_rows', [])):
            raise AssertionError('Visible after-commit denial boundary not established')
        denied_key = denied['s3_requests'][0]['key']
        denied_path = Path(deployed['scratch']) / 'objects' / digest(('synthetic-staging-uploads-73\0' + denied_key).encode())
        if denied_path.exists():
            raise AssertionError('Denied callback stored a successful object')
        for profile in ['staging', 'production']:
            for key in ['ACTIVE_STORAGE_' + profile.upper() + '_BUCKET', 'ACTIVE_STORAGE_S3_REGION']:
                for label, value in [('absent', None), ('blank', ' \t ')]:
                    name = profile + '-' + key.lower() + '-' + label
                    failure = self.app(deployed, name, profile=profile, settings={key: value})
                    if failure.get('success') or failure['error']['class'] != 'UploadStorage::ConfigurationError' or key not in failure['error']['message'] or failure.get('s3_requests') or failure.get('disk_files'):
                        raise AssertionError('Visible missing-config/no-Disk boundary failed: ' + name)
            assets = self.app(deployed, profile + '-assets', mode='assets', profile=profile)
            if not assets.get('success') or assets.get('selected_service') != 'upload_build_only' or not assets.get('build_upload_control') or assets.get('s3_requests'):
                raise AssertionError('Actual credential-free assets:precompile not established')
        disk_first = self.app(deployed, 'disk-mutant-first', disk=True)
        self.replace_storage(disk_first)
        disk_second = self.app(deployed, 'disk-mutant-second', mode='read', owner_id=disk_first.get('owner_id'), disk=True)
        try:
            self.persistence(disk_first, disk_second, 'synthetic-staging-uploads-73')
        except AssertionError as error:
            self.report['disk_falsification'] = str(error)
        else:
            raise AssertionError('Disk mutant was accepted by the actual persistence detector')
        if disk_second.get('success') or disk_second['error']['class'] != 'ActiveStorage::FileNotFoundError':
            raise AssertionError('Disk local-filesystem loss control did not reach')
        local = self.app(deployed, 'development-absent-s3', mode='inspect', profile='development')
        test_resource = self.provision('test')
        migration = self.app(test_resource, 'migration-reversibility', mode='migration', profile='test')
        if (not migration.get('success') or not migration.get('schema_matches_engine') or
                not migration.get('migration_down_clean') or not migration.get('migration_roundtrip_equal')):
            raise AssertionError('Official migration equivalence/reversibility not established')
        test = self.app(test_resource, 'test-absent-s3', mode='inspect', profile='test')
        if not local.get('success') or not test.get('success') or any(case['service_class'] != 'ActiveStorage::Service::DiskService' for case in [local, test]):
            raise AssertionError('Actual local/test Disk parsing without S3 settings failed')
        self.report['builder_gates_passed'] = True

    def cleanup(self):
        for resource in reversed(self.resources):
            if resource.get('container_id'):
                self.inspect_owned(resource)
                port = resource['port']
                self.command(['docker', 'rm', '-f', resource['container_id']])
                code, data = self.command(['docker', 'container', 'inspect', resource['container_id']], check=False)
                if code == 0:
                    raise RuntimeError('Container absence not established')
                # A live daemon read distinguishes actual absence from lost Docker access.
                self.command(['docker', 'info', '--format', '{{.ServerVersion}}'])
                _, remaining = self.command(['docker', 'container', 'ls', '-aq', '--filter', 'id=' + resource['container_id']])
                if remaining.strip():
                    raise RuntimeError('Owned container still registered')
                import socket
                with socket.socket() as probe:
                    if probe.connect_ex(('127.0.0.1', port)) == 0:
                        raise RuntimeError('Owned loopback port still accepts connections')
            else:
                port = None
            if resource.get('volume_created'):
                _, data = self.command(['docker', 'volume', 'inspect', resource['volume_name'], '--format', '{{json .Labels}}'])
                if json.loads(data).get('railsstarter73.nonce') != resource['nonce']:
                    raise RuntimeError('Refuse foreign volume cleanup')
                self.command(['docker', 'volume', 'rm', resource['volume_name']])
                code, _ = self.command(['docker', 'volume', 'inspect', resource['volume_name']], check=False)
                if code == 0:
                    raise RuntimeError('Owned volume still exists')
                self.command(['docker', 'info', '--format', '{{.ServerVersion}}'])
                _, remaining = self.command(['docker', 'volume', 'ls', '-q', '--filter', 'name=' + resource['volume_name']])
                if remaining.strip():
                    raise RuntimeError('Owned volume still registered')
            if resource.get('scratch'):
                scratch = Path(resource['scratch'])
                owner = json.loads((scratch / '.owner.json').read_bytes())
                if owner != {'nonce': resource['nonce'], 'source_root': str(ROOT)} or scratch.is_symlink():
                    raise RuntimeError('Refuse foreign scratch cleanup')
                shutil.rmtree(scratch)
                if scratch.exists():
                    raise RuntimeError('Owned scratch still exists')
            self.report['cleanup'].append({'nonce': resource['nonce'], 'container_absent': True, 'volume_absent': True,
                                           'port_closed': port, 'scratch_absent': True})
        self.report['all_children_reaped'] = all(item['reaped'] for item in self.report['processes'])


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    parser.add_argument('--ruby', default='ruby')
    parser.add_argument('--evidence-directory', type=Path)
    args = parser.parse_args()
    journey = Journey(args.ruby, args.evidence_directory)
    try:
        journey.run()
    except Exception as error:
        journey.report['error'] = str(error)
    finally:
        try:
            journey.cleanup()
        except Exception as error:
            journey.report['cleanup_error'] = str(error)
        journey.report['logs'] = journey.logs
        journey.report['evidence_directory'] = str(journey.evidence)
        private_write(journey.evidence / 'report.json', json.dumps(journey.report, indent=2))
    print(json.dumps(journey.report))
    return 0 if journey.report.get('builder_gates_passed') and not journey.report.get('cleanup_error') else 1


if __name__ == '__main__':
    raise SystemExit(main())
