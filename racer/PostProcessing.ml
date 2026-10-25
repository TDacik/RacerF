(* Postprocessing of data races based on detected imprecisions.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2024 *)

open Imprecision

(** Return true if the given imprecision may hide a race. *)
let could_cause_unsoundness = function
  | Unlock _ | FunctionPointer _ | PthreadOnce | Barrier -> true (* TODO: true for barrier? *)
  | _ -> false

(** Return true if the given imprecision may introduce a false alarm. *)
let could_cause_incompleteness = function
  | FunctionPointer _ | Unlock _ | Backend _ -> false
  | _ -> true

let run res =
  if RaceAnalysis.Result.is_race_free res
  then Imprecision.report could_cause_unsoundness
  else Imprecision.report could_cause_incompleteness
