// Host-owned, read-only diagnostic. Results are not provenance acceptance.
import { spawnSync } from 'node:child_process';
import { readFileSync, mkdtempSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  githubIssueViewArgs,
  githubHierarchyArgs,
  trackerContract,
} from './lisa-work-item.mjs';
import { assertPinnedVerifier } from './lib/github-attestation-verifier.mjs';

const PARENT = '7ca95181e9175d1e136c781709ac5be656e554f6';
const REPOSITORY = 'CodySwannGT/railsstarter';
const ISSUE = '96';
const sha = value => createHash('sha256').update(value).digest('hex');
const report = { kind: 'read-only-diagnostic', requests: [] };
const fail = code => { report.failure = code; throw new Error('control-failed'); };

function request(command, args, env, family) {
  const result = spawnSync(command, args, {
    encoding: 'utf8', env, timeout: 30000, maxBuffer: 1048576,
    killSignal: 'SIGKILL',
  });
  const status = result.status;
  report.requests.push({ family, status, signalled: result.signal !== null,
    nativeError: Boolean(result.error), outputBytes: Buffer.byteLength(result.stdout ?? ''),
    argvSha256: sha(JSON.stringify(args)),
  });
  if (result.error || result.signal || status !== 0) fail('native-request-failed');
  return result.stdout;
}

try {
  const bytes = request('git', ['show', `${PARENT}:.lisa.config.json`], process.env, 'committed-config');
  const config = JSON.parse(bytes);
  const policy = config.automationProvenance;
  if (policy?.repository !== REPOSITORY || policy.ghExecutable !== '/usr/local/bin/gh') fail('policy-failed');
  report.configSha256 = sha(bytes);
  if (process.argv[2] === '--check-gh') {
    if (process.argv.length !== 4 || sha(readFileSync(process.argv[3])) !== policy.ghSha256) fail('gh-identity-failed');
    report.outcome = 'pinned-gh-bytes-pass';
  } else {
    if (process.argv.length !== 2 || process.version !== 'v22.23.3' || process.platform !== 'linux' || process.arch !== 'x64') fail('runtime-failed');
    assertPinnedVerifier(policy);
    report.ghSha256 = policy.ghSha256;
    const root = mkdtempSync(join(tmpdir(), 'lisa-context-read-'));
    const ghConfig = join(root, 'gh-config');
    mkdirSync(ghConfig, { mode: 0o700 });
    const env = { PATH: '/usr/bin:/bin', HOME: root, LANG: 'C.UTF-8',
      GH_HOST: 'github.com', GH_CONFIG_DIR: ghConfig, GH_TOKEN: process.env.GH_TOKEN };
    if (!env.GH_TOKEN) fail('token-absent');
    request(policy.ghExecutable, ['--version'], env, 'gh-version');
    const issue = JSON.parse(request(policy.ghExecutable, githubIssueViewArgs(REPOSITORY, ISSUE), env, 'canonical-issue-view'));
    report.issueShape = issue && typeof issue === 'object' &&
      typeof issue.body === 'string' && Array.isArray(issue.labels) &&
      issue.labels.every(label => typeof label?.name === 'string') &&
      Array.isArray(issue.comments) && Array.isArray(issue.closedByPullRequestsReferences);
    if (!report.issueShape) fail('issue-shape-failed');
    const contract = trackerContract(config);
    report.issueIdentity = String(issue.number) === ISSUE;
    report.issueOpen = String(issue.state).toUpperCase() === 'OPEN';
    report.issueClaimed = issue.labels.some(label => label.name === contract.lifecycle.claimed);
    report.competingLifecycle = issue.labels.some(label => contract.lifecycle.roles.includes(label.name) && label.name !== contract.lifecycle.claimed);
    let after = null;
    const states = [];
    for (let page = 1; page <= 20; page++) {
      const value = JSON.parse(request(policy.ghExecutable, githubHierarchyArgs(contract, ISSUE, after), env, 'canonical-hierarchy'));
      const hierarchy = value.data?.repository?.issue?.subIssues;
      report.hierarchyShape = Array.isArray(hierarchy?.nodes) &&
        hierarchy.nodes.length <= 100 && hierarchy.nodes.every(node => typeof node?.state === 'string') &&
        typeof hierarchy.pageInfo?.hasNextPage === 'boolean';
      if (!report.hierarchyShape) fail('hierarchy-shape-failed');
      states.push(...hierarchy.nodes.map(node => node.state));
      if (!hierarchy.pageInfo.hasNextPage) { report.hierarchyComplete = true; break; }
      after = hierarchy.pageInfo.endCursor;
      if (typeof after !== 'string' || !after || Buffer.byteLength(after) > 1024 || /[\0\n\r]/.test(after) || after.startsWith('@') || /^(?:true|false|null|-?\d+(?:\.\d+)?)$/.test(after)) fail('cursor-failed');
    }
    report.issueLeaf = !issue.labels.some(label => label.name.toLowerCase() === 'type:epic') &&
      !states.some(state => !['closed', 'done', 'completed', 'canceled', 'cancelled'].includes(state.toLowerCase()));
    if (!report.hierarchyComplete || !report.issueIdentity || !report.issueOpen || !report.issueClaimed || report.competingLifecycle || !report.issueLeaf) fail('predicate-failed');
    report.outcome = 'direct-canonical-reads-pass';
  }
} catch {
  // Never expose caught errors, native stderr, provider JSON, body or token.
  report.outcome = 'control-failed';
  report.failure ??= 'parse-or-configuration-failed';
  process.exitCode = 1;
}
process.stdout.write(`${JSON.stringify(report)}\n`);
