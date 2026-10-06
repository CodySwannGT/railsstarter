# Compiled assets and deployment

## Opt-in ECS deployment

The starter has no executable default release/deployment workflow and no intended
live AWS target. The reviewed ECS workflow is preserved at
`templates/github/workflows/deploy-ecs.yml`, outside GitHub's executable
`.github/workflows/` directory. It is an opt-in template, not a callable reusable
GitHub workflow. Removing the executable caller disables both its push trigger
and manual dispatch; commenting out a branch alone would leave dispatch active.
No `deploy.enabled` or `deploy.disabled` configuration key is supported.

The template preserves the reviewed publication, image-digest and failure-order
behavior. All direct action/reusable references are pinned to verified full
commit SHAs; the dormant release pin was resolved from published Lisa 4.69.1.
This is template provenance, not adoption of that package in the starter.
The template preserves historical activation configuration, including a
`staging` trigger, branch checkout and
`cancel-in-progress: true`. These are activation debt, not safe defaults or
evidence of current deployment readiness. The separately owned release-outcome,
serialization and exact release-checkout correction (#74) must be reviewed and
tested before activation. No deployment credentials are needed to keep this
template inactive or to run the synthetic publication regressions.

For a generated consumer that explicitly chooses ECS deployment, configure its
inactive template first, then install it as an executable workflow:

1. Finish the release-outcome/checkout correction. Resolve the intended release
   commit once, verify its ancestry/availability, and use that exact SHA for
   checkout, image tagging and recorded release identity. Serialize release and
   deployment so a release-generated push cannot cancel its own deployment.
2. Select the normally published Lisa release compatible with the consumer's
   installed package and pin `release-rails.yml` to its verified full release
   commit SHA, and declare `expected_workflow_contract_major: '1'` in the release
   job's `with:` block after checking that selected revision's interface. Refresh
   the pinned action versions only through verified full commit SHAs with version
   comments. Include this inactive template in YAML and action pin validation.
   Preserve immutable refs; do not revert them to `@main` or tags.
3. Replace the historical trigger with the following main-only trigger. Keep
   `main` as the only permanent integration branch; no staging/dev branch is
   needed. Add `if: github.ref == 'refs/heads/main'` to the release job and require
   that same condition together with the reviewed release-success condition on
   the deploy job, so a dispatch from a feature ref cannot release or deploy.

   ```yaml
   on:
     push:
       branches: [main]
     workflow_dispatch:
   ```

4. Set every deployment environment value to the consumer's actual resource.
   The initial values are examples and must not be used as live targets:

   | Template value | Required configuration |
   | --- | --- |
   | `AWS_REGION` | Region containing the selected ECR/ECS/S3 resources |
   | `RAILS_ECR_REPO`, `WORKER_ECR_REPO` | Existing web/worker repositories in the intended ECR registry/account |
   | `CLUSTER_NAME` | Intended ECS cluster |
   | `RAILS_SERVICE_NAME`, `WORKER_SERVICE_NAME` | Existing web/worker services |
   | `RAILS_TASK_FAMILY`, `WORKER_TASK_FAMILY` | Existing task-definition families with their intended essential containers |
   | `RAILS_CONTAINER_NAME` | Exact web container name used by the migration override |

5. Configure the consumer's actual account and GitHub OIDC deployment role.
   Replace the branch-based account-secret action with an explicit main account
   secret reference, for example
   `role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_MAIN }}:role/DeployServiceRole`,
   using the actual role name. Keep `id-token: write` and `contents: read` on the
   deploy job. Restrict the role's OIDC trust to the intended repository/main
   subject and audience. Provision `DEPLOY_KEY` for the selected release
   workflow's documented write operations. Set secrets through the consumer's
   secret provider; never place credential values in YAML, source or image
   contexts.
6. Verify the CloudFormation exports in that account/region: a unique
   `ClientUploadBucket`-prefixed export identifying the asset bucket,
   `vpcPrivateSubnets` identifying the task subnets, and `ecsSecurityGroupId`
   identifying the task security group. If the consumer uses other export names,
   update the actual lookup expressions. The bucket must be the intended asset
   target; configure publication permissions and asset URL delivery explicitly.
   The deployment role needs scoped ECR push, these lookup/read operations,
   S3 publication, ECS task/service operations and `iam:PassRole` for the intended
   task roles. Runtime task credentials remain separate.
7. Run the deployment/publication regressions and workflow/pin validation on
   the configured inactive template. Review the actual main-only trigger, OIDC
   role, resource identities, release result and exact checkout before copying:

   ```sh
   mkdir -p .github/workflows
   cp templates/github/workflows/deploy-ecs.yml .github/workflows/deploy.yml
   ```

   Commit the configured template and caller in the generated consumer's
   reviewed PR into `main`. This copy is the activation boundary. A deployment
   result requires separate authorized live verification; local CLI fixtures
   and image checks do not establish S3/ECS success.

The retained local `bin/deploy-staging` command is an explicitly invoked operator
helper, not a GitHub trigger or permission to create a staging branch. Its
profile/resources must also belong to the consumer before any non-dry-run use.
`Verify Deployment Images` remains executable but builds and examines images
with synthetic fixtures; it does not release, push to ECR or update ECS.

## Publication guarantees

Web and worker images build without AWS deployment credentials. The web image
compiles assets with `SECRET_KEY_BASE_DUMMY=1`, EC2 credential discovery disabled,
and no network access. Dummy compilation skips the three AWS bootstrap loaders.
Normal runtime initialization and task IAM roles are unchanged.

After pushing images, publish the compiled web assets before registering ECS task
definitions, running migrations or replacing services. Both the opt-in template
and `bin/deploy-staging` capture the built image ID and resolve its pushed ECR
repository digest. Asset extraction uses that ID, and ECS uses that digest. A
missing or ambiguous digest, invalid manifest, failed extraction or failed upload
stops deployment before any ECS mutations.

For an independently built image already available in the local Docker daemon:

```sh
bin/publish-assets --image registry.example/app@sha256:<digest> \
  --bucket example-assets --profile example-staging --region us-east-1
```

The helper requires Bash, Docker, AWS CLI and jq. It resolves the image reference
once, creates a stopped container, and copies `/rails/public/assets` into a private
temporary directory. It never runs the image entrypoint. It requires a nonempty
Propshaft `.manifest.json` and every listed compiled file. The container and
temporary directory are removed on success, failure, and handled termination.
Extracted symlinks are rejected, and sync is also told not to follow symlinks.

The deployment process supplies short-lived AWS credentials through its normal
CLI credential chain: GitHub uses the assumed OIDC deployment role, and local
deployment uses the selected AWS SSO profile. Nothing exports credentials to a
file, forwards them to Docker builds, or installs/configures AWS CLI in an image.
The publication role needs permission to list the asset bucket and write objects
under `assets/`. Runtime task roles remain separate. Keep publication credentials
short-lived and scoped to deployment resources.

`bin/deploy-staging --service worker` requires no asset bucket and does not publish
assets. `--no-deploy` builds and pushes images only. `--dry-run` displays the
publication command without extracting or uploading assets. Full and web-only
deployments publish after all selected image pushes and before ECS updates.

Publication uses S3 sync without `--delete`. Older fingerprinted files remain
available while previous tasks are still serving pages and during rollback.
If uploading fails partway through, the old deployment remains in place and a
retry can complete the sync. Retention/lifecycle cleanup is a separate policy and
must preserve the rollback window. This helper publishes compiled assets only,
not Active Storage user uploads.

The Docker ignore rules also exclude deployment credential filenames, local AWS
configuration and private agent/session state. Do not place credentials under
arbitrary source filenames or bake secrets into generated assets.

For historical images built before this fix, an operator should assess repository
and registry history, restrict access to potentially affected image layers and
build caches, and revoke or rotate any exposed credentials according to their
type and validity. Removing a file in a later layer cannot erase an earlier
layer. This change does not inspect historical images or prove past credentials
were never used.

Run the focused shell/SDK regressions with `bundle exec rspec spec/deployment`.
The publication examples extract and execute the actual inactive template's run
steps and assert that no default executable deployment caller exists.
Real Docker build/export checks are also required: put only synthetic sentinel
files in an isolated context, build both Dockerfiles without AWS environment
variables or secret arguments, and inspect the final files and exported layers.
Local fixture checks establish failure ordering, not a live S3/ECS deployment.
## Real-image regression

Every pull request runs `Verify Deployment Images`. It builds both complete images with synthetic credentials in ignored paths, inspects every exported layer and image metadata, then extracts and validates the actual compiled assets. An authored AWS CLI fixture checks the asset bytes without contacting AWS. It exercises successful publication and a failing upload, verifies immutable image identity and stopped-container extraction, and checks cleanup. Build logs and JSON reports are retained as `deployment-image-evidence`.

Run the same checks locally after building web and worker images from a context containing a unique synthetic sentinel:

```bash
python3 bin/verify-deployment-images.py \
  --web-image your-web-image --worker-image your-worker-image \
  --sentinel-file /path/to/synthetic-sentinel \
  --report-directory /tmp/deployment-image-evidence
```

The scanner detects the supplied synthetic value and named credential/private paths. It does not assess historical registry images or identify arbitrary undisclosed secrets.

## Retired automation callers

The following five legacy Lisa callers referenced reusable workflows absent from
the supported upstream inventory. Their removal is an explicitly reviewed host
disposition; no Lisa ownership header was added to justify deletion.

| Retired caller | Capability lost and retained route |
| --- | --- |
| `claude-code-review-response.yml` | Automatic responses/remediation to review comments retire. Required review remains; fixes use reviewed PR/issue work. No equivalent autonomous response is claimed. |
| `claude-nightly-code-complexity.yml` | Scheduled autonomous complexity refactoring retires. PR Code Quality enforcement remains intended and must pass on the actual candidate. |
| `claude-nightly-test-coverage.yml` | Scheduled autonomous coverage test authoring retires. Meaningful test execution and the existing coverage floors remain required. |
| `claude-nightly-test-improvement.yml` | Scheduled autonomous test improvement retires. Test maintenance uses reviewed issue work; a dependency scan would not replace this capability. |
| `claude-sync-down-branches.yml` | The main-to-staging-to-dev synchronization route retires because the starter uses main-only integration. |

No replacement autonomous schedules or workers are enabled. `ci.yml`,
`validate-pull-request.yml` and `verify-deployment-images.yml` remain active.
The optional Sonar route is retained in `validate-pull-request.yml`; it is not a
substitute for enforced lint, security or complexity gates. Actual required
context/app parity, meaningful application coverage and fresh PR CI proof remain
delivery requirements. This disposition does not claim those pending checks have
passed or authorize lowering thresholds, skips or audit ignores.
