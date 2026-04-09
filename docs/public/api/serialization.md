# serialization — Envelopes & Serializers

> Source: `src/runtime/serialization.nim`

Serialization envelopes with deterministic SHA256 checksums and pluggable serializer abstraction for JSON and Protobuf transports.

---

## Types

### `SerializerKind`

```nim
SerializerKind* = enum
  skJson
  skProtobuf
```

### `Serializer`

Base serializer type. Subclassed by `JsonSerializer` and `ProtobufSerializer`.

```nim
Serializer* = ref object of RootObj
  kind*: SerializerKind

JsonSerializer* = ref object of Serializer
ProtobufSerializer* = ref object of Serializer
```

---

## Procedures

### Envelope Wrapping

```nim
proc envelopeWrap*(data: JsonNode, schemaVersion: int): JsonNode
```
Wrap data with metadata and a SHA256 checksum.

```nim
proc envelopeUnwrap*(env: JsonNode): JsonNode
```
Validate checksum and extract payload from an envelope.

### Typed Serialization

```nim
proc serializeWithEnvelope*[T](value: T, schemaVersion: int): JsonNode
```
Serialize a typed value into a checksummed envelope.

```nim
proc deserializeWithEnvelope*[T](env: JsonNode): T
```
Deserialize a typed value from a validated envelope.

### Serializer Interface

```nim
proc encode*(s: Serializer, msg: JsonNode): seq[byte]
proc decode*(s: Serializer, data: seq[byte]): JsonNode
proc selectSerializer*(transport: TransportKind): Serializer
```
`selectSerializer` returns the appropriate serializer for the given `TransportKind`.
