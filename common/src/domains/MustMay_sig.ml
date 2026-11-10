(* Signatures for may/must domain.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2026 *)

module type INPUT = sig

  type t

  val compare : t -> t -> int

  val show : t -> string

end
