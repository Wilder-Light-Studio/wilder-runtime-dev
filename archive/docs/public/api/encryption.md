# encryption — Encrypted RECORDs & Encryption Policy

> Sources: `src/runtime/encrypted_record.nim`, `src/runtime/encryption_mode.nim`

Deterministic encrypted RECORD entry helpers and runtime encryption-spectrum policy mapping.

---

## Encryption Mode Policy

### `EncryptionMetadataProfile`

```nim
EncryptionMetadataProfile* = enum
  empCleartext       ## Full metadata visible
  empStructural      ## Structural metadata preserved
  empMinimal         ## Minimal metadata
  empCiphertextOnly  ## No metadata exposed
```

### `EncryptionPolicy`

Explicit runtime policy derived from an `EncryptionMode`.

```nim
EncryptionPolicy* = object
  mode*: EncryptionMode
  storesPlaintext*: bool
  allowsOperatorPlaintextAccess*: bool
  permitsOperatorEscrow*: bool
  requiresKeyMaterial*: bool
  metadataProfile*: EncryptionMetadataProfile
```

### Policy Procedures

```nim
proc policyFor*(mode: EncryptionMode): EncryptionPolicy
proc usesCiphertextStorage*(mode: EncryptionMode): bool
proc requiresKeyMaterial*(mode: EncryptionMode): bool
proc privacyRank*(mode: EncryptionMode): int
proc isPrivacyDowngrade*(fromMode, toMode: EncryptionMode): bool
```

---

## Encrypted RECORD Entries

### `EncryptedRecordEntry`

```nim
EncryptedRecordEntry* = object
  entryType*: string
  authorId*: string
  sequence*: int
  previousHash*: string
  encryptedPayload*: string
  encryptedPayloadHash*: string
  payloadAuthTag*: string
```

### Encrypt / Decrypt

```nim
proc encryptDeterministicPayload*(payload: JsonNode, keyMaterial: string,
                                   sequence: int, entryType, authorId,
                                   previousHash: string): string
proc decryptDeterministicPayload*(encryptedPayload: string, keyMaterial: string,
                                   sequence: int, entryType, authorId,
                                   previousHash: string): JsonNode
```

### Build / Verify

```nim
proc buildEncryptedRecordEntry*(payload: JsonNode, keyMaterial: string,
                                  sequence: int, entryType, authorId,
                                  previousHash: string): EncryptedRecordEntry
proc verifyAndDecryptRecordEntry*(entry: EncryptedRecordEntry,
                                    keyMaterial: string): JsonNode
```
`verifyAndDecryptRecordEntry` checks the HMAC auth tag before decrypting.

### Mode-Aware Helpers

```nim
proc buildRecordEntryForMode*(payload: JsonNode, encryptionMode: EncryptionMode,
                                keyMaterial: string, sequence: int,
                                entryType, authorId, previousHash: string): EncryptedRecordEntry
proc restoreRecordPayloadForMode*(entry: EncryptedRecordEntry,
                                    encryptionMode: EncryptionMode,
                                    keyMaterial: string): JsonNode
proc summarizeRecordEntryForMode*(entry: EncryptedRecordEntry,
                                    encryptionMode: EncryptionMode): JsonNode
```

### Chain Validation

```nim
proc validateRecordChainMetadata*(entries: seq[EncryptedRecordEntry]): bool
proc compareTriumvirateMetadata*(copyA, copyB, copyC: seq[EncryptedRecordEntry]): bool
```
Validate chain integrity and compare three independent copies using metadata only (no decryption required).

### Serialization

```nim
proc encryptedRecordToJson*(entry: EncryptedRecordEntry): JsonNode
proc encryptedRecordFromJson*(node: JsonNode): EncryptedRecordEntry
```
