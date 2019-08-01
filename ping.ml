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
let seq = ref 0
let next_seq () = let s = !seq in incr seq; s

let max_len = 576

let t =
  let%lwt he = gethostbyname target in
  match Array.length he.h_addr_list with
  | 0 -> fail_with (sprintf "no such host %s" target)
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

let ping_req payload =
  let open Bytes in
  let l = 8 + length payload in
  if l > max_len then fail_invalid_arg "payload too big"
  else let msg = create l in
  set_uint8 msg 0 8; (* type *)
  set_uint8 msg 1 0; (* code *)
  set_uint16_ne msg 2 0; (* checksum *)
  set_uint16_ne msg 4 identifier; (* identifier *)
  set_uint16_ne msg 6 @@ next_seq (); (* sequence *)
  blit payload 0 msg 8 @@ length payload;
  set_uint16_ne msg 2 (checksum_1071 msg |> lnot);
  return msg

let s = socket PF_INET SOCK_RAW 1

let send t =
  let%lwt req = ping_req (Bytes.of_string "hello") in
  let%lwt sent = sendto s req 0 (Bytes.length req) [] t in
  if sent <> (Bytes.length req)
  then fail_with "unable to send whole ping request"
  else return ()

let recv () =
  let rec go () =
    let open Bytes in
    let msg = create max_len in
    let%lwt (l, a) = recvfrom s msg 0 (length msg) [] in
    let off = 4 * (get_uint8 msg 0 land 0x0f) in
    let id = get_uint16_ne msg (off + 4) in
    if id <> identifier then go () else
      let seq = get_uint16_ne msg (off + 6) in
      printf "received %d bytes (seq %d) from %s\n"
        (l - off) seq (string_of_sockaddr a);
      return ()
  in with_timeout 1.0 go

let () = Lwt_main.run (t >>= send <&> recv ())
