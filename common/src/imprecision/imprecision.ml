(* Imperative tracking of potential sources of incorrect analysis.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2024 *)

open Cil_datatype

type t =
  | MemAccess of Stmt.t
  | Lock of Stmt.t * Exp.t
  | Unlock of Stmt.t * Exp.t
  | FunctionPointer of Varinfo.t
  | ThreadParamArray of Stmt.t
  | Join of Stmt.t
  | JoinInLoop of Stmt.t
  | ActiveWaiting of Stmt.t
  | TryLock of String.t
  | Malloc
  | UnreleasedLock of Kernel_function.t * Lock.t
  | AtomicFnWithBody of Kernel_function.t

  (* Unsupported pthread functions *)
  | Semaphore
  | Barrier
  | PthreadOnce

  | Backend of t
[@@deriving compare]

module S = Set.Make(struct
  type nonrec t = t
  let compare = compare
end)

let imprecisions = ref S.empty

let add (source : t) =
  imprecisions := S.add source !imprecisions

let add_backend (source : t) = () (*add (Backend source)*)

let get_imprecisions () = !imprecisions

let rec show = function
  | MemAccess (stmt) ->
    Format.asprintf "Memory access at %a" Print_utils.pretty_stmt_short stmt
  | Lock (stmt, _) ->
    Format.asprintf "No lock at %a" Print_utils.pretty_stmt_short stmt
  | Unlock (stmt, _) ->
    Format.asprintf "No unlock at %a" Print_utils.pretty_stmt_short stmt
  | FunctionPointer var ->
    Format.asprintf "Function pointer %a" Cil_datatype.Varinfo.pretty var
  | ThreadParamArray stmt ->
    Format.asprintf "Thread created at %a has array parameter" Print_utils.pretty_stmt_short stmt
  | Join stmt ->
    Format.asprintf "Thread join at %a" Print_utils.pretty_stmt_short stmt
  | JoinInLoop stmt ->
    Format.asprintf "Thread join in loop at %a" Print_utils.pretty_stmt_short stmt
  | ActiveWaiting stmt ->
    Format.asprintf "Active waiting at %a" Print_utils.pretty_stmt_short stmt
  | TryLock (str) ->
    Format.asprintf "Trylock status cannot be checked: %s" str
  | Malloc ->
    Format.asprintf "Dynamic allocation"
  | UnreleasedLock (kf, lock) ->
    Format.asprintf "Thread %a did not released mutex %a (possible deadlock)"
      Kernel_function.pretty kf Lock.pp lock
  | AtomicFnWithBody kf ->
    Format.asprintf "Atomic function with implementation %a" Kernel_function.pretty kf

  | Backend imprecision ->
    Format.asprintf "%s (not supported by the backend)" (show imprecision)

  | Semaphore -> "Semaphores"
  | Barrier -> "Barriers"
  | PthreadOnce -> "Function pthread_once"

let report filter =
  let imprecisions = S.filter filter !imprecisions in
  if not @@ S.is_empty imprecisions then
    let _ = Core0.result "The result may be imprecise, reasons:" in
    S.iter (fun i -> Core0.result "  - %s" (show i)) imprecisions
