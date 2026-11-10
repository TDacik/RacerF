(* Domain representing mapping to {must, may}.
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2026 *)

open MustMay_sig

module Value = struct

  type t = Must | May [@@deriving equal, compare]

  let show = function
    | Must -> "must"
    | May -> "may"

  let join x y = match x, y with
    | May, _ | _, May -> May
    | Must, Must -> Must

  let join_opt x y = match x, y with
    | None, _ | _, None -> Some May
    | Some x, Some y -> Some (join x y)

end

module Make (I : INPUT) = struct

  open Value

  type elem = I.t
  module ElemSet = Set.Make(I)

  module M = Map.Make(I)

  type t = Value.t M.t [@@deriving equal, compare]

  let show self =
    let show_elem = function
      | (e, Must) -> I.show e
      | (e, May) -> Format.asprintf "?%s" (I.show e)
    in
    M.bindings self
    |> List.map show_elem
    |> String.concat ", "
    |> (fun str -> "{" ^ str ^ "}")

  let join xs ys = M.merge (fun _ -> Value.join_opt) xs ys

  let empty = M.empty

  let singleton x = M.singleton x Must

  let set_must self x = M.add x Must self

  let set_may self x = M.add x May self

  let set_must_list self xs = List.fold_left set_must self xs

  let set_may_list self xs = List.fold_left set_may self xs

  let set_must_not self x = M.remove x self

  let set_all_may self = M.map (fun _ -> May) self

  (** Queries *)

  let is_must self x =
    try M.find self x = Must
    with Not_found -> false

  let is_may self x =
    try
      let res = M.find self x in
      res = May || res = Must
    with Not_found -> false

  let get_keys self = List.map fst @@ M.bindings self

  let may_set = get_keys

  let must_set self =
    M.filter (fun _ v -> v = Must) self
    |> get_keys

end
