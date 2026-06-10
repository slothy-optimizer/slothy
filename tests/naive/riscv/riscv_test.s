//LMUL=1:   vadd,vadd,vadd,vadd:
//    EX1: a1 a2 a3 a4
//    EX2: a1 a2 a3 a4

//vadd.vv latency = 4
start_label:
    vsetivli a7, 4, e16, m1, tu, mu
    vadd.vv  v8, v4, v0
    vadd.vv  v16, v8, v26
    vadd.vv  v20, v16, v24
    vadd.vv v21, v20, v25
end_label:

//LMUL=1:   vadd,vadd,vadd,vadd:
//    EX1: a1 a2 a3 a4
//    EX2: a1 a2 a3 a4

//vadd.vv latency = 4
start_label0:
    vsetivli a7, 4, e16, m1, tu, mu
    vadd.vv  v8, v4, v0
    vadd.vv  v16, v15, v26
    vadd.vv  v20, v17, v24
    vadd.vv v21, v22, v25
end_label0:


//LMUL=1:   vsll,vadd,vsll,vadd:
//    EX1: s1 s1 s2 s2
//    EX2:    a1 a1 a2 a2

start_label1:
    vsetivli a7, 4, e16, m1, tu, mu
    vsll.vv  v8, v4, v0
    vadd.vv  v16, v10, v26
    vsll.vv  v20, v22, v24
    vadd.vv v21, v23, v25
end_label1:

//LMUL=1:   vsll,vsll,vsll,vsll:
//     EX1:  s1 s1 s2 s2 s3 s3 s4 s4
//     EX2:

start_label2:
    vsetivli a7, 4, e16, m1, tu, mu
    vsll.vv  v8, v4, v0
    vsll.vv  v16, v10, v26
    vsll.vv  v20, v22, v24
    vsll.vv v21, v23, v25
end_label2: