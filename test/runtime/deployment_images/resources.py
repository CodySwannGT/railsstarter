"""Positive Docker ownership and absence checks, including incomplete allocation."""
import re


def present(owner, kind, target):
    """Only a successful inventory query can establish absence."""
    if kind == 'volume':
        arguments = ('volume', 'ls', '--filter', 'name=^' + re.escape(target) + '$', '--format', '{{.Name}}')
    else:
        selector = 'id=' + target if re.fullmatch('[a-f0-9]{64}', target) else 'name=^/' + re.escape(target) + '$'
        arguments = ('container', 'ls', '--all', '--filter', selector, '--format', '{{.ID}}')
    return bool(owner.command(*arguments).stdout.strip())


def cleanup_resources(owner):
    """Attempt every resource independently and retain unresolved outcomes."""
    errors, observations = [], {}
    containers = [(name, lambda name=name: owner.owned_child(name), name) for name in owner.children]
    if owner.cid:
        containers.append((owner.cid, owner.owned_database, owner.name))
    for target, validate, pending_name in containers:
        try:
            if present(owner, 'container', target):
                validate()
                owner.command('rm', '-f', target)
                if present(owner, 'container', target):
                    raise RuntimeError('Owned container remains')
                owner.pending.discard(pending_name)
                observations[target] = 'removed-and-absent'
            elif pending_name in owner.pending:
                raise RuntimeError('Container allocation outcome remains unresolved')
            else:
                observations[target] = 'confirmed-absent'
        except Exception as error:
            observations[target] = 'unverified'
            errors.append(str(error))
    if owner.volume_created:
        try:
            if present(owner, 'volume', owner.volume):
                observed = owner.inspect('volume', 'inspect', owner.volume)[0]
                if observed.get('Labels', {}).get('runtime-image.nonce') != owner.nonce:
                    raise RuntimeError('Volume ownership differs')
                owner.command('volume', 'rm', owner.volume)
                if present(owner, 'volume', owner.volume):
                    raise RuntimeError('Owned volume remains')
                owner.pending.discard(owner.volume)
                observations[owner.volume] = 'removed-and-absent'
            elif owner.volume in owner.pending:
                raise RuntimeError('Volume allocation outcome remains unresolved')
            else:
                observations[owner.volume] = 'confirmed-absent'
        except Exception as error:
            observations[owner.volume] = 'unverified'
            errors.append(str(error))
    owner.report['cleanup'] = {'resources': observations, 'errors': errors,
                               'pending_allocations': sorted(owner.pending)}
    if errors or owner.pending:
        raise RuntimeError('Runtime image cleanup could not verify every reserved resource')
    owner.report['cleanup']['verified'] = True
