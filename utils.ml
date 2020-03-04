let () = Random.self_init ()

let fresh_identifier () = Random.bits () land 0xffff
let fresh_salt () = Random.bits ()

let socket_path () =
  let gid = Unix.getuid () in
  Sys.getenv_opt "MONITOR_SOCKET"
    |> Option.value ~default:"/var/run/user/%u/monitor.sock"
    |> Str.global_replace (Str.regexp "%u") (Int.to_string gid)
