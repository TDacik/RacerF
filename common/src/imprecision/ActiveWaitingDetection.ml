(* Detection of active waiting patterns.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2026 *)

open Cil_types
open Cil_datatype

let rec is_plain_var rhs = match rhs.enode with
  | Lval (Var _, NoOffset) -> true
  | CastE (_, e) -> is_plain_var e
  | _ -> false

let is_simple_assignment rhs = 
 Cil.isConstant ~is_varinfo_cst:(fun v -> v.vtemp) rhs
 || is_plain_var rhs

(** Frama-C/CIL sometimes creates the following:
      return_label: ; return ...; *) 
let is_fallthrough_return target res = match target.skind, target.succs with
  | Instr (Skip _), [t] -> Stmt.equal res t
  | _ -> false

let rec is_pure_function visited var =
  if not @@ Globals.Functions.mem var then false
  else if Varinfo.Set.mem var visited then true
  else match (Globals.Functions.get var).fundec with
    | Definition (def, _) -> 
      List.for_all (check_stmt (Varinfo.Set.add var visited)) def.sallstmts
    | Declaration _ -> false

and check_stmt visited_fns stmt =
 let check = check_stmt visited_fns in
 match stmt.skind with
 | Break _ | Continue _ | Return _ -> true
 | If (_, block_else, block_then, _) ->
   List.for_all check block_else.bstmts
   && List.for_all check block_then.bstmts
 | Goto (target, _) ->
   (* True for jump directly to return *)
   let ret = Kernel_function.find_return @@ Kernel_function.find_englobing_kf stmt in
   Stmt.equal ret !target || is_fallthrough_return !target ret
 | Block b -> List.for_all check b.bstmts
 | UnspecifiedSequence seq -> 
   let stmts = List.map (fun (s, _, _, _, _) -> s) seq in
   List.for_all check stmts
 | Loop (_, b, _, _, _) -> List.for_all check b.bstmts
 | Instr (Skip _) -> true
 | Instr (Call (_, Var v, _, _)) -> 
   ConcurrencyModel.is_atomic_fn v || is_pure_function visited_fns v
 | Instr (Local_init (_, init, _)) when CIL_utils.is_constant_init init -> true
 | Instr (Set ((Var v, NoOffset), _, _)) when v.vname = "__retres" -> true
 | Instr (Set (_, rhs, _)) when is_simple_assignment rhs -> true
 | _ -> false

let is_active_waiting_loop stmt = match stmt.skind with
  | Loop (_, b, _, _, _) -> List.for_all (check_stmt Varinfo.Set.empty) b.bstmts
  | _ -> false

let run () =
  CFG_utils.filter_stmts is_active_waiting_loop
  |> List.iter (fun s -> Imprecision.add (Imprecision.ActiveWaiting s))
