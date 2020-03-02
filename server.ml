open Lwt
open Lwt_unix

let sf, lf = let gid = Unix.getuid () in (
    Printf.sprintf "/var/run/user/%d/monitor.sock" gid,
    Printf.sprintf "/var/run/user/%d/monitor.lock" gid
  )

let init =
  let s = socket PF_UNIX SOCK_STREAM 0 in
  let%lwt _ = Lwt_io.printf "server socket: %s\n" sf in
  let%lwt l = openfile lf Unix.(O_WRONLY :: O_CREAT :: []) 0o600 in
  let%lwt _ = lockf l F_TLOCK 0 in
  let%lwt _ = try%lwt unlink sf with
    Unix.Unix_error (ENOENT, _, _) -> return () in
  let%lwt _ = bind s (ADDR_UNIX sf) in
  let _ = listen s 10 in
  return s

let deinit s =
  let%lwt _ = close s in
  let%lwt _ = unlink sf in
  return ()

type state = {
  running: bool;
}

let run o st = function
  "STOP" -> return @@ { st with running = false }
| "PING" ->
    let%lwt () = Lwt_io.write o "PONG\n" in
    return st
| cmd ->
    let%lwt () = Lwt_io.fprintf o "ERR unexpected command: %s\n" cmd in
    let%lwt () = Lwt_io.printf "unexpected command: %s\n" cmd in
    return st

type event = Tick | Req of file_descr

let handle_req st s =
  let i = Lwt_io.of_fd ~mode:Lwt_io.input s in
  let o = Lwt_io.of_fd ~mode:Lwt_io.output s in
  let f l st = if st.running then run o st l else return st in
  Lwt_stream.fold_s f (Lwt_io.read_lines i) st

let handle_tick st =
  let%lwt _ = Lwt_io.printf "tick\n" in
  return st

let handle_event st = function
  Tick -> handle_tick st
| Req s -> handle_req st s

let _ = Lwt_main.run @@
  let%lwt s = init in
  let st = { running = true } in

  let ticks, tick = Lwt_stream.create () in
  let _ = Lwt_engine.on_timer 0.1 true (fun _ -> tick (Some Tick)) in

  let clients = Lwt_stream.from @@ fun () ->
    let%lwt s, _ = accept s in return (Some (Req s)) in

  let events = Lwt_stream.choose [ticks; clients] in
  let rec loop st = if not st.running then return () else
    Lwt_stream.next events >>= handle_event st >>= loop in
  finalize (fun () -> loop st) (fun () -> deinit s)
