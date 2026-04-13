# Wilder Cosmos 0.4.0
# Module name: Result Type
# Module Path: src/runtime/result.nim
# Summary: A simple Result type for error handling.

type
  ResultKind = enum rOk, rErr

  Result[T, E] = object
    case it: ResultKind:
      rOk: value: T
      rErr: error: E

proc ok[T, E](val: T): Result[T, E] =
  Result[T, E](it: rOk, value: val)

proc err[T, E](e: E): Result[T, E] =
  Result[T, E](it: rErr, error: e)

proc isOk[T, E](r: Result[T, E]): bool =
  r.it == rOk

proc isErr[T, E](r: Result[T, E]): bool =
  r.it == rErr

proc unwrap[T, E](r: Result[T, E]): T =
  if r.isOk:
    r.value
  else:
    raise newException(ValueError, "Called unwrap on Err result")

proc unwrapOr[T, E](r: Result[T, E], default: T): T =
  if r.isOk:
    r.value
  else:
    default

proc map[T, E, U](r: Result[T, E], f: proc(T): U): Result[U, E] =
  if r.isOk:
    ok(f(r.value))
  else:
    err(r.error)

proc flatMap[T, E, U](r: Result[T, E], f: proc(T): Result[U, E]): Result[U, E] =
  if r.isOk:
    f(r.value)
  else:
    err(r.error)

proc fold[T, E, U](r: Result[T, E], okFunc: proc(T): U, errFunc: proc(E): U): U =
  if r.isOk:
    okFunc(r.value)
  else:
    errFunc(r.error)