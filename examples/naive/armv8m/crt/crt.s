            // Excerpt of CRT interpolation from paper https://eprint.iacr.org/2022/439 -- naively written
            vldrw.u32   in0, [src0]
            vqdmulh.s32 q<diff>, q<in0>, r<mod_p_tw>
            vqrdmulh.s32 q<tmp>, q<diff>, r<const_prshift>
            vmla.s32    q<in0>, q<tmp>, r<mod_p>
            vldrw.u32   in1, [src1]
            vsub.u32    diff, in1, in0
            vqdmulh.s32 q<tmp>, q<diff>, r<p_inv_mod_q_tw>
            vmul.u32    q<diff>, q<diff>, r<p_inv_mod_q>
            vrshr.s32   q<tmp>, q<tmp>, #(SHIFT)
            vmla.s32    q<diff>, q<tmp>, r<mod_q_neg>
            vmul.u32    q<quot_low>,  q<diff>, r<mod_p>
            vqdmulh.s32 q<tmp>, q<diff>, r<mod_p>
            vshr.u32    q<tmpp>, q<quot_low>,  #22
            vmul.u32    q<tmp>, q<tmp>, r<const_shift9>
            vand.u32    quot_low,  quot_low, qmask
            vorr.u32    tmpp, tmpp, tmp
            vshlc       q<tmpp>, r<rcarry>, #32
            vadd.u32    q<in0>, q<in0>, q<tmpp>
            vadd.u32    q<tmpp>, q<quot_low>, q<in0>
            vand.u32 red_tmp, tmpp, qmaskw
            vshlc q<tmpp>, r<rcarry_red>, #32
            vqdmlah.s32 q<red_tmp>, q<tmpp>, r<const_rshift22>
            vstrw.u32   red_tmp, [dst]
