[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 111 - image analysis, static fixes, and supply-chain evidence

## Goal

In this CKS lab you collect reproducible evidence artifacts for a containerized
application: vulnerability reports and static analyzer reports, safe fixes to the
`Dockerfile` and the workload manifest, two SBOMs, a search for dependency versions, and the verification of an image
signature. The result is not just terminal output: each report must be
saved in the specified place and be suitable for an audit.

This is a CKS task about security tooling and the supply chain, and not a CKA exercise. Most of the
artifacts are analyzed locally on the worker; tasks 1c, 4, 5b and 9a-9c additionally work with
the cluster (live Deployments, a hardened Deployment with a Ready/Available check and an HTTP smoke test, a Kyverno policy and a Pod).

## Threat model

The lab models trust in the supply chain through several independent threats. Malicious
code or known weaknesses in an image are detected by the scanners Trivy, kubesec,
kube-linter, and Hadolint at the corresponding levels of the image, the Dockerfile, and the manifests.

Secrets and tokens accidentally left in a layer require a separate check: secret
scanning (for example Trivy secret scanning) and inspection of the image history (`docker history`,
extracting layers). An SBOM solves a different task - an inventory of components and package
versions; it helps a supply-chain investigation (for example, to find a vulnerable library),
but it is not a reliable mechanism for finding secrets in the history of layers and does not replace secret
scanning. Even if the working configuration no longer contains the secret, it may remain
available in the history of the layers.

The mutable-tag tampering threat is that after deployment, under an unchanged reference with
a tag, a different, malicious image can be substituted. This is exactly why digest pinning is important in
tasks 3–5: it pins the specific content of the image, and not only its name and tag.

The signature verification in task 7 proves that a specific digest is signed by a trusted
key/identity (signature integrity), whereas the Trivy scan in task 1 only shows that it found no
known vulnerabilities that fall within its detection coverage under the current vulnerability DB
(Trivy itself documents a trade-off in favor of precision, under which false
negatives are possible - "0 findings" is not a formal proof of the absence of vulnerabilities). These are different axes of
protection: neither replaces the other, since vulnerability != signature. A signature is
NOT the same as provenance/attestation
(for example SLSA-style build metadata about what the artifact was built from and how): `cosign
verify` confirms the authenticity of the signature, and not the full history of the build - for attestation
Sigstore provides separate commands `cosign attest`/`cosign verify-attestation`, which are not
used in this lab.

A local `cosign verify` (task 7) is not enforcement by itself: it proves the
signature of a specific image reference at the time of the check, but does not prevent someone from running
an unsigned or otherwise signed image with a direct `kubectl apply`, bypassing CI. Only an
admission-time check (task 9a-9c) makes the signature a mandatory condition for admitting a
Pod into the cluster - this is the difference between "we verified the signature" and "the cluster will not run an
unsigned image".

Proving this property requires care: a repeated `kubectl apply` of an already
existing Deployment does not create a new Pod if the template has not changed, so
`Running` may mean "an old Pod created before the policy", and not "the policy admitted
exactly this image" (task 9b checks `creationTimestamp` explicitly). Likewise an unsigned
DENY proves the property only if the digest being checked really exists and is pullable in
the same repository as the signed image (task 9c) - otherwise admission may refuse
because of a manifest missing in the registry, and not because of the absence of a signature.

## Self-check before you start

<details>
<summary>1. Why is an SBOM not a reliable mechanism for finding secrets left in an image layer?</summary>

An SBOM solves the task of inventorying COMPONENTS and package versions (what is installed, which version) - this is a structural analysis of package manager metadata, and not a search for arbitrary strings/secrets in the content of the layer files. A secret left, for example, in an ENV environment variable or a temporary file during the build may remain in the layer history even after the final layer no longer contains it - this needs a separate tool (secret scanning, `docker history`, extracting layers), and not an SBOM.
</details>

<details>
<summary>2. What is the difference between what a Trivy scan (task 1) proves and what a Cosign signature (task 9a-9c) proves?</summary>

At the time of the check, with the current vulnerability DB and Trivy's detection logic, the scan did NOT DETECT known vulnerabilities that fall within its detection coverage - this is about the quality/safety of the image content to the extent that Trivy is able to see it. The Trivy documentation itself explicitly describes a trade-off in favor of precision (minimizing false positives), under which false negatives are possible - that is, "0 findings" is not equivalent to a formal proof of the complete absence of vulnerabilities. A Cosign signature proves SIGNATURE INTEGRITY - that a specific digest is signed by a trusted key/identity, that is, someone authorized confirmed that this is exactly the artifact that should be deployed. This is NOT the same as provenance/attestation (the full build history - from what, by whom, and how the artifact was built): for attestation Sigstore has separate commands (`cosign attest`/`cosign verify-attestation`) that are not used in this lab. An image can be completely safe (0 CVE) and still not signed - or signed but contain an unknown vulnerability. These are two independent axes of protection.
</details>

<details>
<summary>3. Why does a local `cosign verify` in CI not prevent someone from deploying an unsigned image via `kubectl apply`?</summary>

A `cosign verify` executed locally (for example, in a CI pipeline) is just one command that checks the signature and returns the result to whoever called it. It is not built into the Kubernetes API admission path - nothing prevents someone with access to the cluster from simply running `kubectl apply` with ANY image, bypassing CI completely. Only an admission-time check (task 9a-9c), built into the cluster itself as a policy, makes the signature a MANDATORY condition for admission - this is the difference between "we checked" and "the cluster physically will not let it through".
</details>

## Infrastructure

The environment is created by Terragrunt in AWS `eu-central-1`.

| Component | Purpose |
|---|---|
| `vpc` | VPC `10.111.0.0/16` with public subnets |
| `ssh-keys` | access to the node |
| `k8s-1` | a single-node kubeadm Kubernetes `1.36.0`, containerd, and **Calico** |
| `worker` | a workstation for analysis, `kubectl`, `check_result`, and the security tools |

The infrastructure is CKA-style: the only control-plane node is allowed for workloads and
labeled `cks.io/lab=111`. The main commands and security tools are run on the worker.
The Kubernetes cluster is used as the target environment for checking the hardened workload and the
admission-time signature policy: task 4 deploys `catalog`, and tasks 9b/9c
perform the positive/negative admission probes.

Exactly these fixed versions are available in advance on the worker:

| Tool | Version | Purpose |
|---|---:|---|
| Trivy | `0.74.0` | CVEs and the package list of an image |
| kubesec | `2.14.0` | the security score of Kubernetes YAML |
| kube-linter | `0.8.3` | policy lint of Kubernetes YAML |
| Hadolint | `2.12.0` | Dockerfile lint |
| Syft | `1.51.0` | SBOM CycloneDX JSON |
| bom | `0.8.0` | SBOM SPDX JSON (the native format of `bom`) |
| Cosign | `3.1.3` | signing and verification of the signature of an OCI image |

Helm and `install-kyverno` are also available on the worker, but Kyverno is deliberately **not installed**:
its installation is part of task 9, as in lab 108. `install-kyverno` pins Kyverno
`1.19`/chart `3.9.0`; the official upstream support matrix for this version is Kubernetes
`1.33-1.35`, whereas this cluster is on `1.36`. This is a conscious lab-specific exception outside the
tested range (similar to the precedent in lab 108), and not guaranteed
official support - remove this exception when updating Kyverno.

## Prerequisites and limitations

**podman and the registry are already configured in the lab environment.** For building and publishing images use `podman`
(a tool from the exam list; rootless, as the user `ubuntu`). Tasks 3 and 9c require building and
**publishing** an image to a registry that is reachable both from the worker and from the cluster (the immutable reference
`repo@sha256:...` is taken from the registry, a local image ID does not work). Such a registry -
`registry:2` on the control-plane - is brought up by the bootstrap:

- the address: `<IP control-plane>:5000`, it is written in `/etc/cks111/registry` on the worker;
- the protocol is plain HTTP inside the VPC: podman on the worker and containerd on the node are configured for it as an
  insecure registry (the flag `--tls-verify=false` is not needed), and the Kyverno `ImageValidatingPolicy` needs
  `credentials.allowInsecureRegistry: true`;
- the data is stored on the local PV of the node (`/var/lib/cks111-registry`), so it survives a
  restart of the registry Pod;
- get the digest of a published image from `podman push --digestfile`, and check the presence of a manifest
  with a request to `/v2/` (HTTPS-only tools like `docker buildx imagetools` do not work with this registry);
- the detailed sequence of commands is in the step "0. Preparation" of the [solution](worker/files/solutions/1.MD).

**The Docker Hub limit.** Anonymous pulls from one IP have a limit (about 100 requests per 6 hours).
So that `check_result` does not run into it, the bootstrap downloads the lab images once into a local cache
(`nginx:1.27.3-alpine` and the candidates for tasks 1b/1c), and Trivy and Syft on repeated scans take the
image from this cache by the same reference `name@sha256:...`, without calling Docker Hub. `bom` can
read an image only from a registry, so it still makes several requests per run.
If Docker Hub still returns `TOOMANYREQUESTS`, wait (the limit window is sliding) or run
`podman login docker.io` under your own account.

**Cosign and the key password.** `cosign generate-key-pair` and `cosign sign --key` ask for the key
password; for a lab key pair you can leave it empty (`export COSIGN_PASSWORD=""`), so that the commands
do not wait for input.

**`trivy sbom` and an SBOM without an OS (task 8).** The SPDX from `bom` for a multi-arch image contains no
information about the OS: Trivy writes `Detected OS family="none"` and finds no vulnerabilities (`Results` is empty).
Therefore in task 8 the CycloneDX from task 7 is scanned - it has an `operating-system` component,
and `trivy sbom` gives a non-empty `Results`.

## Deployment

```bash
TASK=111 make run_cks_task
```

Connect to the worker and select the context:

```bash
kubectl config use-context cluster1-admin@cluster1
cd /home/ubuntu/cks-111
check_result
```

Initially the `Dockerfile` and `deployment.yaml` are deliberately insecure. Create the working artifacts
only in `/var/work/tests/artifacts/<number>/`.

## Tasks

`nginx:1.27.3-alpine` is a mutable tag, and not a pinned reference. First obtain the canonical registry manifest digest from the `Metadata.RepoDigests[0]` of the Trivy JSON and use the immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` (hereinafter `$IMAGE`). For your own hardened image first build and publish the image to a registry reachable by the cluster, then use its manifest digest; a local image ID and a layer DiffID are not a registry manifest digest.

---
| **1** | **Trivy: an image vulnerability report** |
| :---: | :--- |
| What to do | • Scan the immutable `$IMAGE` with Trivy, including OS and library vulnerabilities.<br/>• Save the structured JSON in `/var/work/tests/artifacts/1/trivy-report.json`. |
| Acceptance criteria | • **The file:** non-empty, the JSON is parsed by `jq`, contains `Results` and the immutable reference of the analyzed image.<br/>• **A fresh check:** the checker itself repeats `trivy image` for the same image and requires that this fresh scan successfully match by `ArtifactName`.<br/>• A hand-written but syntactically valid JSON does not pass. |

<details>
<summary>💡 Hint for task 1</summary>

`$IMAGE` is built in two steps: first you scan `nginx:1.27.3-alpine` (a regular tag) and pull `Metadata.RepoDigests[0]` out of THIS first JSON report, then you rebuild the command with `nginx:1.27.3-alpine@sha256:<digest>` and scan the immutable reference - it is this second report that must be saved as the final one. Do not use `ImageID`/`DiffID` from the Trivy output as a substitute for the registry digest - those are LOCAL identifiers that do not match the manifest digest in the registry.
</details>

---
| **1b** | **Multi-image CVE triage: find the image that contains a specific CVE** |
| :---: | :--- |
| What to do | • Open `~/cks-111/candidates.txt` - it has three immutable image references (`CANDIDATE_1/2/3`) and the target `TARGET_CVE`, defined individually for your instance of the lab during the bootstrap.<br/>• Scan **all three** images with Trivy and find which of them really contains `TARGET_CVE`.<br/>• Save the JSON report of exactly this image in `/var/work/tests/artifacts/1b/target-scan.json`.<br/>• Save the line `OFFENDING_IMAGE=<the full reference of this image>` in `/var/work/tests/artifacts/1b/answer.txt`. |
| Acceptance criteria | • **The answer:** `answer.txt` points to exactly the `CANDIDATE_N` whose real Trivy scan contains `TARGET_CVE`.<br/>• **The report:** `target-scan.json` is the genuine Trivy output for the same image (the checker itself repeats the scan and compares). |

<details>
<summary>💡 Hint for task 1b</summary>

`TARGET_CVE` is different for each instance of the lab - it is computed during provisioning from the live Trivy vulnerability DB, and is not hard-coded in advance, so your own answer is in this file. Do not guess by the tag name ("the oldest is probably vulnerable") - really scan all three and find an exact match of the `VulnerabilityID` inside the JSON. One command per image: `trivy image --format json "$ref" | tee scan.json`, then `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | index("<TARGET_CVE>")' scan.json` - `null` means this specific CVE is absent from exactly this image (it may well contain other CVEs - this is not checked).
</details>

---
| **1c** | **Workload image triage by CRITICAL severity** |
| :---: | :--- |
| What to do | • In the namespace `cks-111` 4 Deployments (label `cks.io/task=1c`) are already deployed, each with one immutable digest-pinned image.<br/>• Get the image references from these LIVE Deployments (do not guess by the tag name), scan **all 4** images with Trivy with `--severity CRITICAL`, and count the number of unique CRITICAL `VulnerabilityID` for each.<br/>• Determine the Deployment with the largest number of CRITICAL ("the most vulnerable") and the two Deployments with the smallest number ("the two least vulnerable"). Write their names in `/var/work/tests/artifacts/1c/ranking.txt` as `MOST_VULNERABLE=<deployment-name>`, `LEAST_VULNERABLE_1=<deployment-name>`, `LEAST_VULNERABLE_2=<deployment-name>`.<br/>• For the image of the most vulnerable Deployment generate a CycloneDX SBOM **with Trivy specifically** (`trivy image --format cyclonedx`) into `1c/cyclonedx.json`.<br/>• Then remediate: leave `replicas > 0` only on the two least vulnerable Deployments, and scale the other two (including the most vulnerable) to `replicas: 0`. |
| Acceptance criteria | • **Ranking:** the checker itself repeats the Trivy CRITICAL scan of all 4 live images and recomputes the ranking - `ranking.txt` must match this fresh scan, and not a stale/guessed one.<br/>• **SBOM:** `cyclonedx.json` is a valid CycloneDX document from Trivy specifically, relating to the image of the really most vulnerable Deployment.<br/>• **Remediation:** exactly 2 Deployments (the least vulnerable by the fresh scan) have `replicas > 0`, the other 2 have `replicas: 0`. |

<details>
<summary>💡 Hint for task 1c</summary>

Get the image references with a command like `kubectl -n cks-111 get deployment -l cks.io/task=1c -o jsonpath=...` - do not try to guess from the name of the Deployment which image is "newer" or "safer". The counting command: `trivy image --scanners vuln --severity CRITICAL --format json <ref>`, then `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length'`. For CycloneDX use exactly `trivy image --format cyclonedx --output <file> <ref>` - not Syft (Syft is already used in task 7 for a different image; here Trivy is explicitly required). Scaling is done via `kubectl scale deployment/<name> -n cks-111 --replicas=0` (or `--replicas=1` for the ones you keep).
</details>

---
| **2** | **The initial static analysis reports** |
| :---: | :--- |
| What to do | • BEFORE the fixes (without touching any of these three files after the start of task 3) save the results: Hadolint in `2/hadolint-before.txt`, kubesec JSON in `2/kubesec-before.json`, kube-linter JSON in `2/kube-linter-before.json`.<br/>• Run them directly against the ORIGINAL starting `Dockerfile`/`deployment.yaml`.<br/>• Do not hide errors via `\|\| true` in the report files: a non-zero exit code of the linter is expected. |
| Acceptance criteria | • **Artifacts:** all three exist; Hadolint contains findings, kubesec contains `scoring`, kube-linter is a valid KubeLinter JSON object with the fields `Reports` and `Summary`; before the fixes `Reports` contains findings.<br/>• **Comparison with the baseline:** the checker compares the content of all three artifacts with its own baseline, taken during provisioning against the original starting files BEFORE they were handed to the student.<br/>• A hand-written but syntactically valid report does not pass. |

<details>
<summary>💡 Hint for task 2</summary>

A non-zero exit code from a linter when problems are found is the EXPECTED behavior, not an error of your command. If you wrap the call in `|| true` only so that the script does not stop with `set -e`, make sure that the output of the command is still saved to the file (via `tee` or a redirect BEFORE `|| true`), and is not lost.
</details>

---
| **3** | **Fix the Dockerfile according to the findings** |
| :---: | :--- |
| What to do | • Fix `/home/ubuntu/cks-111/Dockerfile`: pin the base image with the immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>`.<br/>• Do not use `ADD` with a URL, do not store a token in `ENV`, do not install `sudo`.<br/>• Add an unprivileged `USER` (uid not `0`). Use `COPY` and a reproducible installation of packages only when necessary.<br/>• Add `ARG CKS_SIGNATURE_TEST=signed` and `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` next to the other instructions - this is the only point of a controlled image difference that will be needed in task 9c to guarantee a different digest without changing the security properties checked here.<br/>• After the fix save the successful Hadolint output in `3/hadolint-after.txt`. |
| Acceptance criteria | • **The Dockerfile:** no `latest`, the remote `ADD` is removed, no `API_TOKEN`/`TOKEN` remains, there is a non-root `USER`, there is `ARG CKS_SIGNATURE_TEST` and `LABEL cks.signature-test`.<br/>• **Hadolint:** the final report does not contain `DL3007`, `DL3013`, `DL3020`, `DL3045`. |

<details>
<summary>💡 Hint for task 3</summary>

The `ARG`/`LABEL` for `CKS_SIGNATURE_TEST` may seem unrelated to the current Hadolint findings - it is added here on purpose in advance, so that task 9c (much later) can build a physically different image via `--build-arg`, without rewriting the Dockerfile again. Add these two lines now, even if their usefulness becomes clear only in 9c.
</details>

---
| **4** | **Fix the workload YAML according to kubesec and kube-linter** |
| :---: | :--- |
| What to do | • First build and publish the hardened image from task 3, then specify in `deployment.yaml` its immutable manifest reference `registry/.../catalog@sha256:<manifest-digest>` (not the upstream nginx).<br/>• At the Pod level add `automountServiceAccountToken: false`, `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`.<br/>• In the container set `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, CPU and memory requests/limits.<br/>• For nginx mount a writable `emptyDir`/tmpfs at the temp, pid/run, cache, and config paths and prepare the config before startup.<br/>• Remove `privileged`, apply the Deployment, confirm Ready/Available and a successful HTTP request.<br/>• Save the new reports `4/kubesec-after.json` and `4/kube-linter-after.json`. |
| Acceptance criteria | • **The image:** the YAML uses a digest-pinned hardened image with `USER 101`, and not the upstream nginx.<br/>• **The manifest:** the required fields, the init container `prepare-nginx-config`, and writable mounts are present; `privileged` is absent.<br/>• **Operability:** the Deployment is Available and the HTTP request succeeds.<br/>• **Reports:** both final reports are valid JSON. |

<details>
<summary>💡 Hint for task 4</summary>

`readOnlyRootFilesystem: true` requires writable paths for EVERY directory into which nginx normally writes: `/tmp`, `/var/run` (the PID file), `/var/cache/nginx` (the cache), and `/etc/nginx/conf.d` (if the config is generated at startup). If you miss even one, the container will start but crash at the first attempt of nginx to write something there. The init container `prepare-nginx-config` is needed to copy the default config into a separate writable volume BEFORE the main container starts - this is exactly why it is mentioned separately in the acceptance criteria.
</details>

---
| **5** | **Searching for package versions** |
| :---: | :--- |
| What to do | • Use Trivy in the mode of listing all packages for `$IMAGE`.<br/>• Save the command, the immutable image reference, the canonical `nginx@sha256:<manifest-digest>` from `Metadata.RepoDigests[0]`, and at least three lines `name=version` in `/var/work/tests/artifacts/5/version-search.txt`.<br/>• Do not replace the search with a manual list: the evidence must contain a command line with `trivy image --list-all-pkgs`. |
| Acceptance criteria | • **The artifact:** contains the command, the immutable `nginx:1.27.3-alpine@sha256:...`, `repo_digest=nginx@sha256:...` from Trivy, and at least three package/version pairs.<br/>• **A fresh check:** the checker itself repeats `trivy image --list-all-pkgs` for the same image and requires that `repo_digest=` and at least three saved `name=version` pairs match this fresh scan.<br/>• A hand-written but syntactically plausible list does not pass. |

<details>
<summary>💡 Hint for task 5</summary>

The flag is called exactly `--list-all-pkgs`, and not `--list-packages` or a similar variant - check the exact name of the flag in `trivy image --help` if the command does not work. Save the REAL output of the command to a file (for example via `tee`), do not rewrite a few package=version lines by hand "from memory" - the test looks for the line with the command itself as proof that the data came from the tool.
</details>

---
| **5b** | **Find a package version in workload images and remove the offending containers** |
| :---: | :--- |
| What to do | • In the namespace `cks-111` a Deployment `pkg-audit-app` is already deployed with three containers (`c1`, `c2`, `c3`), each on its own immutable digest-pinned image.<br/>• In exactly two of the three images the same package of a specific version is present - the `TARGET_PACKAGE`/`TARGET_VERSION` set for your instance of the lab are determined dynamically during provisioning, there are no hard-coded values.<br/>• Get all three image references from the live Deployment, and for each run `bom generate` (save each SBOM separately in `/var/work/tests/artifacts/5b/bom/`).<br/>• Determine which two containers really contain the same package/version and write the found pair in `5b/answer.txt` as `TARGET_PACKAGE=<name>` and `TARGET_VERSION=<version>`.<br/>• Remove EXACTLY these two offending containers from the Deployment (via `kubectl edit`/`kubectl apply` of a corrected manifest) so that only the "clean" container remains and the Deployment stays `Available`. |
| Acceptance criteria | • **The answer:** `answer.txt` names a real package/version present in exactly two of the three original images (not guessed). These two images have many packages in common: any one `name=version` pair that is not in the third image fits.<br/>• **SBOM:** `5b/bom/` has at least one genuine `bom generate` output confirming this finding.<br/>• **An independent check:** the checker independently runs `bom generate` for the original candidate images (saved during provisioning) and compares your answer with this independent run.<br/>• **The Deployment:** the final Deployment contains only the "clean" container and stays `Available`. |

<details>
<summary>💡 Hint for task 5b</summary>

The command is `bom generate --format json --output <file> --image <ref>` for EACH of the three image references separately. Compare the SBOMs pairwise: a package is considered "offending" if the same `name`/`versionInfo` pair occurs in the SBOMs of two containers but is absent (or has a different version) in the third. Do not try to guess by the name/tag of the image - some pairs of images may look "similar", but the actual match of a package is determined only by comparing the real SBOMs. When editing the Deployment, remove the container entirely from `spec.template.spec.containers`, and do not just change its image.
</details>

---
| **6** | **SPDX SBOM via bom** |
| :---: | :--- |
| What to do | • Generate an SPDX JSON SBOM with the tool `bom` for exactly the immutable `$IMAGE` (the same `tag@digest` that was used in task 1, and not the bare tag `nginx:1.27.3-alpine`); save it in `/var/work/tests/artifacts/6/bom.spdx.json`.<br/>• In the file `6/bom-command.txt` write the executed command with the exact `--image $IMAGE`. |
| Acceptance criteria | • **SBOM:** a valid JSON, has `spdxVersion`, contains the array `packages`; one of the top-level packages referenced by `documentDescribes` identifies THE SAME manifest digest as `$IMAGE` from task 1 (via `versionInfo`/`name`).<br/>• **The command:** `bom-command.txt` contains the exact immutable `$IMAGE` and uses `bom generate`.<br/>• An SBOM for another image (not related to `$IMAGE` from task 1) does not pass, even if `bom-command.txt` is forged.<br/>• **A fresh check:** the checker additionally regenerates the SBOM itself with the same `bom` for the same image and requires that the set of packages (`name`/`versionInfo`) in your SBOM match this fresh run - a minimal hand-written SPDX document with one top-level package does not pass. |

<details>
<summary>💡 Hint for task 6</summary>

The command is `bom generate -o <output.json> -i <image>` - always include the `-o` flag to specify the output file, otherwise the output goes to stdout. The output format of `bom` is its OWN SPDX JSON, which differs in details from the SPDX that Syft can generate - do not confuse these two different tools when generating the same standard format.
</details>

---
| **7** | **CycloneDX SBOM via Syft and a Cosign verification** |
| :---: | :--- |
| What to do | • Generate a CycloneDX JSON SBOM with Syft for the same immutable `$IMAGE` (`nginx:1.27.3-alpine@sha256:<manifest-digest>`) from task 1 and save it in `7/syft.cdx.json`.<br/>• Then verify the signature of the public image `gcr.io/distroless/static-debian13:nonroot` via keyless Cosign and save the full successful output in `7/cosign-verify.txt`.<br/>• For Distroless use the issuer `https://accounts.google.com` and the identity `keyless@distroless.iam.gserviceaccount.com`. |
| Acceptance criteria | • **The Syft SBOM:** `bomFormat: CycloneDX`, a non-empty `components`, `metadata.component.type == "container"` and `metadata.component.version` equal to the manifest digest of the same `$IMAGE` from task 1 - an SBOM for another image (a bare tag, alpine, busybox, etc.) does not pass.<br/>• **Cosign:** a real `cosign verify` command for `gcr.io/distroless/static-debian13:nonroot` (this is the currently supported tag; `gcr.io/distroless/static:nonroot` without the `-debian13` suffix is considered deprecated according to the official Distroless README and is no longer updated) with the specified issuer/identity ends with exit code `0`, and the full output is saved in `7/cosign-verify.txt`.<br/>• **A fresh check:** the checker additionally regenerates the SBOM itself with the same Syft for the same image and requires that the set of components (`name`/`version`) in your SBOM match this fresh run - a minimal hand-written CycloneDX document with one top-level component does not pass. |

<details>
<summary>💡 Hint for task 7</summary>

Syft generates CycloneDX through the flag `-o cyclonedx-json` (not to be confused with the SPDX output of the same tool). For keyless verification of Distroless NEITHER a key NOR `cosign generate-key-pair` is needed - use `cosign verify --certificate-identity <identity> --certificate-oidc-issuer <issuer>` with the EXACT issuer/identity strings given in the task - a typo in either of them will give a verification error.
</details>

---
| **8** | **`trivy sbom`: scanning a ready SBOM file for vulnerabilities** |
| :---: | :--- |
| What to do | • The CycloneDX SBOM from task 7 (`7/syft.cdx.json`) describes the composition of the image and its OS, but by itself contains no vulnerability findings.<br/>• Scan exactly this SBOM file (not the image directly) with the tool `trivy sbom` and save the structured JSON in `/var/work/tests/artifacts/8/sbom-scan.json`.<br/>• The command must explicitly take the SBOM file as input, and not rescan `$IMAGE`; save its text in `/var/work/tests/artifacts/8/sbom-scan-command.txt`. |
| Acceptance criteria | • **The file:** non-empty, the JSON is parsed by `jq`, `ArtifactType` = `cyclonedx`, `Results` is non-empty and contains the found vulnerabilities.<br/>• **The command:** `sbom-scan-command.txt` contains the command `trivy sbom` with the path to `7/syft.cdx.json`.<br/>• **A fresh check:** the checker itself repeats `trivy sbom` on this file. |

<details>
<summary>💡 Hint for task 8</summary>

The command is `trivy sbom <path-to-the-sbom-file>`, and NOT `trivy image <path-to-the-file>` - these are different subcommands with different input logic. If you accidentally pass the path of an SBOM file to `trivy image`, Trivy will try to interpret it as an image reference name and fail with an error or behave unexpectedly.
</details>

---
| **9a** | **Kyverno: install and create an `ImageValidatingPolicy` on a trusted signature** |
| :---: | :--- |
| What to do | • Install Kyverno via `install-kyverno` and wait for the `admission controller` to be ready.<br/>• Generate a local key pair with `cosign generate-key-pair` (a lab key pair, not a production key).<br/>• Sign **your own** hardened image from task 4 (`$HARDENED_IMAGE`, not the upstream nginx) with your private key and save the output of `cosign sign` in `9a/cosign-sign.txt`.<br/>• Create an `ImageValidatingPolicy` `require-signed-catalog-images` that checks `verifyImageSignatures` with your public key for all Pods with an image in the repository of your `$HARDENED_IMAGE`, including `pods/ephemeralcontainers` UPDATE and all container lists, and **rejects** (`validationActions: [Deny]`) unsigned/invalidly signed images. |
| Acceptance criteria | • **Kyverno:** installed, its admission controller is `Available`.<br/>• **The signature:** `9a/cosign-sign.txt` contains the successful output of signing exactly `$HARDENED_IMAGE`; the real command `cosign verify --key cosign.pub "$HARDENED_IMAGE"` completes successfully.<br/>• **The policy:** the applied `ImageValidatingPolicy require-signed-catalog-images` exists, has `apiVersion: policies.kyverno.io/v1`, `validationActions: [Deny]`, the public key, and `verifyImageSignatures`.<br/>• **The scope:** its `matchImageReferences` are restricted exactly to `$HARDENED_REPO:*` and `$HARDENED_REPO@*`, and not to the insecure prefix `$HARDENED_REPO*`. |

<details>
<summary>💡 Hint for task 9a</summary>

`cosign generate-key-pair` creates `cosign.key`/`cosign.pub` in the current directory - a lab key pair, not bound to any OIDC issuer, unlike the keyless verification from task 7. Keep the private key outside `/home/ubuntu/cks-111`, because this directory is reused as the Docker build context in task 9c - a `cosign.key` left inside it will get straight into the filesystem of the published image through `COPY . /usr/share/nginx/html`. The `matchImageReferences` in the policy must restrict its action EXACTLY to your repository (`$HARDENED_REPO`), and not to the whole cluster - otherwise the policy will block ALL Pods without a signature, including the system components of Kubernetes.
</details>

---
| **9b** | **Fresh signed ALLOW: a new Pod after the policy is created** |
| :---: | :--- |
| What to do | • The policy from task 9a must admit the signed `$HARDENED_IMAGE` - but a repeated `kubectl apply` of an already existing Deployment **does not prove** this: if the template has not changed, a new ReplicaSet/Pod may not be created, and `Running` turns out to be just the old Pod created before the policy.<br/>• Create a **new**, previously non-existent object: `kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" --restart=Never --command -- sleep 3600`.<br/>• Save the `creationTimestamp` of this Pod, the `creationTimestamp` of the policy from 9a, and the final `status.phase`/`Ready` condition in `9b/signed-admission-check.json`. |
| Acceptance criteria | • **The Pod:** `signed-admission-check` exists, uses exactly `$HARDENED_IMAGE`; `cosign verify --key cosign.pub "$HARDENED_IMAGE"` completes successfully for it, `status.phase` is not `Failed`, and the `Ready` condition reaches `True`.<br/>• **The artifact:** `9b/signed-admission-check.json` contains this image and a Pod `creationTimestamp` that is **not earlier** than the `creationTimestamp` of the `ImageValidatingPolicy require-signed-catalog-images`.<br/>• This proves a fresh post-policy admission of a verifiably signed image, and not an old Pod that survived the policy. |

<details>
<summary>💡 Hint for task 9b</summary>

Do not reuse the Deployment `catalog` from task 4 for this check - use a literally new `kubectl run` with a new Pod name, as stated in the task. Both timestamps (of the Pod and of the policy) are ISO8601 strings in UTC; they can be compared lexicographically as regular strings (`[[ "2026-09-06T10:05:00Z" > "2026-09-06T10:00:00Z" ]]` works correctly in bash for this format).
</details>

---
| **9c** | **Signature-specific DENY: an unsigned digest that really exists in the same repository** |
| :---: | :--- |
| What to do | • Build and publish a **second** tag in the same repository as `$HARDENED_IMAGE` (for example, `${HARDENED_TAG%:*}:unsigned-1.0`), without signing it.<br/>• This image must be a **physically different artifact**, and not the same digest as the already signed `$HARDENED_IMAGE`: if you build the same `Dockerfile`/context unchanged, a reproducible/cached build may give an identical digest, and then the "unsigned" tag will in fact point to the already signed artifact, and `cosign verify` will unexpectedly pass.<br/>• Introduce a controlled difference via a build-arg (for example `--build-arg CKS_SIGNATURE_TEST=unsigned-1` with the corresponding `ARG`/`LABEL` in the Dockerfile) and explicitly save the proof `$UNSIGNED_DIGEST != $HARDENED_DIGEST` in `9c/digest-comparison.txt`.<br/>• Obtain the registry manifest digest in the same way as in task 3 (`podman push --digestfile`), form `$UNSIGNED_IMAGE` in the same repository.<br/>• Explicitly prove that this digest **exists and is pullable** (a `HEAD` or `GET` request to `/v2/catalog/manifests/<digest>` on the registry succeeds) and **does not have** a valid signature by your key (`cosign verify --key cosign.pub "$UNSIGNED_IMAGE"` ends with an error) - save both outputs in `9c/unsigned-exists.txt` and `9c/unsigned-not-signed.txt`.<br/>• Then create a Pod `catalog-unsigned-probe` with this `$UNSIGNED_IMAGE` and save the admission denial in `9c/admission-deny.txt`. |
| Acceptance criteria | • **The artifact:** `9c/digest-comparison.txt` contains `hardened_digest=`, `unsigned_digest=`, and `unsigned_image=` (a full `tag@digest` reference in the same repository as `$HARDENED_IMAGE`, with a genuinely different digest).<br/>• **The checker's check:** it itself resolves `unsigned_image` in the registry, confirms the absence of a valid signature via its own `cosign verify`, creates ITS OWN new Pod with this image, and requires the unique validation message of its own policy: `catalog image must have a valid release signature`.<br/>• Only this message counts, not just any admission error: a generic admission/signature error from another policy does not give PASS, and `manifest unknown`/registry lookup errors are also insufficient.<br/>• Hand-written evidence files without real admission control do not give PASS - the checker trusts no text files, except `unsigned_image=` as a pointer to the real image for checking. |

<details>
<summary>💡 Hint for task 9c</summary>

The order of the proofs here matters for their credibility: first prove that `$UNSIGNED_IMAGE` EXISTS and is PULLABLE (otherwise the subsequent denial may be just "manifest unknown" and not about the signature), then prove the ABSENCE of a signature, and only AFTER that try to create the Pod. If the digest comparison in `digest-comparison.txt` shows a match - achieve a real difference of content (for example, change the `CKS_SIGNATURE_TEST` build-arg to a different value and rebuild).
</details>

## Verification

```bash
check_result
```

The check contains `Init` and fourteen independent graded tests (task 9 is split into 9a/9b/9c). It checks the content of files and
JSON, and not only the presence of names. External registry requests are required for Trivy, SBOM, and
Cosign; if the registry is temporarily unavailable, repeat exactly the corresponding command.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD).

## Deletion

```bash
TASK=111 make delete_cks_task
```
