        vadd.u32      a, a, a
        vadd.u32      a, a, a
        vadd.u32      a, a, a
        vadd.u32      b, b, b
        vadd.u32      b, b, b
        vadd.u32      b, b, b

        vqdmlsdh.s32  out, a, b
        vqdmladhx.s32 out, a, b
        vstrw.32      out, [addr]

        vqdmladhx.s32 out, c, d
        vqdmlsdh.s32  out, c, d
        vstrw.32      out, [addr, #16]

        vqdmlsdh.s32  out, e, f
        vqdmladhx.s32 out, e, f
        vstrw.32      out, [addr, #32]
