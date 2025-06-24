start:
    // deinterleave real/imag
    vld20.32        {qr, qi}, [in]                            
    vld21.32        {qr, qi}, [in]!                                     
    // square real/imag / accumulate
    vmul.f32        qout, qr, qr                                              
    vfma.f32        qout, qi, qi                                                 
    vstrw.32        q<qout>, [r<out>], #16
    le              lr, start

