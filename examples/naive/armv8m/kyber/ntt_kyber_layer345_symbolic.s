.macro mulmod dst, src, const, const_twisted
        vmul.s16       \dst,  \src, \const
        vqrdmulh.s16   \src,  \src, \const_twisted
        vmla.s16       \dst,  \src, modulus
.endm

.macro ct_butterfly a, b, root, root_twisted
        mulmod tmp, \b, \root, \root_twisted
        vsub.u16       \b,    \a, tmp
        vadd.u16       \a,    \a, tmp
.endm

.macro load_next_roots r0, r1, r2, r3, r4, r5, r6
        ldrd \r0, \r0\()_tw, [r], #(7*16)
        ldrd \r1, \r1\()_tw, [r, #(-6*16)]
        ldrd \r2, \r2\()_tw, [r, #(-5*16)]
        ldrd \r3, \r3\()_tw, [r, #(-4*16)]
        ldrd \r4, \r4\()_tw, [r, #(-3*16)]
        ldrd \r5, \r5\()_tw, [r, #(-2*16)]
        ldrd \r6, \r6\()_tw, [r, #(-1*16)]
.endm

layer345_loop:
        load_next_roots r0, r1, r2, r3, r4, r5, r6

        vldrw.u32 data0, [in]
        vldrw.u32 data1, [in, #16]
        vldrw.u32 data2, [in, #32]
        vldrw.u32 data3, [in, #48]
        vldrw.u32 data4, [in, #64]
        vldrw.u32 data5, [in, #80]
        vldrw.u32 data6, [in, #96]
        vldrw.u32 data7, [in, #112]

        ct_butterfly data0, data4, r0, r0_tw
        ct_butterfly data1, data5, r0, r0_tw
        ct_butterfly data2, data6, r0, r0_tw
        ct_butterfly data3, data7, r0, r0_tw

        ct_butterfly data0, data2, r1, r1_tw
        ct_butterfly data1, data3, r1, r1_tw
        ct_butterfly data0, data1, r2, r2_tw
        ct_butterfly data2, data3, r3, r3_tw

        ct_butterfly data4, data6, r4, r4_tw
        ct_butterfly data5, data7, r4, r4_tw
        ct_butterfly data4, data5, r5, r5_tw
        ct_butterfly data6, data7, r6, r6_tw

        vstrw.u32 data0, [in]
        vstrw.u32 data1, [in, #16]
        vstrw.u32 data2, [in, #32]
        vstrw.u32 data3, [in, #48]
        vstrw.u32 data4, [in, #64]
        vstrw.u32 data5, [in, #80]
        vstrw.u32 data6, [in, #96]
        vstrw.u32 data7, [in, #112]
        // vst40.u32 {data0, data1, data2, data3}, [in]
        // vst41.u32 {data0, data1, data2, data3}, [in]
        // vst42.u32 {data0, data1, data2, data3}, [in]
        // vst43.u32 {data0, data1, data2, data3}, [in]

        // vst40.u32 {data4, data5, data6, data7}, [in]
        // vst41.u32 {data4, data5, data6, data7}, [in]
        // vst42.u32 {data4, data5, data6, data7}, [in]
        // vst43.u32 {data4, data5, data6, data7}, [in]

        le lr, layer345_loop
