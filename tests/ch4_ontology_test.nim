# Wilder Cosmos 0.4.0
# Module name: ch4_ontology_test Tests
# Module Path: tests/ch4_ontology_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

# Summary: Chapter 4 ontology testing — comprehensive verification of 
#   Concept, Occurrence, Perception, and Thing types with lifecycle.
# Simile: Like quality control for lego bricks — each piece must fit,
#   stack, and work deterministically before shipping.
# Memory note: Tests must verify serialization round-trips, lifecycle
#   state transitions, and deterministic filtering behavior.
# Flow: Test type creation → lifecycle → occurrence emission →
#   perception filtering → serialization round-trip.

import json
import std/strutils
import ../src/cosmos/thing/thing

# Flow: Execute procedure with deterministic test helper behavior.
proc testConceptCreation*() =
  ## Test Concept instantiation with six sections.
  let c = createConcept(
    id = "concept_1",
    what = %*{"purpose": "monitor health"},
    why = %*{"rationale": "ensure system stability"},
    how = %*{"mechanism": "periodic checks"},
    where = %*{"scope": "runtime"},
    `when` = %*{"temporal": "every epoch"},
    withSection = %*{"requires": ["validation", "messaging"]},
    manifest = %*{"interrogatives": 10}
  )
  assert c.id == "concept_1"
  assert c.whatSection["purpose"].getStr == "monitor health"
  assert c.manifest["interrogatives"].getInt == 10
  echo "✓ testConceptCreation passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testOccurrenceCreation*() =
  ## Test Occurrence creation with validation.
  let occ = createOccurrence(
    id = "occ_1",
    source = "thing_1",
    epoch = 100,
    payload = %*{"event": "status_change"},
    radius = 2
  )
  assert occ.id == "occ_1"
  assert occ.source == "thing_1"
  assert occ.epoch == 100
  assert occ.projectionRadius == 2
  echo "✓ testOccurrenceCreation passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testOccurrenceValidation*() =
  ## Test Occurrence validation rejects empty id/source.
  try:
    discard createOccurrence(id = "", source = "thing_1", epoch = 0, payload = %*{})
    assert false, "Should reject empty id"
  except ValueError as e:
    assert e.msg.contains("id cannot be empty")
  
  try:
    discard createOccurrence(id = "occ_1", source = "", epoch = 0, payload = %*{})
    assert false, "Should reject empty source"
  except ValueError as e:
    assert e.msg.contains("source cannot be empty")
  
  try:
    discard createOccurrence(id = "occ_1", source = "thing_1", epoch = 0, payload = %*{}, radius = -1)
    assert false, "Should reject negative radius"
  except ValueError as e:
    assert e.msg.contains("projectionRadius must be non-negative")
  
  echo "✓ testOccurrenceValidation passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testPerceptionCreation*() =
  ## Test Perception instantiation.
  let perception = createPerception(
    occurrenceId = "occ_1",
    thingId = "thing_1",
    epoch = 100,
    filtered = true
  )
  assert perception.occurrenceId == "occ_1"
  assert perception.thingId == "thing_1"
  assert perception.epoch == 100
  assert perception.filtered == true
  echo "✓ testPerceptionCreation passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testPerceptionValidation*() =
  ## Test Perception validation rejects empty ids.
  try:
    discard createPerception(occurrenceId = "", thingId = "thing_1", epoch = 0)
    assert false, "Should reject empty occurrenceId"
  except ValueError as e:
    assert e.msg.contains("occurrenceId cannot be empty")
  
  try:
    discard createPerception(occurrenceId = "occ_1", thingId = "", epoch = 0)
    assert false, "Should reject empty thingId"
  except ValueError as e:
    assert e.msg.contains("thingId cannot be empty")
  
  echo "✓ testPerceptionValidation passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testThingInstantiation*() =
  ## Test Thing creation from Concept.
  let c = createConcept(
    id = "concept_1",
    what = %*{"purpose": "test"},
    why = %*{},
    how = %*{},
    where = %*{},
    `when` = %*{},
    withSection = %*{},
    manifest = %*{}
  )
  
  var thing = instantiateThing(
    thingId = "thing_1",
    conceptBlueprint = c,
    initialStatus = %*{"health": "ok"},
    epoch = 0
  )
  
  assert thing.id == "thing_1"
  assert thing.conceptId == "concept_1"
  assert thing.status["health"].getStr == "ok"
  assert thing.epoch == 0
  assert thing.active == true
  echo "✓ testThingInstantiation passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testThingInstantiationValidation*() =
  ## Test Thing instantiation rejects invalid inputs.
  let c = createConcept(id = "c1", what = %*{}, why = %*{}, how = %*{},
    where = %*{}, `when` = %*{}, withSection = %*{}, manifest = %*{})
  
  try:
    discard instantiateThing(thingId = "", conceptBlueprint = c, initialStatus = %*{})
    assert false, "Should reject empty thingId"
  except ValueError as e:
    assert e.msg.contains("id cannot be empty")
  
  let badConcept = Concept(id: "", whatSection: %*{}, whySection: %*{},
    howSection: %*{}, whereSection: %*{}, whenSection: %*{}, withSection: %*{},
    manifest: %*{})
  
  try:
    discard instantiateThing(thingId = "thing_1", conceptBlueprint = badConcept, initialStatus = %*{})
    assert false, "Should reject concept with empty id"
  except ValueError as e:
    assert e.msg.contains("concept id cannot be empty")
  
  echo "✓ testThingInstantiationValidation passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testThingLifecycle*() =
  ## Test Thing lifecycle: active → inactive → cannot update.
  let c = createConcept(id = "c1", what = %*{}, why = %*{}, how = %*{},
    where = %*{}, `when` = %*{}, withSection = %*{}, manifest = %*{})
  
  var thing = instantiateThing(thingId = "thing_1", conceptBlueprint = c,
    initialStatus = %*{"status": "new"})
  
  assert thing.active == true
  
  # Update status while active
  thing.updateStatus(%*{"status": "updated"})
  assert thing.status["status"].getStr == "updated"
  assert thing.epoch == 1
  
  # Deactivate
  thing.deactivateThing()
  assert thing.active == false
  
  # Cannot update after deactivation
  try:
    thing.updateStatus(%*{"status": "again"})
    assert false, "Should not allow status update on inactive Thing"
  except ValueError:
    discard
  
  echo "✓ testThingLifecycle passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testPerceptionRecording*() =
  ## Test recording Perceptions in Thing's log.
  let c = createConcept(id = "c1", what = %*{}, why = %*{}, how = %*{},
    where = %*{}, `when` = %*{}, withSection = %*{}, manifest = %*{})
  var thing = instantiateThing(thingId = "thing_1", conceptBlueprint = c,
    initialStatus = %*{})
  
  let perception = createPerception(
    occurrenceId = "occ_1",
    thingId = "thing_1",
    epoch = 100,
    filtered = true
  )
  
  thing.recordPerception(perception)
  assert thing.perceptionLog.len == 1
  assert thing.perceptionLog[0].occurrenceId == "occ_1"
  
  echo "✓ testPerceptionRecording passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testPerceptionRecordingInactive*() =
  ## Test that recording Perception fails on inactive Thing.
  let c = createConcept(id = "c1", what = %*{}, why = %*{}, how = %*{},
    where = %*{}, `when` = %*{}, withSection = %*{}, manifest = %*{})
  var thing = instantiateThing(thingId = "thing_1", conceptBlueprint = c,
    initialStatus = %*{})
  
  thing.deactivateThing()
  
  let perception = createPerception(occurrenceId = "occ_1", thingId = "thing_1",
    epoch = 100)
  
  try:
    thing.recordPerception(perception)
    assert false, "Should not record perception on inactive Thing"
  except ValueError:
    discard
  
  echo "✓ testPerceptionRecordingInactive passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testOccurrenceFiltering*() =
  ## Test deterministic Occurrence filtering.
  let c = createConcept(id = "c1", what = %*{}, why = %*{}, how = %*{},
    where = %*{}, `when` = %*{}, withSection = %*{}, manifest = %*{})
  var thing = instantiateThing(thingId = "thing_1", conceptBlueprint = c,
    initialStatus = %*{})
  
  let normalOcc = createOccurrence(id = "occ_1", source = "thing_2", epoch = 100,
    payload = %*{})
  let reservedOcc = createOccurrence(id = "occ_2", source = ".*reserved.*",
    epoch = 100, payload = %*{})
  
  assert thing.filterOccurrence(normalOcc) == true
  assert thing.filterOccurrence(reservedOcc) == false
  
  echo "✓ testOccurrenceFiltering passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testOccurrenceFilteringInactive*() =
  ## Test that inactive Things filter nothing.
  let c = createConcept(id = "c1", what = %*{}, why = %*{}, how = %*{},
    where = %*{}, `when` = %*{}, withSection = %*{}, manifest = %*{})
  var thing = instantiateThing(thingId = "thing_1", conceptBlueprint = c,
    initialStatus = %*{})
  
  thing.deactivateThing()
  
  let occ = createOccurrence(id = "occ_1", source = "thing_2", epoch = 100,
    payload = %*{})
  
  assert thing.filterOccurrence(occ) == false
  
  echo "✓ testOccurrenceFilteringInactive passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testOccurrenceEmission*() =
  ## Test emitting an Occurrence from a Thing.
  let occ = emitOccurrence(
    thingId = "thing_1",
    epoch = 50,
    payload = %*{"action": "emit_test"},
    sourceLabel = "thing"
  )
  
  assert occ.source == "thing_1"
  assert occ.epoch == 50
  assert occ.payload["action"].getStr == "emit_test"
  assert occ.id.contains("thing_1")
  assert occ.id.contains("50")
  
  echo "✓ testOccurrenceEmission passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testThingSerialization*() =
  ## Test Thing serialization to/from JSON.
  let c = createConcept(id = "c1", what = %*{}, why = %*{}, how = %*{},
    where = %*{}, `when` = %*{}, withSection = %*{}, manifest = %*{})
  var thing = instantiateThing(thingId = "thing_1", conceptBlueprint = c,
    initialStatus = %*{"health": "ok"})
  
  let perception = createPerception(occurrenceId = "occ_1", thingId = "thing_1",
    epoch = 100)
  thing.recordPerception(perception)
  
  # Serialize to JSON
  let jsonData = thing.thingToJson()
  assert jsonData["id"].getStr == "thing_1"
  assert jsonData["conceptId"].getStr == "c1"
  assert jsonData["status"]["health"].getStr == "ok"
  assert jsonData["perceptionLog"].len == 1
  assert jsonData["active"].getBool == true
  
  echo "✓ testThingSerialization passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testThingDeserialization*() =
  ## Test Thing deserialization from JSON round-trip.
  let c = createConcept(id = "c1", what = %*{}, why = %*{}, how = %*{},
    where = %*{}, `when` = %*{}, withSection = %*{}, manifest = %*{})
  var thing = instantiateThing(thingId = "thing_1", conceptBlueprint = c,
    initialStatus = %*{"health": "ok"})
  
  let perception = createPerception(occurrenceId = "occ_1", thingId = "thing_1",
    epoch = 100, filtered = true)
  thing.recordPerception(perception)
  
  # Serialize and deserialize
  let jsonData = thingToJson(thing)
  let restoredThing = thingFromJson(jsonData)
  
  assert restoredThing.id == "thing_1"
  assert restoredThing.conceptId == "c1"
  assert restoredThing.status["health"].getStr == "ok"
  assert restoredThing.perceptionLog.len == 1
  assert restoredThing.perceptionLog[0].occurrenceId == "occ_1"
  assert restoredThing.active == true
  
  echo "✓ testThingDeserialization passed"

# Flow: Execute procedure with deterministic test helper behavior.
proc testThingDeserializationValidation*() =
  ## Test Thing deserialization validation.
  try:
    discard thingFromJson(%*{"other": "data"})
    assert false, "Should reject JSON without required fields"
  except ValueError as e:
    assert e.msg.contains("missing required")
  
  try:
    discard thingFromJson(%*["not", "json"])
    assert false, "Should reject non-object JSON"
  except ValueError:
    discard
  
  echo "✓ testThingDeserializationValidation passed"

when isMainModule:
  echo "Running Chapter 4 Ontology Tests..."
  echo ""
  
  testConceptCreation()
  testOccurrenceCreation()
  testOccurrenceValidation()
  testPerceptionCreation()
  testPerceptionValidation()
  testThingInstantiation()
  testThingInstantiationValidation()
  testThingLifecycle()
  testPerceptionRecording()
  testPerceptionRecordingInactive()
  testOccurrenceFiltering()
  testOccurrenceFilteringInactive()
  testOccurrenceEmission()
  testThingSerialization()
  testThingDeserialization()
  testThingDeserializationValidation()
  
  echo ""
  echo "✅ All Chapter 4 tests passed!"
