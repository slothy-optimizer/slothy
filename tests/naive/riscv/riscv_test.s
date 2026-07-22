start_label:
    vsetvli a7, a7, e32, m8, tu, mu
    vle32.v v8,  (a1), v0.t
end_label: