# Request security configuration

Staging and production require `ALLOWED_HOSTS`, a comma-separated list of exact
DNS names, IPv4 addresses or bracketed IPv6 addresses. Values are normalized to
lowercase and deduplicated. Empty entries, wildcards, leading-dot subdomain
patterns, URLs, ports, CIDRs and malformed identities fail boot with a sanitized
configuration error. Rails permits request ports on a configured host identity;
this is host authorization rather than exact-origin authorization. Supply your
own deployment identities. Disabling AWS bootstrap or setting a dummy secret
does not disable this validation.

Rails validates both the request Host and the last forwarded Host. Only the exact
request path `/up` is exempt from host rejection and SSL redirects, including a
query string. `/up/`, `/up-other`, uppercase and encoded lookalikes receive no
exemption. `assume_ssl` and `force_ssl` remain enabled. Proxy TLS assumptions and
the SSL redirect exclusion are separate: the tests exercise real SSL middleware
without AssumeSSL as well as the full deployed application. Health reports boot
liveness, not database readiness. JSON health checks avoid relying on the built-in
HTML health page's inline styling, which this policy does not authorize.

An exclusive, actual Rails/Rake `assets:precompile` invocation with
`SECRET_KEY_BASE_DUMMY=1` may omit hosts because it builds assets without serving
requests. Ordinary runner/server processes and mixed task invocations still
require hosts. This exception is independent of AWS and upload storage. It does
not authorize storage credentials or change the normal asset/S3 publication
contract.

The enforced CSP permits same-origin assets and the exact authored Bootstrap
5.3.8 CSS and JavaScript resources. Existing Bootstrap integrity pins remain
unchanged. A cryptographically random nonce is generated per request; Rails'
importmap helper and Turbo propagate it to inline scripts and the progress
stylesheet. Data images are allowed for Bootstrap SVG icons. Objects and framing
are denied, forms and base URLs are same-origin, and no broad HTTPS, wildcard,
unsafe-inline or unsafe-eval grant is used. `CLOUDFRONT_ENDPOINT`, if supplied,
must be one HTTPS origin without credentials, query, fragment or non-root path.
Only that origin is added to the asset directives. No CSP/host disable switch is
provided; editing these guarantees requires deliberate application configuration.

The DB-free request and Chrome fixtures use the real application, global AWS SDK
stubs and explicit database refusal. They observe headers/nonces, real CSS and
module execution, navbar/flash/Turbo navigation, and unauthorized-origin,
missing-nonce and corrupted-integrity controls. Existing Bootstrap scenarios
remain separate. The released Lisa BDD checker and matrix generator are wired
through the project commands and required CI caller described in
[the BDD checks](bdd-checks.md). Generated reports distinguish authored mappings
from supplied execution results; they do not imply hosted CI passed.

Anonymous requests now share a fixed-window quota across application processes,
using an atomic dedicated table in the existing MySQL cache database. The generic
starter default is 120 requests per 60 seconds. Configure the quota for your
application's traffic using `REQUEST_RATE_LIMIT` and `REQUEST_RATE_PERIOD`, which
accept strict positive decimal integers. There is no authentication boundary in this starter,
so cookies or Authorization headers do not grant a quota exemption.

Run the normal cache migration before enabling traffic (`bin/rails db:migrate:cache`).
`CacheRecord` owns a separate cache connection even in test; the counter does not
inherit the primary connection or use the general SolidCache entries table.
A unique SHA-256 key namespaces the environment, fixed window and canonical
client. InnoDB atomically materializes, locks and increments one aggregate row.
The first expiry is retained. General cache pressure, expiration and clear cannot
reset this row. Counts never return nil, reset to one, or retry an ambiguous SQL
commit. Established quota excess returns 429 with Retry-After and no-store;
operational counter failure returns a sanitized 503. Exact `/up`, including its
query string, bypasses both identity and counter access; the original path is
checked before RackAttack normalization, so `/up/` is not exempt.

`PruneRequestRateLimitsJob` removes at most 1000 expired rows per invocation and
is scheduled every minute alongside the existing recurring jobs. Active buckets
survive. Ensure the queue worker runs; housekeeping is required to bound storage,
while retained expired rows never reset the quota. Fixed windows permit a burst
at the boundary, clients behind one NAT share a quota, and synchronized clocks
are required across processes. The configured limits are request controls rather
than a connection, bandwidth or distributed attack defense.

Choose `REQUEST_INGRESS_PROFILE` explicitly for ordinary staging/production boot.
Development and test default to `direct`, which uses the socket REMOTE_ADDR and
ignores all forwarded identity headers. `thruster` requires
`THRUSTER_TRUSTED_PEERS` and selects the last address appended by Thruster.
`alb` requires `ALB_TRUSTED_PEERS` and selects the last ALB append-mode address.
`alb_thruster` requires both lists: validate the immediate Thruster peer and the
last appended ALB hop, then select the preceding client. Earlier attacker tokens
are ignored. Private client addresses remain clients. IPv4, IPv6, IPv4 ports and
bracketed IPv6 ports are validated and equivalent mapped IPv4 forms normalize.
Missing, malformed and mismatched topology fails with 400 or 403 before quota
access. Rails' independent spoof detection remains active.

Peer lists accept explicit addresses and nonzero CIDRs, with no implicit private
network trust or catch-all CIDR. They define an actual trust boundary: restrict
application-port access to the selected ingress and prevent untrusted processes
from using those peers. Configure the ALB's actual append behavior and topology;
no live AWS ingress or security-group configuration is established by local
starter tests. Thruster must preserve incoming forwarding headers for the
ALB-plus-Thruster profile. The public fixtures prove installed Thruster transport
and a clearly labeled local ALB append model, not a deployed ALB. This supports
exactly the selected topology, not an inferred arbitrary chain of proxies.

`REQUEST_RATE_LIMIT_ENABLED=false` deliberately disables quota storage for an
operational escape or independent DB-free fixture. It does not disable ingress,
host or CSP validation. Genuine exclusive dummy-key asset precompilation disables
quota storage and may omit runtime ingress; dummy runner/server or mixed tasks
are not build contexts. All host, SSL, Bootstrap integrity and S3/asset contracts
remain separate and enforced.

Run the public focused checks with the locked Ruby 3.4.11 bundle:

```sh
bundle exec rspec spec/configuration/request_policy_spec.rb spec/models/request_rate_limit_counter_spec.rb spec/jobs/prune_request_rate_limits_job_spec.rb spec/requests/request_rate_limits_spec.rb spec/browser/request_rate_limits_spec.rb
```

The runtime fixtures require local Docker with a Unix socket and MySQL 8.4.11,
plus native Thruster from the locked bundle. Chrome and its compatible driver use
public executable discovery or explicit `CHROME_BIN` and `CHROMEDRIVER`; Docker
uses `DOCKER_BIN` or PATH. They create a fresh labeled container and volume,
restricted synthetic user and four guarded schemas, execute source-identical
snapshots and clean only recorded owned resources with monotonic deadlines and
positive absence readbacks. Source schemas are never changed by running specs.

The focused checks retain their actual coverage exits. Full 80/70 coverage and
hosted Linux AMD64 CI require their own actual runs. The independent DB-free
CSP CLI fixture explicitly uses direct
ingress, a valid socket address and disabled quota storage. It clears ambient
request/proxy inputs while retaining its host, CSP, SSL and asset-task controls.

Framework contracts: [RackAttack 6.8 counter/window code](https://github.com/rack/rack-attack/blob/v6.8.0/lib/rack/attack/cache.rb),
[Rails multiple database connections](https://guides.rubyonrails.org/active_record_multiple_databases.html).
