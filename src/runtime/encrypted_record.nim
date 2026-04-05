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

type
  EncryptedRecordEntry* = object
    entryType*: string
    authorId*: string
    sequence*: int
    previousHash*: string
    encryptedPayload*: string
    encryptedPayloadHash*: string

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

# Flow: Derive deterministic nonce from key material and entry identity tuple.
proc deriveNonce(keyMaterial: string,
                 sequence: int,
                 entryType: string,
                 authorId: string,
                 previousHash: string): string =
  computeSha256(toBytes(
    keyMaterial & "|" & $sequence & "|" & entryType & "|" & authorId & "|" & previousHash
  ))

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
  EncryptedRecordEntry(
    entryType: entryType,
    authorId: authorId,
    sequence: sequence,
    previousHash: previousHash,
    encryptedPayload: encryptedPayload,
    encryptedPayloadHash: computeSha256(toBytes(encryptedPayload))
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
    "encryptedPayloadHash": entry.encryptedPayloadHash
  }

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
