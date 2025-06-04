            // Excerpt of CRT interpolation from paper https://eprint.iacr.org/2022/439 -- naively written
            vldrw.u32   in0, [src0]
            vqdmulh.s32 diff, in0, mod_p_tw
            vqrdmulh.s32 tmp, diff, const_prshift
            vmla.s32    in0, tmp, mod_p
            vldrw.u32   in1, [src1]
            vsub.u32    diff, in1, in0
            vqdmulh.s32 tmp, diff, p_inv_mod_q_tw
            vmul.u32    diff, diff, p_inv_mod_q
            vrshr.s32   tmp, tmp, #(SHIFT)
            vmla.s32    diff, tmp, mod_q_neg
            vmul.u32    quot_low,  diff, mod_p
            vqdmulh.s32 tmp, diff, mod_p
            vshr.u32    q<tmpp>, q<quot_low>,  #22
            vmul.u32    tmp, tmp, const_shift9
            vand.u32    quot_low,  quot_low, qmask
            vorr.u32    tmpp, tmpp, tmp
            vshlc       tmpp, rcarry, #32
            vadd.u32    in0, in0, tmpp
            vadd.u32    tmpp, quot_low, in0
            vand.u32 red_tmp, tmpp, qmask
            vshlc tmpp, rcarry_red, #32
            vqdmlah.s32 red_tmp, tmpp, const_rshift22
            vstrw.u32   red_tmp, [dst]
