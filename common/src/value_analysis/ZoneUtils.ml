(* Utilities for manipulation with Frama-C's memory zones.
 *
 * The main goal is checking of atomicity of memory accesses
 * which cannot be done purely on memory bases.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2026 *)

let is_atomic_type typ = Ast_types.has_attribute Constants.racerf_atomic_attr typ

let is_fully_atomic_type typ =
  if Ast_types.is_array typ 
  then is_atomic_type @@ Ast_types.element_type typ
  else is_atomic_type typ

let concretise_zone_aux fn zone =
  try Memory_zone.fold_i (fun base offsets acc ->
    if Int_Intervals.is_top offsets then acc
    else match fn (base, offsets) with
      | Some x -> x :: acc
      | None -> acc
  ) zone []
  with Abstract_interp.Error_Top -> []

let filter_offsets base typ offsets =
  Imprecision.add (Imprecision.AtomicAttr base);
  offsets

  (*match typ.tnode with
  | TComp { cstruct = true; cfields = Some fields; _ } ->
  | _ -> offsets*)

let filter_atomic (base, offsets) = match Base.typeof base with
  | Some t when is_fully_atomic_type t -> None
  | Some t when Ast_types.has_attribute_memory_block "racerf_atomic" t ->
    Some (base, filter_offsets base t offsets) 
  | _ -> Some (base, offsets)

let concretise_zone = concretise_zone_aux filter_atomic

