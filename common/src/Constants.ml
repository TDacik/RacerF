(* Definitions of constants used by the plugins
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2026 *)

(** In C, the attributes is written as __racerf_atomic__. 
    Frama-C strips trailing '_' characters. *)
let racerf_atomic_attr = "racerf_atomic"
