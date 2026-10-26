(* Detection of potential imprecisions in source code.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2024 *)

open Cil_types

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
  | _ -> ()

let check_functions () =
  Globals.Functions.iter (fun kf ->
    if Kernel_function.is_not_called kf then ()
    else check_function kf
  )

let is_active_waiting stmt =
  let rec check_instructions stmt = match stmt.skind with
    | If (_, block_else, block_then, _) ->
      List.for_all check_instructions block_else.bstmts
      && List.for_all check_instructions block_then.bstmts
    | Break _ -> true
    | Block b -> List.for_all check_instructions b.bstmts
    | _ -> false
  in
  match stmt.skind with
  | Loop (_, block, _, _, _) -> begin match block.bstmts with
    | stmts -> List.for_all check_instructions stmts
    end
  | _ -> false

let check () =
  check_functions ();
  let empty_while_loops = CFG_utils.filter_stmts is_active_waiting in
  List.iter (fun s -> add (ActiveWaiting s)) empty_while_loops
