# Wilder Cosmos 0.4.0
# Module name: encrypted_record
# Module Path: src/runtime/encrypted_record.nim
#
# encrypted_record.nim
# Deterministic encrypted RECORD entry helpers.
# Summary: Encrypt/decrypt RECORD payloads deterministically and reconcile chains by metadata only.
# Simile: Like sealed ledger cards, content stays closed while chain integrity stays inspectable.
# Memory note: reconciliation must never require payload decrypt.
# Flow: derive deterministic keystream -> xor payload bytes -> emit metadata-hashed entry.

import json
import std/strutils
import validation
import config
import encryption_mode

type
  EncryptedRecordEntry* = object
    entryType*: string
    authorId*: string
    sequence*: int
    previousHash*: string
    encryptedPayload*: string
    encryptedPayloadHash*: string
    payloadAuthTag*: string  ## HMAC-SHA256(keyMaterial, ciphertext || associated_data)

# Flow: Convert string into byte sequence.
proc toBytes(raw: string): seq[byte] =
  result = newSeq[byte](raw.len)
  for i in 0 ..< raw.len:
    result[i] = byte(raw[i])

# Flow: Convert byte sequence into string.
proc fromBytes(raw: openArray[byte]): string =
  result = newString(raw.len)
  for i in 0 ..< raw.len:
    result[i] = char(raw[i])

# Flow: Encode bytes as lowercase hex string.
proc bytesToHex(raw: openArray[byte]): string =
  const hexChars = "0123456789abcdef"
  result = newString(raw.len * 2)
  for i in 0 ..< raw.len:
    let b = int(raw[i])
    result[i * 2] = hexChars[(b shr 4) and 0xF]
    result[i * 2 + 1] = hexChars[b and 0xF]

# Flow: Decode lowercase/uppercase hex string to bytes.
proc hexToBytes(raw: string): seq[byte] =
  if raw.len mod 2 != 0:
    raise newException(ValueError,
      "encrypted_record: hex input length must be even")
  result = newSeq[byte](raw.len div 2)
  var i = 0
  while i < raw.len:
    let pair = raw[i .. i + 1]
    try:
      result[i div 2] = byte(parseHexInt(pair))
    except ValueError:
      raise newException(ValueError,
        "encrypted_record: invalid hex input")
    i = i + 2

# Flow: Encode a string with a length prefix to prevent delimiter-injection in hash preimages.
proc lenPrefixed(s: string): string =
  $s.len & ":" & s

# Flow: Compute HMAC-SHA256 over a message with the given key (RFC 2104).
proc hmacSha256(key: seq[byte], message: seq[byte]): string =
  ## Authenticated MAC binding key, message, and associated context.
  ## Simile: A wax seal that is unique to both the sender and the letter.
  const blockSize = 64
  # Normalize key: hash if longer than the SHA256 block size.
  var keyBlock = newSeq[byte](blockSize)
  if key.len > blockSize:
    let hashed = hexToBytes(computeSha256(key))
    for i in 0 ..< hashed.len:
      keyBlock[i] = hashed[i]
  else:
    for i in 0 ..< key.len:
      keyBlock[i] = key[i]
  # Build inner/outer XOR pads.
  var innerKey = newSeq[byte](blockSize)
  var outerKey = newSeq[byte](blockSize)
  for i in 0 ..< blockSize:
    innerKey[i] = keyBlock[i] xor 0x36'u8
    outerKey[i] = keyBlock[i] xor 0x5c'u8
  # Inner hash: SHA256(innerKey || message)
  let innerMsg = innerKey & message
  let innerHash = hexToBytes(computeSha256(innerMsg))
  # Outer hash: SHA256(outerKey || innerHash)
  let outerMsg = outerKey & innerHash
  computeSha256(outerMsg)

# Flow: Derive deterministic nonce from key material and entry identity tuple.
proc deriveNonce(keyMaterial: string,
                 sequence: int,
                 entryType: string,
                 authorId: string,
                 previousHash: string): string =
  # Length-prefix all variable-length fields to prevent delimiter-injection
  # collisions where different field combinations yield the same preimage.
  computeSha256(toBytes(
    lenPrefixed(keyMaterial) & "|" & $sequence & "|" &
    lenPrefixed(entryType) & "|" & lenPrefixed(authorId) & "|" &
    lenPrefixed(previousHash)
  ))

# Flow: Compute HMAC-SHA256 over ciphertext and associated entry metadata.
proc computePayloadAuthTag(keyMaterial: string,
                           ciphertextHex: string,
                           sequence: int,
                           entryType: string,
                           authorId: string,
                           previousHash: string): string =
  ## Bind the ciphertext to its metadata so that bit-flipping attacks on the
  ## ciphertext, or swapping metadata between entries, both fail verification.
  let assocData = toBytes(
    $sequence & "|" & lenPrefixed(entryType) & "|" &
    lenPrefixed(authorId) & "|" & lenPrefixed(previousHash)
  )
  let message = toBytes(ciphertextHex) & assocData
  hmacSha256(toBytes(keyMaterial), message)

# Flow: Build deterministic keystream with SHA256 counter expansion.
proc deterministicKeystream(keyMaterial: string,
                            nonce: string,
                            size: int): seq[byte] =
  if size < 0:
    raise newException(ValueError,
      "encrypted_record: size must be non-negative")
  var counter = 0
  while result.len < size:
    let digestBlock = computeSha256(toBytes(keyMaterial & "|" & nonce & "|" & $counter))
    result.add(toBytes(digestBlock))
    counter = counter + 1
  result.setLen(size)

# Flow: XOR payload bytes with deterministic keystream and return hex ciphertext.
proc encryptDeterministicPayload*(payload: JsonNode,
                                  keyMaterial: string,
                                  sequence: int,
                                  entryType: string,
                                  authorId: string,
                                  previousHash: string): string =
  if keyMaterial.strip.len == 0:
    raise newException(ValueError,
      "encrypted_record: key material must not be empty")
  let plaintext = toBytes($payload)
  let nonce = deriveNonce(keyMaterial, sequence, entryType, authorId, previousHash)
  let stream = deterministicKeystream(keyMaterial, nonce, plaintext.len)
  var outBytes = newSeq[byte](plaintext.len)
  for i in 0 ..< plaintext.len:
    outBytes[i] = plaintext[i] xor stream[i]
  bytesToHex(outBytes)

# Flow: Decrypt deterministic payload by applying the same XOR keystream.
proc decryptDeterministicPayload*(encryptedPayload: string,
                                  keyMaterial: string,
                                  sequence: int,
                                  entryType: string,
                                  authorId: string,
                                  previousHash: string): JsonNode =
  let cipher = hexToBytes(encryptedPayload)
  let nonce = deriveNonce(keyMaterial, sequence, entryType, authorId, previousHash)
  let stream = deterministicKeystream(keyMaterial, nonce, cipher.len)
  var plain = newSeq[byte](cipher.len)
  for i in 0 ..< cipher.len:
    plain[i] = cipher[i] xor stream[i]
  try:
    result = parseJson(fromBytes(plain))
  except JsonParsingError:
    raise newException(ValueError,
      "encrypted_record: decrypted payload is not valid JSON")

# Flow: Verify HMAC auth tag then decrypt — the safe public decryption API.
proc verifyAndDecryptRecordEntry*(entry: EncryptedRecordEntry,
                                   keyMaterial: string): JsonNode =
  ## Authenticate the ciphertext before decrypting.  Raises ValueError if the
  ## auth tag is absent or does not match — indicating tampering or corruption.
  ## Simile: Breaking the wax seal before reading the letter — if it is broken,
  ##   the letter has been opened.
  if keyMaterial.strip.len == 0:
    raise newException(ValueError,
      "encrypted_record: key material is required for verification")
  if entry.payloadAuthTag.len == 0:
    raise newException(ValueError,
      "encrypted_record: auth tag is absent; entry may be tampered with " &
      "or was built before authentication was introduced")
  let expectedTag = computePayloadAuthTag(
    keyMaterial,
    entry.encryptedPayload,
    entry.sequence,
    entry.entryType,
    entry.authorId,
    entry.previousHash
  )
  if expectedTag != entry.payloadAuthTag:
    raise newException(ValueError,
      "encrypted_record: auth tag mismatch — ciphertext or metadata has been tampered with")
  decryptDeterministicPayload(
    entry.encryptedPayload,
    keyMaterial,
    entry.sequence,
    entry.entryType,
    entry.authorId,
    entry.previousHash
  )

# Flow: Build deterministic encrypted RECORD entry with structural metadata.
proc buildEncryptedRecordEntry*(payload: JsonNode,
                                keyMaterial: string,
                                sequence: int,
                                entryType: string,
                                authorId: string,
                                previousHash: string): EncryptedRecordEntry =
  if sequence < 1:
    raise newException(ValueError,
      "encrypted_record: sequence must be >= 1")
  if entryType.strip.len == 0:
    raise newException(ValueError,
      "encrypted_record: entryType must not be empty")
  if authorId.strip.len == 0:
    raise newException(ValueError,
      "encrypted_record: authorId must not be empty")
  let encryptedPayload = encryptDeterministicPayload(
    payload,
    keyMaterial,
    sequence,
    entryType,
    authorId,
    previousHash
  )
  let authTag = computePayloadAuthTag(
    keyMaterial, encryptedPayload, sequence, entryType, authorId, previousHash
  )
  EncryptedRecordEntry(
    entryType: entryType,
    authorId: authorId,
    sequence: sequence,
    previousHash: previousHash,
    encryptedPayload: encryptedPayload,
    encryptedPayloadHash: computeSha256(toBytes(encryptedPayload)),
    payloadAuthTag: authTag
  )

# Flow: Validate chain metadata only (without payload decrypt).
proc validateRecordChainMetadata*(entries: seq[EncryptedRecordEntry]): bool =
  if entries.len == 0:
    return true
  if entries[0].sequence != 1:
    return false

  for i, entry in entries:
    if computeSha256(toBytes(entry.encryptedPayload)) != entry.encryptedPayloadHash:
      return false
    if i > 0:
      let prev = entries[i - 1]
      if entry.sequence != prev.sequence + 1:
        return false
      if entry.previousHash != prev.encryptedPayloadHash:
        return false
  true

# Flow: Compare triumvirate copies by structural metadata tuple only.
proc compareTriumvirateMetadata*(copyA: seq[EncryptedRecordEntry],
                                 copyB: seq[EncryptedRecordEntry],
                                 copyC: seq[EncryptedRecordEntry]): bool =
  if copyA.len != copyB.len or copyB.len != copyC.len:
    return false

  for i in 0 ..< copyA.len:
    let tupleA = (copyA[i].sequence, copyA[i].entryType,
      copyA[i].encryptedPayloadHash, copyA[i].previousHash)
    let tupleB = (copyB[i].sequence, copyB[i].entryType,
      copyB[i].encryptedPayloadHash, copyB[i].previousHash)
    let tupleC = (copyC[i].sequence, copyC[i].entryType,
      copyC[i].encryptedPayloadHash, copyC[i].previousHash)
    if tupleA != tupleB or tupleB != tupleC:
      return false
  true

# Flow: Convert encrypted record entry to deterministic JSON object.
proc encryptedRecordToJson*(entry: EncryptedRecordEntry): JsonNode =
  %*{
    "entryType": entry.entryType,
    "authorId": entry.authorId,
    "sequence": entry.sequence,
    "previousHash": entry.previousHash,
    "encryptedPayload": entry.encryptedPayload,
    "encryptedPayloadHash": entry.encryptedPayloadHash,
    "payloadAuthTag": entry.payloadAuthTag
  }

# Flow: Convert deterministic JSON object back into typed encrypted record entry.
proc encryptedRecordFromJson*(node: JsonNode): EncryptedRecordEntry =
  discard validateStructure(node, @[
    "entryType", "authorId", "sequence", "previousHash",
    "encryptedPayload", "encryptedPayloadHash"
  ])
  if node["entryType"].kind != JString or
     node["authorId"].kind != JString or
     node["sequence"].kind != JInt or
     node["previousHash"].kind != JString or
     node["encryptedPayload"].kind != JString or
     node["encryptedPayloadHash"].kind != JString:
    raise newException(ValueError,
      "encrypted_record: record JSON has invalid field types")
  EncryptedRecordEntry(
    entryType: node["entryType"].getStr(),
    authorId: node["authorId"].getStr(),
    sequence: node["sequence"].getInt(),
    previousHash: node["previousHash"].getStr(),
    encryptedPayload: node["encryptedPayload"].getStr(),
    encryptedPayloadHash: node["encryptedPayloadHash"].getStr(),
    payloadAuthTag: if node.hasKey("payloadAuthTag") and
                       node["payloadAuthTag"].kind == JString:
                     node["payloadAuthTag"].getStr()
                   else: ""  # absent in records predating authentication
  )

# Flow: Build a record entry according to the selected encryption mode.
proc buildRecordEntryForMode*(payload: JsonNode,
                              encryptionMode: EncryptionMode,
                              keyMaterial: string,
                              sequence: int,
                              entryType: string,
                              authorId: string,
                              previousHash: string): EncryptedRecordEntry =
  let policy = policyFor(encryptionMode)
  if policy.storesPlaintext:
    let plaintext = $payload
    return EncryptedRecordEntry(
      entryType: entryType,
      authorId: authorId,
      sequence: sequence,
      previousHash: previousHash,
      encryptedPayload: plaintext,
      encryptedPayloadHash: computeSha256(toBytes(plaintext))
    )
  if policy.requiresKeyMaterial and keyMaterial.strip.len == 0:
    raise newException(ValueError,
      "encrypted_record: key material is required for this encryption mode")
  result = buildEncryptedRecordEntry(
    payload,
    keyMaterial,
    sequence,
    entryType,
    authorId,
    previousHash
  )

# Flow: Restore the original payload according to the selected encryption mode.
proc restoreRecordPayloadForMode*(entry: EncryptedRecordEntry,
                                  encryptionMode: EncryptionMode,
                                  keyMaterial: string): JsonNode =
  if policyFor(encryptionMode).storesPlaintext:
    try:
      return parseJson(entry.encryptedPayload)
    except JsonParsingError:
      raise newException(ValueError,
        "encrypted_record: clear-mode payload is not valid JSON")
  result = verifyAndDecryptRecordEntry(entry, keyMaterial)

# Flow: Build one operator-facing summary that respects the selected encryption mode.
proc summarizeRecordEntryForMode*(entry: EncryptedRecordEntry,
                                  encryptionMode: EncryptionMode): JsonNode =
  result = %*{
    "entryType": entry.entryType,
    "sequence": entry.sequence,
    "previousHash": entry.previousHash,
    "encryptedPayloadHash": entry.encryptedPayloadHash,
    "contentVisible": false
  }

  case encryptionMode
  of emClear:
    result["authorId"] = %entry.authorId
    result["contentVisible"] = %true
    try:
      result["payload"] = parseJson(entry.encryptedPayload)
    except JsonParsingError:
      result["payload"] = %entry.encryptedPayload
  of emStandard:
    result["authorId"] = %entry.authorId
  of emPrivate:
    discard
  of emComplete:
    discard

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
