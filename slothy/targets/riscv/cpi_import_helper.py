import pandas as pd
import os


script_dir = os.path.dirname(os.path.abspath(__file__))
ods_path = os.path.join(script_dir, "riscv_v_instr_benchmarks.ods")
table = pd.read_excel(ods_path, sheet_name="vl=VMAX tu mu", engine="odf")
two_units = {}
one_unit = {}
uncategorized = {}
missing = []

actual_instr = [
    "vle",
    "vlse",
    "vluxei",
    "vloxei",
    "vse",
    "vsse",
    "vsuxei",
    "vsoxei",
    "vadd.vv",
    "vsub.vv",
    "vrsub.vv",
    "vand.vv",
    "vor.vv",
    "vxor.vv",
    "vsll.vv",
    "vsrl.vv",
    "vmseq.vv",
    "vmsne.vv",
    "vmsltu.vv",
    "vmslt.vv",
    "vmsleu.vv",
    "vmsle.vv",
    "vminu.vv",
    "vmin.vv",
    "vmaxu.vv",
    "vmax.vv",
    "vmul.vv",
    "vmulh.vv",
    "vmulhu.vv",
    "vmulhsu.vv",
    "vdivu.vv",
    "vdiv.vv",
    "vremu.vv",
    "vrem.vv",
    "vmacc.vv",
    "vnmsac.vv",
    "vmadd.vv",
    "vnmsub.vv",
    "vadd.vx",
    "vsub.vx",
    "vrsub.vx",
    "vand.vx",
    "vor.vx",
    "vxor.vx",
    "vsll.vx",
    "vsrl.vx",
    "vmseq.vx",
    "vmsne.vx",
    "vmsltu.vx",
    "vmslt.vx",
    "vmsleu.vx",
    "vmsle.vx",
    "vmsgtu.vx",
    "vmsgt.vx",
    "vmsgeu.vx",
    "vmsge.vx",
    "vminu.vx",
    "vmin.vx",
    "vmaxu.vx",
    "vmax.vx",
    "vmul.vx",
    "vmulh.vx",
    "vmulhu.vx",
    "vmulhsu.vx",
    "vdivu.vx",
    "vdiv.vx",
    "vremu.vx",
    "vrem.vx",
    "vmacc.vx",
    "vnmsac.vx",
    "vmadd.vx",
    "vnmsub.vx",
    "vadd.vi",
    "vrsub.vi",
    "vand.vi",
    "vor.vi",
    "vxor.vi",
    "vsll.vi",
    "vsrl.vi",
    "vsra.vi",
    "vmseq.vi",
    "vmsne.vi",
    "vmsleu.vi",
    "vmsle.vi",
    "vmsgtu.vi",
    "vmsgt.vi",
    "vmerge.vvm",
    "vmerge.vxm",
    "vmerge.vim",
    "vrgather.vv",
    "vrgatherei16.vv",
    "vrgather.vx",
    "vrgather.vi",
    "vsetvli",
    "vsetivli",
    "vsetvl",
]

# Loop over all instructions
for act in actual_instr:
    found = False
    for row in table.itertuples(index=False):
        instr_str = getattr(row, "instruction")
        if "v0.t" in instr_str:
            continue  # skip masked instructions

        instr_base = instr_str.split()[0]
        if act == instr_base:
            found = True
            e8m1 = int(getattr(row, "e8m1"))
            e8m2 = int(getattr(row, "e8m2"))
            e32m1 = int(getattr(row, "e32m1"))

            if e8m1 == 1 and e8m2 == 2:
                two_units[act] = str(e32m1)
            elif e8m1 == 2 and e8m2 == 4:
                one_unit[act] = str(e32m1)
            else:
                uncategorized[act] = str(e32m1)
            break  # stop scanning table once matched
    if not found:
        missing.append(act)
print("One unit:")
print(one_unit)
print("Two Units")
print(two_units)
print("uncategorized")
print(uncategorized)
print("missing")
print(missing)
