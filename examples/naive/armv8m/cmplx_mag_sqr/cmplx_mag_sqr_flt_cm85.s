start:
    // deinterleave real/imag
    vld20.32        {qr, qi}, [in]                            
    vld21.32        {qr, qi}, [in]!                                     
    // square real/imag 
    vmul.f32        qtmp, qr, qr                                              
    vmul.f32        qout, qi, qi     
    // accumulate without VFMA to allow better performance
    vadd.f32        qout, qout, qtmp                                                 
    vstrw.32        q<qout>, [r<out>], #16
    le              lr, start

