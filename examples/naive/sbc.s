/* 0 */
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q0, q4, q5           
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q1, q4, q5           

/* 1 */
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q4, q4, q5           
vadd.i32    q0, q0, q4           
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q4, q4, q5           
vadd.i32    q1, q1, q4           

/* 2 */
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q4, q4, q5           
vadd.i32    q0, q0, q4           
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q4, q4, q5           
vadd.i32    q1, q1, q4           

/* 3 */
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q4, q4, q5           
vadd.i32    q0, q0, q4           
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q4, q4, q5           
vadd.i32    q1, q1, q4           

/* 4 */
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q4, q4, q5           
vadd.i32    q0, q0, q4           
vldrh.u16   q2, [in], #16     
vldrh.u16   q3, [cst], #16    
vmullb.s16  q4, q2, q3           
vmullt.s16  q5, q2, q3           
vadd.i32    q4, q4, q5           
vadd.i32    q1, q1, q4           


mvn         r12, #15             
vrshl.s32   q0, r12              
vrshl.s32   q1, r12              

/* pack pairs of 2 consecutives accumulator elements */
/* to be duplicated in 16-bit vector for the cos transform */

//vmov        r3, r0, d0           
//vmov        r4, r5, d1           
//vmov        r6, r7, d2           
//vmov        r8, r9, d3           

vmov        r3, r0, q0[2], q0[0]
vmov        r4, r5, q0[3], q0[1]
vmov        r6, r7, q1[2], q1[0]
vmov        r8, r9, q1[3], q1[1]    


pkhbt       r0, r3, r0, lsl #16  
vdup.32     q2, r0               
pkhbt       r4, r4, r5, lsl #16  
vdup.32     q3, r4               

/* 0 */
vldrh.u16   q4, [cst], #16    
vmullb.s16  q5, q2, q4           
vmullt.s16  q6, q2, q4           
vadd.i32    q0, q5, q6           
vldrh.u16   q4, [cst], #16    
vmullb.s16  q5, q2, q4           
vmullt.s16  q6, q2, q4           
vadd.i32    q1, q5, q6           

/* 1 */
vldrh.u16  q4, [cst], #16    
vmullb.s16  q5, q3, q4           
vmullt.s16  q6, q3, q4           
vadd.i32    q5, q5, q6           
vadd.i32    q0, q0, q5           
vldrh.u16   q4, [cst], #16    
vmullb.s16  q5, q3, q4           
vmullt.s16  q6, q3, q4           
vadd.i32    q5, q5, q6           
vadd.i32    q1, q1, q5           


pkhbt       r6, r6, r7, lsl #16 
vdup.32     q2, r6              
pkhbt       r8, r8, r9, lsl #16 
vdup.32     q3, r8              

/* 2 */
vldrh.u16  q4, [cst], #16    
vmullb.s16  q5, q2, q4          
vmullt.s16  q6, q2, q4          
vadd.i32    q5, q5, q6          
vadd.i32    q0, q0, q5          
vldrh.u16   q4, [cst], #16   
vmullb.s16  q5, q2, q4          
vmullt.s16  q6, q2, q4          
vadd.i32    q5, q5, q6          
vadd.i32    q1, q1, q5          

/* 3 */
vldrh.u16  q4, [cst], #16    
vmullb.s16  q5, q3, q4          
vmullt.s16  q6, q3, q4          
vadd.i32    q5, q5, q6          
vadd.i32    q0, q0, q5          
vldrh.u16   q4, [cst], #16   
vmullb.s16  q5, q3, q4          
vmullt.s16  q6, q3, q4          
vadd.i32    q5, q5, q6          
vadd.i32    q1, q1, q5          

/* final store */
vstrw.32    q0, [out]        
vstrw.32    q1, [out, #16]   