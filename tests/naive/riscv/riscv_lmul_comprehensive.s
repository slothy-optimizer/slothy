start:
// Vector-Vector operations
vadd.vv  v8, v4, v12
vsub.vv  v8, v8, v16

// Vector-Scalar operations
vadd.vx  v8, v8, x1
vsub.vx  v8, v8, x2

// Vector-Immediate operations
vadd.vi  v8, v8, 5
vor.vi   v8, v8, 3

// Scalar-Vector operations (extract scalar from vector)
vmv.x.s  x4, v8

// Vector-Scalar operations (splat scalar to vector)
vmv.s.x  v8, x6

// Vector-Vector move operations
vmv.v.v  v16, v8

// Masked operations (mask register v0 not expanded)
vmerge.vvm  v8, v4, v12, v0
vmerge.vxm  v8, v8, x1, v0
vmerge.vim  v8, v8, 7, v0
end: