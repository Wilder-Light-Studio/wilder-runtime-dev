# Wilder Cosmos 0.4.0
# Module name: record_reconciliation
# Module Path: src/runtime/record_reconciliation.nim
#
# Wilder Foundation License 1.0
# record_reconciliation.nim

import std/[json, sequtils, strutils]

# Flow: Provide deterministic metadata-only reconciliation for sovereign RECORD copies.

type
  ReconciliationError* = object of CatchableError

  RecordCopyStatus* = enum
    rcHealthy
    rcChainBroken
    rcHashMismatch
    rcSequenceError

  ReconciliationResult* = object
    status*: RecordCopyStatus
    description*: string
    healthyCount*: int
    brokenKeys*: seq[string]

# Flow: Validate three sovereign RECORD copies and report reconciliation status.
proc reconcileTriumvirate*(copy1, copy2, copy3: seq[JsonNode]): ReconciliationResult =
  ## Reconciliation compares metadata tuples across three copies without decrypting.
  ## Returns status: healthy (all match), chainBroken (sequence/hash mismatch),
  ## hashMismatch (payload hash divergence), or sequenceError (ordering problem).
  
  result = ReconciliationResult(
    status: rcHealthy,
    description: "",
    healthyCount: 0,
    brokenKeys: @[]
  )

  # Flow: Validate each copy independently using metadata-only checks.
  let copies = [copy1, copy2, copy3]
  var validCopyCount = 0
  var copyErrors: array[3, string]
  
  for idx, entries in copies.pairs:
    try:
      if entries.len == 0:
        continue
      
      # Flow: Validate chain metadata for this copy (sequence, previous hash continuity).
      for i in 0 ..< entries.len:
        let entry = entries[i]
        let seq = entry["sequence"].getInt()
        
        # Flow: Check sequence starts at 1 and increments strictly.
        if i == 0:
          if seq != 1:
            raise newException(ReconciliationError, "first entry sequence must be 1")
        else:
          if seq != (entries[i-1]["sequence"].getInt() + 1):
            raise newException(ReconciliationError, "sequence not strictly increasing")
        
        # Flow: Check previous hash chain continuity (no decrypt needed).
        if i > 0:
          let prevHash = entries[i-1]["encryptedPayloadHash"].getStr()
          let linkHash = entry["previousHash"].getStr()
          if prevHash != linkHash:
            raise newException(ReconciliationError, "previous hash chain broken at sequence " & $seq)
      
      validCopyCount += 1
    except CatchableError:
      copyErrors[idx] = getCurrentExceptionMsg()
      result.brokenKeys.add("copy_" & $idx)
  
  result.healthyCount = validCopyCount
  
  # Flow: If all copies valid, compare metadata tuples for consensus.
  if validCopyCount == 3 and copy1.len == copy2.len and copy2.len == copy3.len:
    # Flow: Compare triumvirate metadata tuples across entries.
    for i in 0 ..< copy1.len:
      let entry1 = copy1[i]
      let entry2 = copy2[i]
      let entry3 = copy3[i]
      
      # Flow: Extract metadata tuples (no decryption needed).
      let tuple1 = (
        sequence: entry1["sequence"].getInt(),
        entryType: entry1["entryType"].getStr(),
        payloadHash: entry1["encryptedPayloadHash"].getStr(),
        previousHash: entry1["previousHash"].getStr()
      )
      
      let tuple2 = (
        sequence: entry2["sequence"].getInt(),
        entryType: entry2["entryType"].getStr(),
        payloadHash: entry2["encryptedPayloadHash"].getStr(),
        previousHash: entry2["previousHash"].getStr()
      )
      
      let tuple3 = (
        sequence: entry3["sequence"].getInt(),
        entryType: entry3["entryType"].getStr(),
        payloadHash: entry3["encryptedPayloadHash"].getStr(),
        previousHash: entry3["previousHash"].getStr()
      )
      
      # Flow: Check tuple consensus.
      if not (tuple1.sequence == tuple2.sequence and tuple2.sequence == tuple3.sequence and
              tuple1.entryType == tuple2.entryType and tuple2.entryType == tuple3.entryType and
              tuple1.payloadHash == tuple2.payloadHash and tuple2.payloadHash == tuple3.payloadHash and
              tuple1.previousHash == tuple2.previousHash and tuple2.previousHash == tuple3.previousHash):
        result.status = rcHashMismatch
        result.description = "triumvirate metadata mismatch at sequence " & $tuple1.sequence
        return
    
    result.status = rcHealthy
    result.description = "all three copies agree on metadata"
  elif validCopyCount < 3:
    result.status = rcChainBroken
    result.description = "chain broken in " & $result.brokenKeys.len & " copies"
  else:
    result.status = rcSequenceError
    result.description = "copy lengths differ: " & $copy1.len & ", " & 
      $copy2.len & ", " & $copy3.len

# Flow: Extract metadata tuple from a single RECORD entry for comparison.
proc extractMetadataTuple*(entry: JsonNode): tuple[
  sequence: int,
  entryType: string,
  payloadHash: string,
  previousHash: string
] =
  result.sequence = entry["sequence"].getInt()
  result.entryType = entry["entryType"].getStr()
  result.payloadHash = entry["encryptedPayloadHash"].getStr()
  result.previousHash = entry["previousHash"].getStr()

# Flow: Check if all three metadata tuples match (consensus).
proc allMetadataMatch*(tuple1, tuple2, tuple3: auto): bool =
  result = (tuple1.sequence == tuple2.sequence and
            tuple2.sequence == tuple3.sequence) and
           (tuple1.entryType == tuple2.entryType and
            tuple2.entryType == tuple3.entryType) and
           (tuple1.payloadHash == tuple2.payloadHash and
            tuple2.payloadHash == tuple3.payloadHash) and
           (tuple1.previousHash == tuple2.previousHash and
            tuple2.previousHash == tuple3.previousHash)

# Flow: Reconciliation report for structured output.
proc formatReconciliationReport*(reconcResult: ReconciliationResult): string =
  result = "reconciliation_status=" & $reconcResult.status & ","
  result &= "healthy_copies=" & $reconcResult.healthyCount & ","
  result &= "broken_keys=[" & reconcResult.brokenKeys.mapIt("\"" & it & "\"").join(",") & "],"
  result &= "description=\"" & reconcResult.description & "\""
