open Cil_types

let is_null exp = Cil.isZero @@ Cil.constFold true exp

let is_constant_init init =
  let is_const exp = Cil.isConstant ~is_varinfo_cst:(fun v -> v.vtemp) exp in
  match init with
  | AssignInit (SingleInit exp) -> is_const exp
  | AssignInit (CompoundInit _) -> false (* TODO *)
  | ConsInit (_, exps, _) -> List.for_all is_const exps
