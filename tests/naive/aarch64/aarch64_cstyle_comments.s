/* Comment before optimization region */
// Another comment before
ldr q0, [x1, #0]  /* This should be preserved */

start:
/* Single line C-style comment */
ldr q1, [x2, #0]  /* inline comment */

/* Multi-line with
   // what looks like a comment
   but should be ignored */
ldr q8, [x0]
ldr q9, [x0, #1*16]
ldr q10, [x0, #2*16]
ldr q11, [x0, #3*16]

mul v24.8h, v9.8h, v0.h[0]  /* first */ /* second */ // third
sqrdmulh v9.8h, v9.8h, v0.h[1]
mls v24.8h, v9.8h, v1.h[0]
sub v9.8h, v8.8h, v24.8h
add v8.8h, v8.8h, v24.8h

/**
 * Javadoc style before stores
 */
str q8, [x0], #4*16
str q9, [x0, #-3*16]  /* store with offset */
str q10, [x0, #-2*16]
str q11, [x0, #-1*16]
end:

/* Comment after optimization region */
// Another comment after
str q0, [x1]  /* This should also be preserved */