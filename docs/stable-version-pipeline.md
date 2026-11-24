# Jenkins stable-version discovery

The pipeline in `Jenkinsfile.stable-versions` uses self-hosted Renovate to
discover dependency updates and open pull requests in their owning GitHub
repositories. It does not install or validate updates and does not access a
Kubernetes cluster.

## What it covers

Renovate reads the default branch of each configured repository. It inspects
recognized Helm charts, Helm values, Dockerfiles, Docker Compose files, and pip
requirements. Custom rules additionally cover the Agent Sandbox version and
the vendored Redis Stack server image tag. Matching files in a repository can
include disabled components and dependencies unrelated to the deployed stack.
The discovery report is not an inventory of what is actually running.

Renovate ignores versions it recognizes as unstable or prerelease. A proposed
version is an upstream candidate, not an Intel-certified compatibility claim.
Image tag conventions differ and some floating tags do not identify an
immutable release. The pipeline does not update firmware, OS packages,
Kubernetes installations, models, external services, or versions hidden in
unrecognized templates and runtime environment overrides. For complete
coverage, compare the discovery report to your deployment inventory and add
verified managers or rules for each missing component.

Agent-toolkit and inference files under `ext/` and environment files under
`env/` are ignored by this checkout. Pull requests against the source
repositories do not update those existing local copies or already deployed
environments.

## Jenkins setup

1. Commit `Jenkinsfile.stable-versions` and `ci/renovate-config.json` to a
   trusted repository branch. Review this configuration before granting it
   credentials.
2. Provide a trusted Jenkins agent labeled `docker`, with Bash, Docker, `jq`, access
   to `renovate/renovate:44.257.9`, GitHub, and the relevant package registries.
   The job launches a container through the agent's Docker daemon; it does not
   mount the daemon socket into that container. Configure `HTTP_PROXY`,
   `HTTPS_PROXY`, and `NO_PROXY` on the agent if required. Configure trusted CA
   certificates for the agent and container if the proxy performs TLS
   inspection. Do not copy environment-specific proxy credentials into Git.
3. Create a Jenkins **Secret text** credential with ID
   `renovate-github-token`. Use a dedicated GitHub bot with read access to
   repository contents and metadata. To create pull requests, grant it contents
   write and pull request read/write access to each target repository. Use
   organization-approved credentials and permissions. A read-only token is
   sufficient for an initial discovery-only run.
4. Create a Pipeline job using **Pipeline script from SCM** and select
   `Jenkinsfile.stable-versions` as the script path. Restrict who can configure
   or run the job and access its artifacts. Never expose the credential to
   untrusted pull request builds or untrusted repository configurations.
5. Run with `CREATE_PRS=false` first. Set `REPOSITORIES` to the exact GitHub
   repositories the bot may access, in `owner/repo,owner/repo` format with no
   spaces. Check the `stable-discovery.jsonl` artifact and reconcile its
   extracted dependencies with the intended component inventory.
6. After reviewing coverage, run with `CREATE_PRS=true`. Renovate opens or
   updates its pull requests in the respective repositories. It does not
   merge them. Each target must permit the bot to push branches and create
   pull requests. The configured repository default branch is the base; arrange
   a repository-specific base branch policy if another branch is needed.
7. Once the dry run and pull requests are verified, set an approved Jenkins
   build schedule. Scheduled builds use the parameter defaults; change the
   default of `CREATE_PRS` deliberately if scheduled runs should create PRs.

Both stages fail if Renovate logs warnings or errors, or if its report does not
show extracted dependencies for every requested repository. Investigate the
archived log instead of treating an incomplete scan as a successful run.

The PR stage performs its own lookup; releases or base branches can change
between the two stages, so a PR may differ from the discovery report. Renovate
can create some PRs before a later repository or registry fails. Inspect the
logs and existing PRs after a failed run. A successful process exit does not
guarantee that every expected component was recognized: inspect the report,
including skipped dependencies, and add explicit coverage checks
before relying on it as a complete inventory.

Pull requests require human review and a separate compatibility, deployment,
and validation workflow. Renovate is configured not to automerge; this pipeline
does not provide test, compatibility, backup, or rollback gates.
