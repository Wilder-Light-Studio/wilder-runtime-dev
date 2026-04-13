# Wilder Cosmos 0.4.0
# Module name: Result Type
# Module Path: src/runtime/result.nim
# Summary: A simple Result type for error handling.

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

proc isOk*[T](r: Result[T]): bool =
  r.it == rOk

proc isErr*[T](r: Result[T]): bool =
  r.it == rErr

proc get*[T](r: Result[T]): T =
  if r.isOk:
    return r.value
  else:
    raise newException(ValueError, "Called get on Err result")

proc error*[T](r: Result[T]): string =
  if r.isErr:
    return r.error
  else:
    raise newException(ValueError, "Called error on Ok result")

proc value*[T](r: Result[T]): T =
  if r.isOk:
    return r.value
  else:
    raise newException(ValueError, "Called value on Err result")
