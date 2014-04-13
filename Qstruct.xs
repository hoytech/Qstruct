#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


/* define int64_t and uint64_t when using MinGW compiler */
#ifdef __MINGW32__
#include <stdint.h>
#endif

/* define int64_t and uint64_t when using MS compiler */
#ifdef _MSC_VER
#include <stdlib.h>
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;
#endif

#define MATH_INT64_NATIVE_IF_AVAILABLE
#include "perl_math_int64.h"

#include "qstruct_utils.h"
#include "qstruct_compiler.h"
#include "qstruct_loader.h"
#include "qstruct_builder.h"


typedef struct qstruct_definition * Qstruct_Definitions;
typedef struct qstruct_item * Qstruct_Item;
typedef struct qstruct_builder * Qstruct_Builder;


MODULE = Qstruct         PACKAGE = Qstruct
PROTOTYPES: ENABLE


BOOT:
  PERL_MATH_INT64_LOAD_OR_CROAK;


Qstruct_Definitions
parse_schema(schema_sv)
        SV *schema_sv
    CODE:
        char *schema;
        size_t schema_size;
        struct qstruct_definition *def;
        char err_buf[1024];

        schema_size = SvCUR(schema_sv);
        schema = SvPV(schema_sv, schema_size);

        def = parse_qstructs(schema, schema_size, err_buf, sizeof(err_buf));

        if (!def) croak("Qstruct::parse error: %s", err_buf);

        RETVAL = def;
    OUTPUT:
        RETVAL


MODULE = Qstruct         PACKAGE = Qstruct::Definitions
PROTOTYPES: ENABLE



void
iterate(def, callback)
        Qstruct_Definitions def
        SV *callback
    CODE:
        HV *def_info, *items_iterator;

        for(; def; def = def->next) {
        ENTER;
        SAVETMPS;

        PUSHMARK(SP);

        def_info = (HV *) sv_2mortal ((SV *) newHV ());
        hv_store(def_info, "def_addr", 8, newSViv((size_t)def), 0);
        hv_store(def_info, "name", 4, newSVpvn(def->name, def->name_len), 0);
        hv_store(def_info, "body_size", 9, newSVnv(def->body_size), 0);
        hv_store(def_info, "num_items", 9, newSVnv(def->num_items), 0);
        XPUSHs(newRV((SV*)def_info));

        PUTBACK;

        call_sv(callback, G_SCALAR);

        FREETMPS;
        LEAVE;
        }


SV *
get_item(def_addr, item_index)
        unsigned long def_addr
        unsigned long item_index
    CODE:
        Qstruct_Definitions def = (Qstruct_Definitions) def_addr; // FIXME: must be better way to do this in XS
        HV * rh;
        struct qstruct_item *item = def->items + item_index;

        rh = (HV *) sv_2mortal ((SV *) newHV ());
        hv_store(rh, "name", 4, newSVpvn(item->name, item->name_len), 0);
        hv_store(rh, "type", 4, newSVnv(item->type), 0);
        hv_store(rh, "fixed_array_size", 16, newSVnv(item->fixed_array_size), 0);
        hv_store(rh, "byte_offset", 11, newSVnv(item->byte_offset), 0);
        hv_store(rh, "bit_offset", 10, newSVnv(item->bit_offset), 0);

        RETVAL = newRV((SV *)rh);
    OUTPUT:
        RETVAL



void
DESTROY(def)
        Qstruct_Definitions def
    CODE:
        free_qstruct_definitions(def);




MODULE = Qstruct         PACKAGE = Qstruct::Runtime
PROTOTYPES: ENABLE


int
sanity_check(buf_sv)
        SV *buf_sv
    CODE:
        char *buf;
        size_t buf_size;

        buf_size = SvCUR(buf_sv);
        buf = SvPV(buf_sv, buf_size);

        RETVAL = !qstruct_sanity_check(buf, buf_size);
    OUTPUT:
        RETVAL

uint64_t
get_uint64(buf_sv, byte_offset)
        SV *buf_sv
        size_t byte_offset
    CODE:
        char *buf;
        size_t buf_size;
        uint64_t output;
        int ret;

        buf_size = SvCUR(buf_sv);
        buf = SvPV(buf_sv, buf_size);

        ret = qstruct_get_uint64(buf, buf_size, byte_offset, &output);

        if (ret) croak("malformed qstruct");

        RETVAL = output;
    OUTPUT:
        RETVAL


int
get_bool(buf_sv, byte_offset, bit_offset)
        SV *buf_sv
        size_t byte_offset
        int bit_offset
    CODE:
        char *buf;
        size_t buf_size;
        int output;
        int ret;

        buf_size = SvCUR(buf_sv);
        buf = SvPV(buf_sv, buf_size);

        ret = qstruct_get_bool(buf, buf_size, byte_offset, bit_offset, &output);

        if (ret) croak("malformed qstruct");

        RETVAL = output;
    OUTPUT:
        RETVAL


void
get_string(buf_sv, byte_offset, output_sv)
        SV *buf_sv
        size_t byte_offset
        SV *output_sv
    CODE:
        char *buf, *output;
        size_t buf_size, output_size;
        int ret;

        buf_size = SvCUR(buf_sv);
        buf = SvPV(buf_sv, buf_size);

        ret = qstruct_get_pointer(buf, buf_size, byte_offset, &output, &output_size, 1);

        if (ret == -2) croak("string too large for 32 bit machine");
        if (ret) croak("malformed qstruct");

        SvUPGRADE(output_sv, SVt_PV);

        // Link the reference counts together
        sv_magicext(output_sv, buf_sv, PERL_MAGIC_ext, NULL, NULL, 0);

        SvCUR_set(output_sv, output_size);
        SvPV_set(output_sv, output);
        SvPOK_only(output_sv);

        // Don't try to free this memory: it's owned by buf_sv
        SvLEN_set(output_sv, 0);

        SvREADONLY_on(output_sv);
        SvREADONLY_on(buf_sv);




MODULE = Qstruct         PACKAGE = Qstruct::Builder
PROTOTYPES: ENABLE

Qstruct_Builder
new(package)
        char *package
    CODE:
        RETVAL = qstruct_builder_new();
    OUTPUT:
        RETVAL

void
set_uint64(self, byte_offset, value)
        Qstruct_Builder self
        size_t byte_offset
        uint64_t value
    CODE:
        if (qstruct_builder_set_uint64(self, byte_offset, value)) croak("out of memory");

void
set_bool(self, byte_offset, bit_offset, value)
        Qstruct_Builder self
        size_t byte_offset
        int bit_offset
        int value
    CODE:
        if (qstruct_builder_set_bool(self, byte_offset, bit_offset, value)) croak("out of memory");

void
set_string(self, byte_offset, value_sv)
        Qstruct_Builder self
        size_t byte_offset
        SV *value_sv
    CODE:
        char *value;
        size_t value_size;

        value_size = SvCUR(value_sv);
        value = SvPV(value_sv, value_size);

        if (qstruct_builder_set_string(self, byte_offset, value, value_size)) croak("out of memory");



SV *
render(builder)
        Qstruct_Builder builder
    CODE:
        char *msg;
        size_t msg_size;

        msg_size = qstruct_builder_get_msg_size(builder);

        msg = qstruct_builder_get_buf(builder);

        RETVAL = newSVpvn(msg, msg_size);
    OUTPUT:
        RETVAL
  

void
DESTROY(builder)
        Qstruct_Builder builder
    CODE:
        qstruct_builder_free(builder);
