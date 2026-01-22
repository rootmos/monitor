open Printf

let () = Random.self_init ()

let fresh_identifier () = Random.bits () land 0x7fff
let fresh_salt () = Random.bits ()

let socket_path () =
  let gid = Unix.getuid () in
  Sys.getenv_opt "MONITOR_SOCKET"
    |> Option.value ~default:"/var/run/user/%u/monitor.sock"
    |> Str.global_replace (Str.regexp "%u") (Int.to_string gid)

let human_size_of_bytes b = let open Int64 in
  let k = div b (of_int 1024) in
  if equal k zero then sprintf "%LdB" b else
  let m = div k (of_int 1024) in
  if equal m zero then sprintf "%LdKB" k else
  let g = div m (of_int 1024) in
  if equal g zero then sprintf "%LdMB" m else
  let t = div g (of_int 1024) in
  if equal t zero then sprintf "%LdGB" g else
  sprintf "%LdTB" t
