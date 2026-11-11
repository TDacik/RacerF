(* Removal of trivial branching.
 *
 * The goal of this pass is to simplify the following pattern introduced by loop unrolling:
 *
 *   type i = const;
 *   { if expr(i) then C1 else C2; ... }
 *
 * TODO: the implementation with visitors crash on pthread-driver-races benchmarks.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2024 *)

open Cil_types
open Cil_datatype

let is_instr stmt = match stmt.skind with Instr _ -> true | _ -> false
let is_block stmt = match stmt.skind with Block _ -> true | _ -> false

let exp_as_const expr = match (Cil.stripCasts expr).enode with
  | Const c -> c
  | _ -> raise Exit

class substitution var const = object
  inherit Visitor.frama_c_copy (Project.create "dummy")

  method! vexpr e = match e.enode with
    | Lval (Var var', NoOffset) ->
      if Varinfo.equal var var' then ChangeTo {e with enode = Const const}
      else DoChildren
    | _ -> DoChildren

end

let inline fst snd =
  match fst.skind, snd.skind with
    | Instr (Local_init (v, AssignInit (SingleInit e), loc)), Block b ->
      let const = exp_as_const e in
      let head, tail = List.hd b.bstmts, List.tl b.bstmts in
      begin match head.skind with
      | If (cond, b_then, b_else, loc) ->
        let cond' = Visitor.visitFramacExpr (new substitution v const) cond in
        let cond'' = Cil.constFoldToInt ~machdep:true cond' in
        let res = match cond'' with
          | Some i when Z.is_one i -> b_then
          | Some i when Z.is_zero i -> b_else
          | None -> raise Exit
        in
        Format.printf "Removing a branch\n";
        b.bstmts <- res.bstmts @ tail;
        b.blocals <- res.blocals @ b.blocals
      | _ -> raise Exit
      end
    | _ -> raise Exit

class visitor = object
  inherit Visitor.frama_c_inplace

  method! vstmt_aux stmt = match stmt.skind with
    | Block block when List.length block.bstmts > 1 ->
      begin try
        Core0.feedback "Considering block at %d" (Print_utils.stmt_line stmt);
        let fst, snd = match block.bstmts with x :: y :: _ -> (x, y) in
        inline fst snd;
        DoChildren
      with Exit | _ -> DoChildren
      end
    | _ -> DoChildren

end

let transform file =
  Core0.feedback "Removing trivial IFs";
  Visitor.visitFramacFileSameGlobals (new visitor) file;
  List.iter (function
    | GFun (fundec, _) -> Frama_c_kernel.File.must_recompute_cfg fundec
    | _ -> ()
  ) file.globals;
  Ast.mark_as_changed ()

let run file =
  if Core0.Inline.get () then transform file
  else ()

let () =
  let module F = Frama_c_kernel.File in
  let category = F.register_code_transformation_category "remove-trivial-branching" in
  F.add_code_transformation_after_cleanup ~after:[Unfold_loops.transform] category run
