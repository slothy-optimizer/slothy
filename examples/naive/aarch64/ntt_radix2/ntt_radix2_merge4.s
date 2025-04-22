///
/// Copyright (c) 2022 Arm Limited
/// Copyright (c) 2022 Hanno Becker
/// Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
/// SPDX-License-Identifier: MIT
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.
///

.macro mulmod dst, src, const, const_twisted, idx
        mul        \dst,  \src, \const[\idx]
        sqrdmulh   \src,  \src, \const_twisted[\idx]
        mla        \dst,  \src, modulus
.endm

.macro ct_butterfly a, b, root, root_twisted, idx
        mulmod tmp, \b, \root, \root_twisted, \idx
        sub    \b,    \a, tmp
        add    \a,    \a, tmp
.endm

start:
        ldr data0,  [in]
        ldr data1,  [in]
        ldr data2,  [in]
        ldr data3,  [in]
        ldr data4,  [in]
        ldr data5,  [in]
        ldr data6,  [in]
        ldr data7,  [in]
        ldr data8,  [in]
        ldr data9,  [in]
        ldr data10, [in]
        ldr data11, [in]
        ldr data12, [in]
        ldr data13, [in]
        ldr data14, [in]
        ldr data15, [in]

        ct_butterfly data0, data8,  root0, root0_twisted, 0
        ct_butterfly data1, data9,  root0, root0_twisted, 0
        ct_butterfly data2, data10, root0, root0_twisted, 0
        ct_butterfly data3, data11, root0, root0_twisted, 0
        ct_butterfly data4, data12, root0, root0_twisted, 0
        ct_butterfly data5, data13, root0, root0_twisted, 0
        ct_butterfly data6, data14, root0, root0_twisted, 0
        ct_butterfly data7, data15, root0, root0_twisted, 0

        ct_butterfly data0,  data4,  root0, root0_twisted, 1
        ct_butterfly data1,  data5,  root0, root0_twisted, 1
        ct_butterfly data2,  data6,  root0, root0_twisted, 1
        ct_butterfly data3,  data7,  root0, root0_twisted, 1
        ct_butterfly data8,  data12, root0, root0_twisted, 2
        ct_butterfly data9,  data13, root0, root0_twisted, 2
        ct_butterfly data10, data14, root0, root0_twisted, 2
        ct_butterfly data11, data15, root0, root0_twisted, 2

        ct_butterfly data0,  data2,  root1, root1_twisted, 0
        ct_butterfly data1,  data3,  root1, root1_twisted, 0
        ct_butterfly data4,  data6,  root1, root1_twisted, 1
        ct_butterfly data5,  data7,  root1, root1_twisted, 1
        ct_butterfly data8,  data10, root1, root1_twisted, 2
        ct_butterfly data9,  data11, root1, root1_twisted, 2
        ct_butterfly data12, data14, root1, root1_twisted, 3
        ct_butterfly data13, data15, root1, root1_twisted, 3

        ct_butterfly data0,  data1,  root2, root2_twisted, 0
        ct_butterfly data2,  data3,  root2, root2_twisted, 1
        ct_butterfly data4,  data5,  root2, root2_twisted, 2
        ct_butterfly data6,  data7,  root2, root2_twisted, 3
        ct_butterfly data8,  data9,  root3, root3_twisted, 0
        ct_butterfly data10, data11, root3, root3_twisted, 1
        ct_butterfly data12, data13, root3, root3_twisted, 2
        ct_butterfly data14, data15, root3, root3_twisted, 3

        str data0,  [in]
        str data1,  [in]
        str data2,  [in]
        str data3,  [in]
        str data4,  [in]
        str data5,  [in]
        str data6,  [in]
        str data7,  [in]
        str data8,  [in]
        str data9,  [in]
        str data10, [in]
        str data11, [in]
        str data12, [in]
        str data13, [in]
        str data14, [in]
        str data15, [in]
end:
