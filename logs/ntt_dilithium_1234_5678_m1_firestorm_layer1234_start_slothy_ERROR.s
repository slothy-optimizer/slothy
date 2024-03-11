// Config:
//         _locked: True
//         _arch: <module 'slothy.targets.aarch64.aarch64_neon' from '/home/amin/slothy/slothy/targets/aarch64/aarch64_neon.py'>
//         _target: <module 'slothy.targets.aarch64.apple_m1_firestorm_experimental' from '/home/amin/slothy/slothy/targets/aarch64/apple_m1_firestorm_experimental.py'>
//         _sw_pipelining: SoftwarePipelining:
//                 _locked: True
//                 _enabled: True
//                 _unroll: 1
//                 _pre_before_post: False
//                 _allow_pre: True
//                 _allow_post: False
//                 _unknown_iteration_count: False
//                 _minimize_overlapping: False
//                 _optimize_preamble: True
//                 _optimize_postamble: True
//                 _max_overlapping: None
//                 _min_overlapping: None
//                 _halving_heuristic: False
//                 _halving_heuristic_periodic: False
//                 _halving_heuristic_split_only: False
//                 _max_pre: 1.0
//         _constraints: Constraints:
//                 _locked: True
//                 st_ld_hazard: True
//                 st_ld_hazard_ignore_scattergather: False
//                 st_ld_hazard_ignore_stack: False
//                 minimize_st_ld_hazards: False
//                 _max_displacement: 1.0
//                 maximize_register_lifetimes: False
//                 move_stalls_to_top: False
//                 move_stalls_to_bottom: False
//                 minimize_register_usage: None
//                 minimize_use_of_extra_registers: None
//                 allow_extra_registers: {}
//                 _stalls_allowed: 0
//                 _stalls_maximum_attempt: 512
//                 _stalls_minimum_attempt: 0
//                 _stalls_precision: 0
//                 _stalls_timeout_below_precision: None
//                 _stalls_first_attempt: 40
//                 _model_latencies: True
//                 _model_functional_units: True
//                 _allow_reordering: True
//                 _allow_renaming: True
//         _hints: Hints:
//                 _locked: True
//                 _all_core: True
//                 _order_hint_orig_order: False
//                 _rename_hint_orig_rename: False
//                 _ext_bsearch_remember_successes: False
//         _variable_size: False
//         _register_aliases: {'in': 'x0', 'inp': 'x1', 'count': 'x2', 'r_ptr0': 'x3', 'r_ptr1': 'x4', 'xtmp': 'x5', 'data0': 'v8', 'data1': 'v9', 'data2': 'v10', 'data3': 'v11', 'data4': 'v12', 'data5': 'v13', 'data6': 'v14', 'data7': 'v15', 'data8': 'v16', 'data9': 'v17', 'data10': 'v18', 'data11': 'v19', 'data12': 'v20', 'data13': 'v21', 'data14': 'v22', 'data15': 'v23', 'qform_data0': 'q8', 'qform_data1': 'q9', 'qform_data2': 'q10', 'qform_data3': 'q11', 'qform_data4': 'q12', 'qform_data5': 'q13', 'qform_data6': 'q14', 'qform_data7': 'q15', 'qform_data8': 'q16', 'qform_data9': 'q17', 'qform_data10': 'q18', 'qform_data11': 'q19', 'qform_data12': 'q20', 'qform_data13': 'q21', 'qform_data14': 'q22', 'qform_data15': 'q23', 'qform_v0': 'q0', 'qform_v1': 'q1', 'qform_v2': 'q2', 'qform_v3': 'q3', 'qform_v4': 'q4', 'qform_v5': 'q5', 'qform_v6': 'q6', 'qform_v7': 'q7', 'qform_v8': 'q8', 'qform_v9': 'q9', 'qform_v10': 'q10', 'qform_v11': 'q11', 'qform_v12': 'q12', 'qform_v13': 'q13', 'qform_v14': 'q14', 'qform_v15': 'q15', 'qform_v16': 'q16', 'qform_v17': 'q17', 'qform_v18': 'q18', 'qform_v19': 'q19', 'qform_v20': 'q20', 'qform_v21': 'q21', 'qform_v22': 'q22', 'qform_v23': 'q23', 'qform_v24': 'q24', 'qform_v25': 'q25', 'qform_v26': 'q26', 'qform_v27': 'q27', 'qform_v28': 'q28', 'qform_v29': 'q29', 'qform_v30': 'q30', 'qform_v31': 'q31', 'root0': 'v0', 'root1': 'v1', 'root2': 'v2', 'root3': 'v3', 'root4': 'v4', 'root5': 'v5', 'root6': 'v6', 'root7': 'v7', 'qform_root0': 'q0', 'qform_root1': 'q1', 'qform_root2': 'q2', 'qform_root3': 'q3', 'qform_root4': 'q4', 'qform_root5': 'q5', 'qform_root6': 'q6', 'qform_root7': 'q7', 'tmp': 'v24', 't0': 'v25', 't1': 'v26', 't2': 'v27', 't3': 'v28', 'modulus': 'v29'}
//         _outputs: {'v4', 'v3', 'v7', 'v1', 'v29', 'v2', 'v5', 'v0', 'x0', 'v6'}
//         _inputs_are_outputs: True
//         _rename_inputs: {'arch': 'static', 'symbolic': 'any'}
//         _rename_outputs: {'arch': 'static', 'symbolic': 'any'}
//         _locked_registers: []
//         _reserved_regs: ['x0', 'x1', 'x2', 'x3', 'x4', 'x5', 'x30', 'sp', 'x18']
//         _selfcheck: True
//         _allow_useless_instructions: False
//         _split_heuristic: False
//         _split_heuristic_region: [0.0, 1.0]
//         _split_heuristic_chunks: False
//         _split_heuristic_optimize_seam: 0
//         _split_heuristic_bottom_to_top: False
//         _split_heuristic_factor: 2
//         _split_heuristic_abort_cycle_at: None
//         _split_heuristic_stepsize: None
//         _split_heuristic_repeat: 1
//         _split_heuristic_preprocess_naive_interleaving: False
//         _split_heuristic_preprocess_naive_interleaving_by_latency: False
//         _compiler_binary: gcc
//         _keep_tags: True
//         _inherit_macro_comments: False
//         _ignore_tags: False
//         _do_address_fixup: True
//         _with_preprocessor: False
//         _max_solutions: 64
//         _timeout: 10800
//         _retry_timeout: None
//         _ignore_objective: True
//         _objective_precision: 0
//         indentation: 8
//         visualize_reordering: True
//         placeholder_char: .
//         early_char: e
//         late_char: l
//         core_char: *
//         typing_hints: {}
//         solver_random_seed: 42
//         log_dir: logs/
