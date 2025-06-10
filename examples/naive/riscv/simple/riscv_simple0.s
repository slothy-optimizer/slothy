start:
vle8.v v0, (x0)
vlse16.v v1, (x0), x1
vluxei32.v v2, (x0), v1
vloxei64.v v3, (x0), v1
vse8.v v4, (x0)
vsse16.v v5, (x0), x1
vsuxei32.v v6, (x0), v1
vsoxei64.v v7, (x0), v1, v0.t
vadd.vv v8, v7, v7
vadd.vx v9, v8, x0
vadd.vi v10, v9, 5
vmerge.vvm v11, v10, v9, v0
li x0, 1000
end: