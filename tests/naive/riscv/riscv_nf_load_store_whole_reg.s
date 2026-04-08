start:
vl1r.v     v8, (x1)
vadd.vv v31, v8, v9
vl2r.v     v8, (x2)
vadd.vv v31, v8, v31
vl4re32.v  v8, (x3)
vadd.vv v31, v9, v31
vl8r.v     v16, (x4)

vs1r.v     v24, (x5)
vs2r.v     v26, (x6)
vs4re32.v  v28, (x7)
vs8r.v     v0, (x8)
end: