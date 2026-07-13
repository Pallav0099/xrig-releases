# XRIG Releases

This public repository is the distribution channel for XRIG AI PC application
releases. It intentionally contains **no Kai, Vertex, or XRIG Platform source
code** and no release binary is committed to Git history.

Every production binary, inner installer, bootstrap, manifest, and signature is
uploaded as a GitHub Release asset by the protected `Build and publish XRIG app
release` workflow. The signed `xrig-release-v1.manifest` is the release
authority; GitHub's `latest` route is only a download selector.

## What is published

- `Install-Kai.ps1` and `Install-Vertex.ps1` public bootstraps;
- Kai and Vertex Windows binaries and their verified inner installers;
- locked llama.cpp/CUDA runtime archives;
- the factory model configuration (model bytes download directly from the
  pinned public Hugging Face entries in that configuration);
- an Ed25519 signature for every release payload and the canonical manifest.

`xrig-identity.exe`, Register, Activate, and Reactivate are not published here.
They stay on XRIG Platform's private factory/support path. Product installers
only proceed after the installed Platform passes local Verify and its online
active-device check.

## Release workflow

Run `.github/workflows/publish-release.yml` manually from this repository. It
requires exact **tags**, not branches, for the three private source repositories:

- `Pallav0099/xrig-platform`
- `Pallav0099/xrig-llama-backend`
- `Pallav0099/kai`

The workflow checks out those tags with a read-only source token, compiles the
Windows artifacts, validates the signed manifest with the Platform verifier,
and creates either a GitHub pre-release or stable release. A versioned asset is
never replaced with different bytes.

## Required protected-environment configuration

Create a `production` environment for this repository and protect it with the
factory release approver. Configure only these values there:

- `XRIG_SOURCE_READ_TOKEN` — a fine-grained token limited to **Contents: Read**
  on the three private source repositories above.
- `XRIG_RELEASE_SIGNING_PKCS8_B64` — the existing XRIG Ed25519 signing key,
  Base64-encoded. It is used only while signing release assets on the protected
  runner.
- `XRIG_SUPABASE_ANON_KEY` — Platform public activation metadata.
- `XRIG_ACTIVATION_RESPONSE_PUBLIC_KEY_HEX` — Platform public activation
  response key.

The workflow's built-in `GITHUB_TOKEN` has write access only to this repository
and is used to create the GitHub Release. No Supabase storage token is used for
Kai or Vertex release publication.

## Factory pre-release command

GitHub's `latest` selector excludes pre-releases. For a factory candidate, save
the versioned bootstrap, then pass that same tag explicitly:

```powershell
$tag = 'v1.0.0-rc.1'
Invoke-WebRequest "https://github.com/Pallav0099/xrig-releases/releases/download/$tag/Install-Vertex.ps1" -OutFile .\Install-Vertex.ps1
.\Install-Vertex.ps1 -ReleaseTag $tag
```

Use the equivalent `Install-Kai.ps1` command for Kai. This is only for factory
and clean-runner pre-release validation; owner installation always uses the
stable URLs below.

## Public stable URLs

Once a pre-release is promoted to stable, the public installation endpoints are:

```powershell
irm https://github.com/Pallav0099/xrig-releases/releases/latest/download/Install-Vertex.ps1 | iex
irm https://github.com/Pallav0099/xrig-releases/releases/latest/download/Install-Kai.ps1 | iex
```

The initial bootstrap is HTTPS-trusted by design. Before elevation or product
mutation, it must call XRIG Platform, validate the active device online, and
verify the signed manifest plus each immutable artifact.
