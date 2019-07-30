open Unix
open Printf

let string_of_sockaddr = function
| ADDR_INET (a, 0) -> sprintf "%s" (string_of_inet_addr a)
| ADDR_INET (a, p) -> sprintf "%s:%d" (string_of_inet_addr a) p
| _ -> failwith "unexpected address format"

let s = socket PF_INET SOCK_RAW 1
let buf = Bytes.create 576
let (l, a) = recvfrom s buf 0 (Bytes.length buf) []

let () = printf "received %d bytes from %s\n" l (string_of_sockaddr a)
