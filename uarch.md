# Examination of the C908 uArch Model

## Arithmetic & Logic Instructions

- According to (Ji-Peng)[https://github.com/Ji-Peng/PQRV/tree/ches2025/cpi]: latency =1, CPI = 0,5 (dual issue) -> ITP = 1
- TODO: Check whether all instructions are mapped to the correct instruction type

##  Load Instructions (lh/ lw/ ld)

- lw instruction supports forwarding. The latency with forwarding is 2 cycles, without 3 cycles
- lh is a special case that cannot benefit from the forwarding since it zero extension takes one more cycle
- All other instruction are supposed to benefit from the forwarding too (?)

## Store Instructions (sh/sw/sd)

- latency = 1, cpi = 1 -> ITP = 1

## Multiply Instructions (mul/mulw/mulh)

- mulw: latency = 3, CPI = 1
- mul: latency = 4, CPI = 2
- mulh: latency = 4, CPI = 2


## Instruction count NTT

Preambel: 1+14+11
loop 1 preambel: 115
loop 1: 232*14 -> expected IPC: 1.53 (slothy only counts 231 instr.)
loop 1 postambel: 116

loop 2 preambel: 121
loop 2: 15*242 -> expected IPC: 1.64 (slothy only counts 241 instr.)
loop 2 postambel: 120+16

= 7392 instructions
Real IPC = 7392/ 6400 = 1.16

Expected IPC average (loops only): 
    total loop instr = 3234 + 3615 = 6849
    loop 1: 3242/ 6849 = 0.47
    loop 2: 3615/ 6849 = 0.53
    
    Expected IPC average = 0.47*1.53 + 0.53 * 1.64 = 1.59

Expected IPC average (total):
    115+116+121+136 = 488 instr left (not included in IPC calculation)
    Estimated IPC: 1.6 - 1.8
    488/7392 * 1.8 + 6904/ 7392 * 1.59 = 1.60

## Instruction count Poly Basemul

1 + 14 + 1 + 1 + 32 * 52 + 14 + 1 + 1 = 1697 instructions
IPC = 1697/ 1149 = 1.48

## Comparison NTT optimized vs Poly Basemul optimized

add rd, x1, x2 (dest, src, src)

### Poly Basemul

- mainly lw/ld, sd, mul, add
### NTT

- mainly ld, sw, add/sub, addi/ srai, mul/ mulh

## Observations

- The load/ use latency difference between lh and ld/ lw is not relevant, since lh is not used anywhere
- 