import base64
import json
import os
from pathlib import Path
import subprocess
import zlib


def git(*args, data=None):
    return subprocess.run(['git', *args], input=data, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=True).stdout.decode().strip()


spec = json.loads(Path('.github/package-work/spec.json').read_text())
ops = git('rev-parse', 'HEAD')
git('config', 'user.name', 'Boorusama package preparation')
git('config', 'user.email', 'package-preparation@users.noreply.github.com')
git('checkout', '--detach', spec['base'])
results = []
for stage in spec['stages']:
    branch = stage['branch']
    if not branch.startswith(('feature/', 'maintenance/', 'bug/')) or branch in ('develop', 'master'):
        raise RuntimeError('Invalid package branch')
    parent = git('rev-parse', 'HEAD')
    if delta := stage.get('delta'):
        patch = subprocess.check_output(['git', 'diff', '--binary', *delta])
        git('apply', '--3way', '--index', data=patch)
    for source, paths in stage.get('copies', {}).items():
        git('restore', '--source=' + source, '--staged', '--worktree', '--', *paths)
    if stage.get('patch'):
        patch = zlib.decompress(base64.b64decode(stage['patch']))
        git('apply', '--index', data=patch)
    actual = git('write-tree')
    if actual != stage['tree']:
        raise RuntimeError(f"Tree mismatch for {stage['id']}: {actual} != {stage['tree']}")
    git('diff', '--cached', '--check')
    remote = git('ls-remote', 'origin', 'refs/heads/' + branch)
    if remote:
        sha = remote.split()[0]
        git('fetch', 'origin', branch)
        if git('rev-parse', sha + '^{tree}') != actual:
            raise RuntimeError('Existing package branch differs; never overwrite: ' + branch)
        git('reset', '--hard', sha)
    else:
        git('commit', '-m', stage['message'])
        sha = git('rev-parse', 'HEAD')
        git('push', 'origin', sha + ':refs/heads/' + branch)
    results.append({'id': stage['id'], 'branch': branch, 'sha': sha, 'parent': parent, 'tree': actual})
git('checkout', '--detach', ops)
Path('package-assembly.json').write_text(json.dumps(results, indent=2) + '\n')
print(json.dumps(results, indent=2))
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    output.write('matrix=' + json.dumps({'include': results}, separators=(',', ':')) + '\n')
