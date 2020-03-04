let () = Random.self_init ()

let fresh_identifier () = Random.bits () land 0xffff
let fresh_salt () = Random.bits ()
