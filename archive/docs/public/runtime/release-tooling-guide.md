# Release Tooling Guide

What this is. This page is the operator playbook for CI, release, promotion, signing, and rollback workflows.

## Workflow Map

- CI gate: `.github/workflows/ci.yml`
- Pre-release verification: `.github/workflows/pre_release_verify.yml`
- Release build and publish: `.github/workflows/release_artifacts.yml`
- Preview to stable promotion: `.github/workflows/promote_release.yml`
- Rollback and yanking: `.github/workflows/rollback_release.yml`
- Manual Windows fallback staging: `.github/workflows/cd_release.yml`

## Daily And Release Commands

```powershell
nimble compliance
nimble verify
```

```powershell
# Tag-based release trigger
# Example
# git tag v0.9.10
# git push origin v0.9.10
```

## Release Runbook

1. Verify main branch is green in CI and pre-release verification.
2. Create and push a release tag in semver format:
   - `vMAJOR.MINOR.PATCH`
   - preview tags allowed with suffix, for example `v0.9.10-preview.1`
3. Wait for `.github/workflows/release_artifacts.yml` to finish.
4. Confirm GitHub Release contains:
   - target artifacts for each matrix target,
   - `SHA256SUMS`,
   - `RELEASE-SUMMARY.md`.
5. If signing is configured, confirm `SHA256SUMS.sig` and `SHA256SUMS.sig.b64` are present.

## Optional Signing Setup

Signing is optional and auto-activates when secrets are configured.

Required repository secrets:
- `RELEASE_SIGNING_PRIVATE_KEY`
  - PEM private key (raw PEM text) or base64-encoded PEM text.
- `RELEASE_SIGNING_KEY_PASSPHRASE`
  - optional passphrase for encrypted private keys.

When secrets are not present, release workflow still succeeds and records unsigned status in release summary.

## Promotion Runbook

Use `.github/workflows/promote_release.yml` to promote preview release assets to a stable tag.

Inputs:
- `source_tag`: preview or source tag, for example `v0.9.10-preview.1`
- `target_tag`: stable tag, for example `v0.9.10`
- `make_latest`: whether promoted release becomes latest

Promotion behavior:
- validates source and target tags,
- downloads source release assets,
- creates or updates target release,
- uploads assets with clobber enabled,
- writes promotion notes.

## Rollback Runbook

Use `.github/workflows/rollback_release.yml` to yank a release quickly.

Inputs:
- `tag`: tag to yank
- `delete_tag`: whether to remove git tag after yanking
- `reason`: rollback reason shown in yanked release notes

Rollback behavior:
- validates release tag,
- marks release title with `YANKED:` prefix,
- sets release to prerelease and non-latest,
- uploads `YANKED-NOTICE.md` asset,
- optionally deletes tag reference.

## Branch And Environment Protection

Recommended repository settings:
- protect `main` with required status checks:
  - CI core test suite
  - Pre-release verify workflow
- require pull request review before merge to `main`.
- disallow direct pushes to `main`.
- use GitHub environment protection for release operations:
  - create environment `release`,
  - require manual approval for publish jobs,
  - restrict secret access to release environment only.

## Audit Checklist

For each release, confirm:
- release tag and release title match expected version,
- release summary includes commit hash and target count,
- checksums are present,
- signature artifacts are present when signing is enabled,
- promotion and rollback workflows are executable by release operators.

## Troubleshooting

- Missing artifacts in release:
  - check matrix job failure logs in `.github/workflows/release_artifacts.yml`.
- Promotion failed with missing source assets:
  - verify source release exists and has downloadable assets.
- Rollback cannot delete tag:
  - confirm workflow token has `contents: write` and branch/tag protections allow deletion.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
