open Cil_types

let is_null exp = Cil.isZero @@ Cil.constFold true exp

let is_constant_init init =
  let is_const exp = Cil.isConstant ~is_varinfo_cst:(fun v -> v.vtemp) exp in
  match init with
  | AssignInit (SingleInit exp) -> is_const exp
  | AssignInit (CompoundInit _) -> false (* TODO *)
  | ConsInit (_, exps, _) -> List.for_all is_const exps

let kf_return_expressions kf =
  let fundec = Kernel_function.get_definition kf in
  List.filter_map (fun stmt -> match stmt.skind with
    | Instr (Set ((Var v, NoOffset), exp, _)) when String.equal v.vname "__retres" ->
      Some exp
    | _ -> None
  ) fundec.sbody.bstmts
