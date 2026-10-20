(* Witness generator for format 2.2
 *
 * Author: Tomas Dacik (idacik@fit.vut.cz), 2024 *)

open WitnessUtils

let version = "2.2"

let get_machdep () = match Machine.machdep_name () with
  | "machdep_gcc_x86_32" -> "ILP32"
  | "machdep_gcc_x86_64" -> "LP64"
  | _ -> assert false

let yaml_files () =
  get_files ()
  |> List.map (fun f -> `String f)

let yaml_file_hashes () =
  get_file_hashes ()
  |> List.map (fun (f, h) -> (f, `String h))

let yaml_producer metadata = [
  ("name",    `String metadata.producer);
  ("version", `String metadata.version);
]

let yaml_task metadata : (string * Yaml.value) list = [
  ("input_files",       `A (yaml_files ()));
  ("input_file_hashes", `O (yaml_file_hashes ()));
  ("specification",     `String metadata.spec);
  ("data_model",        `String (get_machdep ()));
  ("language",          `String metadata.language);
]

let yaml_metadata metadata uuid time : (string * Yaml.value) list = [
  ("format_version", `String version);
  ("uuid",           `String uuid);
  ("creation_time",  `String time);
  ("producer",       `O (yaml_producer metadata));
  ("task",           `O (yaml_task metadata));
]

(** Witness content *)

let yaml_location stmt : (string * Yaml.value) list =
  let open Cil_datatype in
  let loc = Stmt.loc stmt in
  let kf = Kernel_function.find_englobing_kf stmt in
  let file = (* TODO: fix after removing external preprocessing *)
    let files = get_files () in
    assert (List.length files == 1);
    List.hd files
  in
  [
    ("file_name", `String file (*Filepath.show @@ Fileloc.path loc*));
    ("line",      `Float (Float.of_int @@ Fileloc.line loc));
    ("function",  `String (Format.asprintf "%a" Kernel_function.pretty kf));
  ]

let thread_entry t : Yaml.value =
  `O [
        ("type",      `String "function_enter");
        ("action",    `String "follow");
        ("thread_id", `Float 0.0); (* TODO: 0 = main, implement lookup in thread graph *)
        ("location",  `O (yaml_location @@ Option.get @@ Thread.get_create_stmt t));
   ]

let final_waypoint n stmt : Yaml.value =
  `O  [
        ("type",      `String "target");
        ("action",    `String "follow");
        ("thread_id", `Float (Float.of_int n));
        ("location",  `O (yaml_location stmt));
  ]

let waypoint content : Yaml.value = `O [("waypoint", content)]

let segment waypoints : Yaml.value = `O [("segment", `A waypoints)]

let final stmt1 stmt2 : Yaml.value list =
  [
        waypoint @@ final_waypoint 1 stmt1;
        waypoint @@ final_waypoint 2 stmt2;
  ]

let yaml_race race : Yaml.value list =
  let t1, t2 = Race.get_threads race in
  let stmt1, stmt2 = Race.get_stmts race in
  [
    segment [waypoint @@ thread_entry t1];
    segment [waypoint @@ thread_entry t2];
    segment @@ final stmt1 stmt2;
  ]

let witness ~uuid ~time race metadata : Yaml.value = `A [ `O [
  ("entry_type",  `String "violation_sequence");
  ("metadata",    `O (yaml_metadata metadata uuid time));
  ("content",     `A (yaml_race race));
]]

let mk_yaml race =
  let uuid = Uuidm.to_string @@ Uuidm.v4_gen (Random.State.make_self_init ()) () in
  let t = Unix.localtime @@ Unix.time () in
  let metadata = WitnessUtils.metadata () in
  let time =
    Format.sprintf "%04u-%02u-%02uT%02u:%02u:%02u"
      (1900 + t.tm_year) (1 + t.tm_mon) t.tm_mday t.tm_hour t.tm_min t.tm_sec
  in
  witness ~uuid ~time race metadata

let dump_trace race filepath =
  try
    let file = Format.asprintf "%a" Frama_c_kernel.Filepath.pretty_abs filepath in
    let channel = open_out_gen [Open_creat; Open_trunc; Open_wronly] 0o666 file in
    let yaml = mk_yaml race in
    Out_channel.output_string channel (Yaml.to_string_exn yaml);
    close_out channel
  with _ -> ()
