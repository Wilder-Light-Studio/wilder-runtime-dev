# Encryption Modes Notes

This note expands the proposed encryption mode vocabulary and captures the intended trust boundaries.

It predates the normative Phase XF work and is now superseded by the canonical
four-mode Cosmos encryption spectrum in `docs/implementation/REQUIREMENTS.md` and
`docs/implementation/SPECIFICATION-NIM.md`.

These notes are exploratory and do not define current runtime behavior.

## Summary

The proposed mode names form a progressive privacy spectrum:

- `open`
- `standard`
- `private`
- `closed`
- `local`

The value of this model is clarity. The names are short, memorable, and communicate increasing operator blindness and user custody.

## Proposed Semantics

### `open`

Operator-visible, cloud-standard.

- Data encrypted in transit and at rest using server-side encryption.
- Operator can read plaintext for debugging, support, or shared features.
- Full account recovery available.
- Suitable for low-risk or collaborative contexts.

Use when convenience and recoverability matter more than strict privacy.

### `standard`

Operator-blind to content, metadata visible.

- Client-side encryption for user content.
- Server sees ciphertext and minimal metadata such as timestamps and sizes.
- Operator cannot read content but can assist with account recovery.
- Optional key escrow with explicit user consent.

Use when users want strong privacy without accepting total data loss risk.

### `private`

Strong client-side encryption, limited recovery.

- All content encrypted client-side with keys controlled by the user.
- Operator cannot read content.
- Metadata minimized.
- Recovery possible only if the user opted into a backup mechanism such as a recovery phrase or hardware token.

Use when users want near-E2EE privacy with a deliberate safety net.

### `closed`

Full E2EE, sealed mode.

- True end-to-end encryption.
- Keys never leave user devices in plaintext.
- No operator recovery, no backdoors, no exceptions.
- All RECORD data, prompts, outputs, and eidela state encrypted before leaving the device.
- Lost keys make data permanently unrecoverable.

Use when users want maximum privacy and accept full key responsibility.

### `local`

Air-gapped, device-only encryption.

- All data stored and encrypted locally.
- No sync, no cloud, and no server involvement.
- Optional encrypted local backups.
- Suitable for sovereign, offline, or ephemeral contexts.

Use when users want a self-contained offline cryptographic sanctuary.

## Design Reading

- `open` prioritizes convenience.
- `standard` prioritizes strong privacy with recovery.
- `private` prioritizes user custody with optional fallback.
- `closed` prioritizes absolute privacy.
- `local` prioritizes sovereignty and offline operation.

## Design Cautions

- The mode names are product policy terms, not direct cryptographic algorithm names.
- Recovery policy, sync policy, and metadata policy should be specified separately even if surfaced together in one mode selector.
- `local` may ultimately behave more like a deployment/storage mode than a pure encryption mode.
- The boundary between `private` and `closed` should remain explicit to avoid user confusion.

## Suggested Future Spec Work

- Define key ownership and storage rules per mode.
- Define exact metadata exposure per mode.
- Define permitted sync and replication behavior per mode.
- Define migration rules between modes.
- Define operator support boundaries and user-facing warnings.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*