# Wilder Cosmos 0.4.0
# Module name: Result Type
# Module Path: src/runtime/result.nim
# Summary: A simple Result type for error handling.
# Simile: Like an envelope marked either "contents" or "reason it's empty" —
#   check the mark before opening it.
# Memory note: get, value and error raise when called on the wrong kind; check
#   isOk or isErr first.
# Flow: build with ok or err -> check isOk or isErr -> read value or error.

type
  ResultKind* = enum rOk, rErr

  Result*[T] = object
    case it: ResultKind
    of rOk: value: T
    of rErr: error: string

template ok*[T](val: T): Result[T] =
  Result[T](it: rOk, value: val)

template err*[T](e: string): Result[T] =
  Result[T](it: rErr, error: e)

# Flow: Report whether the Result holds a value.
proc isOk*[T](r: Result[T]): bool =
  r.it == rOk

# Flow: Report whether the Result holds an error.
proc isErr*[T](r: Result[T]): bool =
  r.it == rErr

# Flow: Return the value, raising if the Result holds an error.
proc get*[T](r: Result[T]): T =
  if r.isOk:
    return r.value
  else:
    raise newException(ValueError, "Called get on Err result")

# Flow: Return the error message, raising if the Result holds a value.
proc error*[T](r: Result[T]): string =
  if r.isErr:
    return r.error
  else:
    raise newException(ValueError, "Called error on Ok result")

# Flow: Return the value, raising if the Result holds an error (same as get).
proc value*[T](r: Result[T]): T =
  if r.isOk:
    return r.value
  else:
    raise newException(ValueError, "Called value on Err result")
