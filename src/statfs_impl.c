#include <sys/vfs.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

#define CAML_NAME_SPACE
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/fail.h>

CAMLprim value statfs_prim(value path)
{
    CAMLparam1(path);

    const char* p = String_val(path);
    struct statfs s;
    int r = statfs(p, &s);
    if(r == -1) {
        char buf[1024];
        snprintf(buf, sizeof(buf), "statfs(%s): %s", p, strerror(errno));
        caml_failwith(buf);
    }

    value v = caml_alloc_tuple(3);
    Store_field(v, 0, Val_int(s.f_bsize));
    Store_field(v, 1, caml_copy_int64(s.f_blocks));
    Store_field(v, 2, caml_copy_int64(s.f_bavail));
    CAMLreturn(v);
}
