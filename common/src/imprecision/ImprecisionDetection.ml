(* Detection of potential imprecisions in source code.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2024 *)

open Imprecision

let allocation_functions = [
  "malloc";
  "calloc";
  "alloca"
]

let semaphore_functions = [
  "sem_wait";
  "sem_trywait";
  "sem_timedwait";
  "sem_clockwait";
  "sem_post";
  "sem_getvalue"
]

let check_function kf = match Kernel_function.get_name kf with
  | name when List.mem name allocation_functions -> Imprecision.add_backend Malloc
  | name when List.mem name semaphore_functions -> Imprecision.add Semaphore
  | "pthread_barrier_wait" -> Imprecision.add Barrier
  | "pthread_once" -> Imprecision.add PthreadOnce
  | _ when ConcurrencyModel.is_atomic_kf kf && Kernel_function.has_definition kf ->
    Imprecision.add (AtomicFnWithBody kf)
  | _ -> ()

let check_functions () =
  Globals.Functions.iter (fun kf ->
    if Kernel_function.is_not_called kf then ()
    else check_function kf
  )

(** Check for pthread_join using the return value of a thread. This information
    currently cannot be propagated by thread analysis. *)
let check_join_with_return_value () =
  let check stmt = match ConcurrencyModel.classify_stmt stmt with
    | Thread_join (_, ret) ->
      (** TODO: could be refined in common situation when thread always returns NULL *)
      not @@ (CIL_utils.is_null ret)
    | _ -> false
  in
  CFG_utils.filter_stmts check
  |> List.iter (fun s -> add (JoinWithReturn s))

let check () =
  check_functions ();
  check_join_with_return_value ();
  ActiveWaitingDetection.run ()
