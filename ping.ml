open Lwt
open Lwt_unix
open Printf

let string_of_sockaddr = function
| ADDR_INET (a, 0) -> sprintf "%s" (Unix.string_of_inet_addr a)
| ADDR_INET (a, p) -> sprintf "%s:%d" (Unix.string_of_inet_addr a) p
| ADDR_UNIX s -> s

let target = "ip.rootmos.io"

let () = Random.self_init ()
let identifier = Random.bits () land 0xffff

let max_len = 576

let resolve t =
  let%lwt he = gethostbyname t in
  match Array.length he.h_addr_list with
  | 0 -> fail_with (sprintf "no such host %s" t)
  | _ -> return @@ ADDR_INET (Array.get he.h_addr_list 0, 0)

let checksum_1071 bs =
  let sum = ref 0 and count = ref @@ Bytes.length bs and off = ref 0 in
  while !count > 1 do
    sum := !sum + Bytes.get_int16_le bs !off;
    count := !count - 2;
    off := !off + 2
  done;
  if !count > 0 then sum := !sum + Bytes.get_uint8 bs !off;
  while !sum lsr 16 > 0 do
    sum := !sum land 0xffff + !sum lsr 16
  done;
  !sum

let ping_req seq payload =
  let open Bytes in
  let l = 8 + length payload in
  if l > max_len then fail_invalid_arg "payload too big"
  else let msg = create l in
  set_uint8 msg 0 8; (* type *)
  set_uint8 msg 1 0; (* code *)
  set_uint16_ne msg 2 0; (* checksum *)
  set_uint16_ne msg 4 identifier; (* identifier *)
  set_uint16_ne msg 6 @@ seq; (* sequence *)
  blit payload 0 msg 8 @@ length payload;
  set_uint16_ne msg 2 (checksum_1071 msg |> lnot);
  return msg

let send s t seq =
  let%lwt req = ping_req seq (Bytes.of_string "hello") in
  let%lwt sent = sendto s req 0 (Bytes.length req) [] t in
  if sent <> (Bytes.length req)
  then fail_with "unable to send whole ping request"
  else return ()

type rsp = {
  seq: int;
  len: int;
  from: sockaddr;
  time: float;
}

let rec recv s () =
  let open Bytes in
  let msg = create max_len in
  let%lwt (l, a) = recvfrom s msg 0 (length msg) [] in
  let off = 4 * (get_uint8 msg 0 land 0x0f) in
  let id = get_uint16_ne msg (off + 4) in
  if id <> identifier then recv s () else
    let seq = get_uint16_ne msg (off + 6) in
    let time = Unix.gettimeofday () in
    return (Some { seq; len = l - off; from = a; time })

type status = {
  seq: int;
  sentat: float;
  respat: float option;
}

type state = {
  s: file_descr;
  t: sockaddr;
  ps: status option Array.t;
  i: int;
}

type stats = {
  sent: int;
  responses: int;
  min: float;
  max: float;
  avg: float;
}

let start () =
  let%lwt t = resolve target in
  let s = socket PF_INET SOCK_RAW 1 in
  let es = Lwt_stream.from (recv s) in
  let ps = Array.make 1000 None in
  return (es, { s; t; ps; i = 0 })

let event st (msg: rsp) =
  let f i = function
      Some p when p.seq = msg.seq ->
        Array.set st.ps i (Some { p with respat = Some msg.time })
    | _ -> () in
  Array.iteri f st.ps;
  return st

let tick st (t: Monitor.tick) =
  let seq = t.seq in
  let%lwt () = send st.s st.t seq in
  Array.set st.ps st.i (Some { seq; sentat = t.time; respat = None });
  return { st with i = (st.i + 1) mod Array.length st.ps }

let stats st =
  let sent = ref 0 in
  let responses = ref 0 in
  let total = ref 0.0 in
  let max = ref nan in
  let min = ref nan in
  let f = function
    None -> ()
  | Some p ->
      sent := !sent + 1;
      match p.respat with
      Some t ->
        responses := !responses + 1;
        let d = t -. p.sentat in
        total := !total +. d;
        if d < !min || !responses = 1 then min := d;
        if d > !max || !responses = 1 then max := d
      | None -> () in
  Array.iter f st.ps;
  {
    sent = !sent;
    responses = !responses;
    avg = !total /. (float_of_int !responses);
    min = !min;
    max = !max;
  }
