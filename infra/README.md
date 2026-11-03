# infra
| version 0.0.0

OVHcloud infrastructure managed with Terragrunt and OpenTofu. It lives in
`infra/` and is deployed by the `terragrunt-plan` and `terragrunt-apply`
workflows; the Ansible part of the repository configures the VPS itself.

## Layout

```
configs/<env>/config.yaml  # values of an environment (ENV, default: production)
configs/<env>/CHANGELOG.md  # what each deployment of the environment shipped
modules/bootstrap/          # Terraform module: S3 user, policy and state bucket
modules/vps/                # Terraform module around ovh_vps
bootstrap/terragrunt.hcl    # standalone unit: state storage (project, user, bucket)
ovh/root.hcl                # root: ovh provider, S3 backend (OVHcloud Object Storage)
ovh/vps/terragrunt.hcl      # the VPS unit
scripts/bootstrap.sh        # creates the state storage and migrates its own state
scripts/env.sh              # loads .env and checks the required variables
Makefile                    # fmt, fmt-check and test of the modules
```

## Credentials

One OVHcloud method is enough; `scripts/env.sh` accepts any of them.
Secrets live in `infra/.env` (ignored by git). The commands of this document
are run from `infra/`:

```sh
cp .env.example .env
$EDITOR .env
chmod 600 .env
source scripts/env.sh
```

| Variable | Usage |
|---|---|
| `OVH_CLIENT_ID`, `OVH_CLIENT_SECRET` | OVHcloud API, OAuth2 service account (written by the bootstrap) |
| `OVH_ACCESS_TOKEN` | OVHcloud API, short-lived admin token (bootstrap only) |
| `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY` | OVHcloud API, classic keys (alternative to the two above) |
| `OVH_PROJECT_ID` | id of the Public Cloud project, read by the bootstrap only |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | S3 Object Storage (state) |

### OVHcloud API keys

1. Open <https://eu.api.ovh.com/createToken/> (`ovh-eu` endpoint).
2. Log in, name the script (`ovh-tf`) and pick a validity.
3. Rights, one per line: `GET /*`, `PUT /vps/*`, `POST /vps/*`.
4. **Create keys**, then copy `Application Key`, `Application Secret` and
   `Consumer Key` into `.env`.

These rights cover importing and managing an existing VPS. Ordering a VPS
from Terraform would also need `/order/*` and `/me/*`.

### Admin access token (bootstrap only)

The bootstrap creates IAM objects, so it needs an admin credential. Instead
of long-lived API keys, use a short-lived access token from an OAuth2
service account (client credentials flow).

1. **Create the service account** in the Control Panel: *Identity, Security
   & Operations* → *Identities* → *Service account* → *Add a service
   account*. Name it (e.g. `ovh-tf-admin`), then copy the `clientId` and the
   password (`clientSecret`) shown: the secret cannot be read back later.
2. **Give it rights** with an IAM access policy on that account. It needs
   what the bootstrap calls: the project (`/cloud/project/*`), OAuth2
   clients, IAM policies, and read access to the account. The API console
   (<https://eu.api.ovh.com/console/>) shows the required *IAM actions* of
   each route. A temporary broad policy, deleted once the bootstrap is done,
   is the simplest.
3. **Get a token** (valid about an hour; the EU endpoint is shown, use
   `https://ca.ovh.com/auth/oauth2/token` for `ovh-ca`):
   ```sh
   read -rs OVH_ADMIN_SECRET            # paste the clientSecret, nothing is echoed
   OVH_ACCESS_TOKEN="$(printf 'grant_type=client_credentials&scope=all&client_id=%s&client_secret=%s' \
       '<clientId>' "$OVH_ADMIN_SECRET" |
     curl -s --request POST --data @- 'https://www.ovh.com/auth/oauth2/token' |
     jq -r .access_token)"
   export OVH_ACCESS_TOKEN
   unset OVH_ADMIN_SECRET
   ```
   The response is JSON with `access_token`, `token_type` (`Bearer`) and
   `expires_in` (about 3600 seconds). Keep the token in the environment of
   the shell that runs the bootstrap rather than in `.env`.
4. **Run the bootstrap** from that shell: `scripts/bootstrap.sh`, or
   `scripts/bootstrap.sh --remote` once its state is in the bucket.

### Credentials for the other units

Once the bootstrap has run, `.env` holds `OVH_CLIENT_ID` and
`OVH_CLIENT_SECRET` (the scoped service account it created) and the
`AWS_*` keys. No token has to be fetched by hand for Terragrunt: the `ovh`
provider reads `OVH_CLIENT_ID` and `OVH_CLIENT_SECRET` and obtains and
renews its access tokens itself.

```sh
source scripts/env.sh
cd ovh/vps
terragrunt plan
```

If a tool other than the provider needs a raw token (e.g. `curl` on the
API), use the same call as above with `OVH_CLIENT_ID` and
`OVH_CLIENT_SECRET`. The admin token is then no longer needed, and the
admin service account and its temporary policy can be deleted.

### Bootstrapping the state storage

`bootstrap/` creates what the other units need to store their state: a
dedicated user with the *Object Storage operator* role, its S3 credentials
and policy, and the versioned bucket named `remote_state.bucket`. It can
also order the Public Cloud project (`bootstrap.order_project`, which needs
a default payment method on the account); otherwise set `OVH_PROJECT_ID` (in
`.env`, so that the id is not committed) to the id of an existing project.

Only one admin OVHcloud credential has to exist beforehand, in the
environment or in `.env`: an `OVH_ACCESS_TOKEN` (short-lived, e.g. obtained
from an OAuth2 service account with the client credentials flow), or API
keys. It needs `GET /*`, `POST`, `PUT`, `DELETE` on `/cloud/project/*`, and
for the OAuth2 client and its policies `POST /me/api/oauth2/client`,
`PUT`/`DELETE` on `/me/api/oauth2/client/*`, `POST /iam/policy` and
`PUT`/`DELETE` on `/iam/policy/*`. List the collection route (without `/*`)
as well as the wildcard: `.../client/*` does not match `.../client`. Ordering
a project also needs `/order/*` and `/me/*`. Then:

```sh
scripts/bootstrap.sh          # --yes skips the confirmation
```

`bootstrap.oauth2_client` also creates an OAuth2 service account (client
credentials flow) and, from `bootstrap.iam_policies`, the IAM policies that
say what it may do (the VPS and its IPs by default). The script writes
`OVH_CLIENT_ID` and `OVH_CLIENT_SECRET` into `.env`: the other units then run
with that account, and the admin credential is no longer needed for them. The
action names in `iam_policies` come from the provider documentation and the
OVHcloud guides; the API console shows the *IAM actions* each route needs, to
check them or to extend the list.

The script applies `bootstrap/` with a local state, writes the new
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` into `.env`, migrates the
state into the bucket it just created and removes the local copy. If the
migration is interrupted, `scripts/bootstrap.sh --migrate-only` resumes it.
`scripts/bootstrap.sh --write-env` only rewrites the `AWS_*` and
`OVH_CLIENT_*` lines of `.env` from the bootstrap outputs (e.g. after rotating the S3 credential); it reads
the remote state, so it needs working S3 credentials, or the local state if
it still exists. The admin credential cannot be generated this way: the bootstrap
needs it to run.
To change `bootstrap/` after the migration, run `scripts/bootstrap.sh --remote`
(or any command with `BOOTSTRAP_BACKEND=s3`), with the admin credential again. The state contains
the S3 secret key: keep the bucket private.

To adopt a user, policy or bucket that already exist instead of creating
them, import them first (from `bootstrap/`, with
`BOOTSTRAP_BACKEND=local`), using the project id and the user id
(`GET /cloud/project/{id}/user`):

```sh
terragrunt import ovh_cloud_project_user.this <project_id>/<user_id>
terragrunt import ovh_cloud_project_user_s3_policy.this <project_id>/<user_id>
terragrunt import ovh_cloud_storage_object_bucket.this <project_id>/<REGION>_<bucket_name>
```

The bucket id is the upper-case region followed by the bucket name, e.g.
`GRA_infra-ovh-tfstate`; the bare bucket name is rejected by the API.

The S3 credential is not imported (its secret cannot be read back): a new
one is created.

### S3 access for the state, by hand

The manual equivalent of the bootstrap above. Object Storage belongs to a
**Public Cloud** project.

1. **User**: Public Cloud → project → *Users & Roles* → add a user with
   the *Object Storage operator* role.
2. **S3 keys**: generate them from the Object Storage section if the
   interface offers it. Otherwise, through OpenStack:
   ```sh
   uv tool install python-openstackclient
   source openrc.sh      # the user's OpenStack configuration file
   openstack ec2 credentials create
   ```
   `access` → `AWS_ACCESS_KEY_ID`, `secret` → `AWS_SECRET_ACCESS_KEY`.
   The secret is displayed only once. Never commit `openrc.sh`.
3. **Bucket**: create an *S3 compatible API* container in the region set by
   `remote_state.region` (GRA by default), named after `remote_state.bucket`
   in `configs/<env>/config.yaml`. Enable versioning.
4. **Policy**: without a policy, the user gets `AccessDenied` on the
   bucket. Write the policy to `policy.json`:
   ```json
   {"Statement":[{"Sid":"tfstate","Effect":"Allow",
    "Action":["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket",
              "s3:GetBucketLocation","s3:ListBucketMultipartUploads",
              "s3:ListMultipartUploadParts","s3:AbortMultipartUpload"],
    "Resource":["arn:aws:s3:::<bucket>","arn:aws:s3:::<bucket>/*"]}]}
   ```
   then send it to the API (<https://eu.api.ovh.com/console/>):
   `POST /cloud/project/{serviceName}/user/{userId}/policy`, with the body
   `jq -n --rawfile p policy.json '{policy: $p}'` (the policy is an escaped
   JSON string in the `policy` field).

Check:

```sh
source scripts/env.sh
aws s3 ls s3://<bucket> --endpoint-url https://s3.gra.io.cloud.ovh.net --region gra
```

## Checks

```sh
make fmt-check   # tofu fmt and terragrunt hcl format, as the ci workflow does
make test        # tofu test of every module with a tests/ directory
```

The tests mock the OVHcloud provider: they need no credential. The `ci`
workflow runs both (`infra-fmt` and `infra-test`). The commands are run from
`infra/`; from the root of the repository use `make -C infra <target>`.

## Versioning

Each part is versioned by multicz from Conventional Commits (see
`multicz.toml`): `infra` (the wiring and the bootstrap unit),
`module-vps` and `module-bootstrap` (one component per module) are released
on every push to `main`, like the collection. The version of `infra` is the
`| version` line at the top of this file, the one of a module is the same line
in its `README.md`, and each has its `CHANGELOG.md`. `terragrunt-<env>` is the state applied on an environment: its
`version` key is in `configs/<env>/config.yaml`, its changelog next to it, and
it is bumped only after a successful apply.

## Deployment

Same flow as the Ansible one (see the README of the repository):

1. once **ci** and **release** succeeded on `main`, the **terragrunt-plan**
   workflow runs `terragrunt plan` for every `configs/<env>/` (GitHub
   environment `terragrunt-<env>-plan`);
2. if the plan has changes, or `main` differs from `terragrunt/<env>`, it opens
   a tracking issue and a pull request from `plan/terragrunt-<env>` into
   `terragrunt/<env>`. Both only carry a summary (`Plan: N to add...`, the
   commits and the files not deployed yet): the diff and the full plan are not
   posted, so that the repository can be public. The complete plan is stored in
   the private state bucket (`plans/terragrunt-<env>/<run id>/plan.txt`), and
   the pull request gives the `aws s3 cp` command to read it. The Ansible plan
   does the same under `plans/ansible-<env>/`. The bootstrap expires everything
   under `plans/` after `bootstrap.plans_retention_days` days (7 by default),
   with a lifecycle rule limited to that prefix: run `scripts/bootstrap.sh
   --remote` to create or change it;
3. merging that pull request runs **terragrunt-apply** (GitHub environment
   `terragrunt-<env>-apply`): it realigns `terragrunt/<env>` on `main`, applies, bumps
   `terragrunt-<env>` with a signed release commit, fast-forwards `main`, and
   publishes the GitHub release `terragrunt-<env>-v<version>`.

The `bootstrap/` unit is never run by the pipelines: it creates the state
storage and the credentials they use.

One-time setup, in addition to `GH_PAT` and the GPG secrets:

- Secrets `OVH_CLIENT_ID`, `OVH_CLIENT_SECRET`, `AWS_ACCESS_KEY_ID` and
  `AWS_SECRET_ACCESS_KEY` in the environments `terragrunt-<env>-apply` and
  `terragrunt-<env>-plan` (the values of `infra/.env` after the bootstrap).
- Create the branch once at the root commit:
  `git push origin "$(git rev-list --max-parents=0 main)":refs/heads/terragrunt/production`.
- The environment `terragrunt-<env>-apply` is restricted to the `terragrunt/*`
  branches and `terragrunt-<env>-plan` to `main`.

## Importing the existing VPS

1. Fill in `configs/production/config.yaml`: bucket, region, S3 endpoint,
   `vps.display_name`, `vps.netboot_mode`, and optionally `vps.keymap` and
   `vps.sla_monitoring`.
2. Import, using the VPS `service_name` (`vps-xxxxxxxx.vps.ovh.net`):
   ```sh
   source scripts/env.sh
   cd ovh/vps
   terragrunt import ovh_vps.this vps-xxxxxxxx.vps.ovh.net
   terragrunt plan
   ```
3. The plan should be empty, or close to it. If not, adjust `display_name`
   and `netboot_mode`, or `ignore_changes` in `modules/vps/main.tf`.

The keys under `vps:` in `configs/<env>/config.yaml` are passed as-is to the
module: they are the variables of `modules/vps/variables.tf`, which cover
every argument of the `ovh_vps` resource. Any variable missing from the
config is left unmanaged. `image_id` reinstalls the VPS when set or changed;
`plan`, `plan_option`, `ovh_subsidiary`, `public_ssh_key` and
`do_not_send_password` only matter at order time and are ignored once the
VPS exists.

### Reverse DNS

`vps.reverse_dns` (see `configs/production/config.yaml`) maps an address of the
VPS (`ips` output) to a hostname. The hostname must already resolve to that
address (A/AAAA record), otherwise OVHcloud refuses it. The API key must
also allow `PUT`, `POST` and `DELETE` on `/ip/*`. An existing record can be
imported with
`terragrunt import 'ovh_ip_reverse.this["<ip>"]' '<ip>/32|<ip>'`. The IPv6
address of the VPS has its own record (quote its key in the YAML file, its
block is a `/128`): `... '<ipv6>/128|<ipv6>'` for the import.

The module protects the VPS with `prevent_destroy`: destroying the resource
would terminate the OVHcloud service.
