# Copyright (c) 2021 Arm Limited
# Copyright (c) 2022 Hanno Becker
# Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
# SPDX-License-Identifier: MIT

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

"""Helper script for the generation of twiddle factors for various NTTs"""

import math


class NttRootGenInvalidParameters(Exception):
    """Invalid parameters for NTT root generation"""


class NttRootGen:
    """Helper class for the generation of NTT twiddle factors"""

    def __init__(
        self,
        *,
        size,
        modulus,
        root,
        layers,
        print_label=False,
        pad=None,
        bitsize=16,
        inverse=False,
        vector_length=128,
        word_offset_mod_4=None,
        incomplete_root=True,
        widen_single_twiddles_to_words=True,
        block_strided_twiddles=True,
        negacyclic=True,
        iters=None,
    ):
        if pad is None:
            pad = []

        if bitsize not in [16, 32]:
            raise NttRootGenInvalidParameters("Invalid bit width")

        self.pad = pad
        self.print_label = print_label
        self.word_offset_mod_4 = word_offset_mod_4

        self.negacyclic = negacyclic
        self.bitsize = bitsize
        self.vector_length = vector_length

        self.widen_single_twiddles_to_words = widen_single_twiddles_to_words
        self.block_strided_twiddles = block_strided_twiddles
        self.elements_per_vector = self.vector_length // self.bitsize

        self.modulus = modulus
        self.root = root
        self.size = size

        self.incomplete_root = incomplete_root

        self.inverse = inverse
        self.inverse_scaling = 0  # 32

        if not self.inverse:
            self.roots_array_name = "roots"
        else:
            self.roots_array_name = "roots_inv"

        #
        # Parameter sanity checks
        #

        # Need an odd prime modulus
        if self.modulus % 2 == 0:
            raise NttRootGenInvalidParameters("Modulus must be odd")
        self._inv_mod = pow(self.modulus, -1, 2**self.bitsize)

        # Check that we've indeed been given a root of unity of the correct order
        if self.negacyclic:
            self.root_order = 2 * size
        else:
            self.root_order = size

        self.log2size = int(math.log(size, 2))
        if size != pow(2, self.log2size):
            raise NttRootGenInvalidParameters(f"Size {size} not a power of 2")

        self.layers = layers
        self.incompleteness_factor = 2 ** (self.log2size - self.layers)

        if iters is None:
            if self.layers % 2 == 0:
                self.iters = [(x, 2) for x in range(0, self.layers, 2)]
            else:
                self.iters = [(0, 1)] + [(x, 2) for x in range(1, self.layers, 2)]
        else:
            self.iters = iters

        real_root_order = self.root_order
        if self.incomplete_root:
            real_root_order = real_root_order // self.incompleteness_factor

        if (
            pow(root, real_root_order, modulus) != 1
            or pow(root, real_root_order // 2, modulus) == 1
        ):
            raise NttRootGenInvalidParameters(
                f"{root} is not a primitive {real_root_order}-th "
                f"root of unity modulo {modulus}"
            )

        self.radixes = [2] * self.log2size

    def get_root_pow(self, exp):
        """Returns specific power of base root of unity"""

        if not exp % self.incompleteness_factor == 0:
            raise NttRootGenInvalidParameters(
                f"Invalid exponent {exp} for incompleteness "
                f"factor {self.incompleteness_factor}"
            )
        if self.incomplete_root:
            exp = exp // self.incompleteness_factor
        return pow(self.root, exp, self.modulus)

    def _prepare_root(self, root):

        # Force _signed_ representation of root?
        if root > self.modulus // 2:
            root -= self.modulus

        def round_to_even(x):
            rx = round(x)
            if rx % 2 == 0:
                return rx
            if rx <= x:
                return rx + 1
            return rx - 1

        quot = (root * 2**self.bitsize) / self.modulus
        root_twisted = round_to_even(quot) // 2
        return root, root_twisted

    def _bitrev_list(self, num, radix_list):
        result = 0
        for r in radix_list:
            result = r * result + (num % r)
            num = num // r
        return result

    def root_of_unity_for_block(self, layer, block):
        """Returns the twiddle factor to be used for a specific layer and block"""

        actual_layer = layer
        if self.negacyclic:
            block += pow(2, layer)
            actual_layer += 1
        radixes_so_far = self.radixes[:actual_layer]
        radixes_remaining = self.radixes[actual_layer:]
        size_remaining = 1
        for r in radixes_remaining:
            size_remaining *= r
        log = size_remaining * self._bitrev_list(block, radixes_so_far)
        # For the inverse NTT, we need the inverse twiddle factors
        if self.inverse:
            log = (self.root_order - log) % self.root_order
        root = self.get_root_pow(log)
        root, root_twisted = self._prepare_root(root)
        return root, root_twisted

    def _roots_of_unity_for_layer_core(self, layer, merged):

        if merged not in [1, 2, 3, 4]:
            raise NttRootGenInvalidParameters("Invalid layer merge")

        for cur_block in range(0, 2**layer):
            if merged == 1:
                root, root_twisted = self.root_of_unity_for_block(layer, cur_block)
                yield ([root], [root_twisted])
            elif merged == 2:
                # Compute the roots of unity that we need at this stage
                fst_layer = layer + 0
                snd_layer = layer + 1
                root0, root0_twisted = self.root_of_unity_for_block(
                    fst_layer, cur_block
                )
                root1, root1_twisted = self.root_of_unity_for_block(
                    snd_layer, 2 * cur_block + 0
                )
                root2, root2_twisted = self.root_of_unity_for_block(
                    snd_layer, 2 * cur_block + 1
                )

                if layer in self.pad:
                    yield (
                        [root0, root1, root2, 0],
                        [root0_twisted, root1_twisted, root2_twisted, 0],
                    )
                else:
                    yield (
                        [root0, root1, root2],
                        [root0_twisted, root1_twisted, root2_twisted],
                    )

            elif merged == 3:
                # Compute the roots of unity that we need at this stage
                fst_layer = layer + 0
                snd_layer = layer + 1
                thr_layer = layer + 2
                root0, root0_tw = self.root_of_unity_for_block(fst_layer, cur_block)
                root1, root1_tw = self.root_of_unity_for_block(
                    snd_layer, 2 * cur_block + 0
                )
                root2, root2_tw = self.root_of_unity_for_block(
                    snd_layer, 2 * cur_block + 1
                )
                root3, root3_tw = self.root_of_unity_for_block(
                    thr_layer, 4 * cur_block + 0
                )
                root4, root4_tw = self.root_of_unity_for_block(
                    thr_layer, 4 * cur_block + 1
                )
                root5, root5_tw = self.root_of_unity_for_block(
                    thr_layer, 4 * cur_block + 2
                )
                root6, root6_tw = self.root_of_unity_for_block(
                    thr_layer, 4 * cur_block + 3
                )

                if layer in self.pad:
                    yield (
                        [root0, root1, root2, root3, root4, root5, root6, 0],
                        [
                            root0_tw,
                            root1_tw,
                            root2_tw,
                            root3_tw,
                            root4_tw,
                            root5_tw,
                            root6_tw,
                            0,
                        ],
                    )
                else:
                    yield (
                        [root0, root1, root2, root3, root4, root5, root6],
                        [
                            root0_tw,
                            root1_tw,
                            root2_tw,
                            root3_tw,
                            root4_tw,
                            root5_tw,
                            root6_tw,
                        ],
                    )
            else:
                assert merged == 4
                # Compute the roots of unity that we need at this stage
                fst_layer = layer + 0
                snd_layer = layer + 1
                thr_layer = layer + 2
                fth_layer = layer + 3
                root0, root0_tw = self.root_of_unity_for_block(fst_layer, cur_block)
                root1, root1_tw = self.root_of_unity_for_block(
                    snd_layer, 2 * cur_block + 0
                )
                root2, root2_tw = self.root_of_unity_for_block(
                    snd_layer, 2 * cur_block + 1
                )
                root3, root3_tw = self.root_of_unity_for_block(
                    thr_layer, 4 * cur_block + 0
                )
                root4, root4_tw = self.root_of_unity_for_block(
                    thr_layer, 4 * cur_block + 1
                )
                root5, root5_tw = self.root_of_unity_for_block(
                    thr_layer, 4 * cur_block + 2
                )
                root6, root6_tw = self.root_of_unity_for_block(
                    thr_layer, 4 * cur_block + 3
                )
                root7, root7_tw = self.root_of_unity_for_block(
                    fth_layer, 8 * cur_block + 0
                )
                root8, root8_tw = self.root_of_unity_for_block(
                    fth_layer, 8 * cur_block + 1
                )
                root9, root9_tw = self.root_of_unity_for_block(
                    fth_layer, 8 * cur_block + 2
                )
                root10, root10_tw = self.root_of_unity_for_block(
                    fth_layer, 8 * cur_block + 3
                )
                root11, root11_tw = self.root_of_unity_for_block(
                    fth_layer, 8 * cur_block + 4
                )
                root12, root12_tw = self.root_of_unity_for_block(
                    fth_layer, 8 * cur_block + 5
                )
                root13, root13_tw = self.root_of_unity_for_block(
                    fth_layer, 8 * cur_block + 6
                )
                root14, root14_tw = self.root_of_unity_for_block(
                    fth_layer, 8 * cur_block + 7
                )

                if layer in self.pad:
                    yield (
                        [
                            root0,
                            root1,
                            root2,
                            root3,
                            root4,
                            root5,
                            root6,
                            root7,
                            root8,
                            root9,
                            root10,
                            root11,
                            root12,
                            root13,
                            root14,
                            0,
                        ],
                        [
                            root0_tw,
                            root1_tw,
                            root2_tw,
                            root3_tw,
                            root4_tw,
                            root5_tw,
                            root6_tw,
                            root7_tw,
                            root8_tw,
                            root9_tw,
                            root10_tw,
                            root11_tw,
                            root12_tw,
                            root13_tw,
                            root14_tw,
                            0,
                        ],
                    )
                else:
                    yield (
                        [
                            root0,
                            root1,
                            root2,
                            root3,
                            root4,
                            root5,
                            root6,
                            root7,
                            root8,
                            root9,
                            root10,
                            root11,
                            root12,
                            root13,
                            root14,
                        ],
                        [
                            root0_tw,
                            root1_tw,
                            root2_tw,
                            root3_tw,
                            root4_tw,
                            root5_tw,
                            root6_tw,
                            root7_tw,
                            root8_tw,
                            root9_tw,
                            root10_tw,
                            root11_tw,
                            root12_tw,
                            root13_tw,
                            root14_tw,
                        ],
                    )

    def roots_of_unity_for_layer(self, layer, merged):
        """Generator yielding the twiddle factors for a number of merged layers"""

        num_blocks = 2**layer
        block_size = self.size // num_blocks
        butterfly_size = block_size // 2**merged

        stride = 1
        if butterfly_size < self.vector_length // self.bitsize:
            stride = (self.vector_length // self.bitsize) // butterfly_size

        all_root_pairs = list(self._roots_of_unity_for_layer_core(layer, merged))
        all_roots = [x[0] for x in all_root_pairs]
        all_roots_twisted = [x[1] for x in all_root_pairs]
        num_pairs = len(all_root_pairs)
        assert num_pairs % stride == 0

        for i in range(0, num_pairs, stride):
            root_chunk = list(zip(*all_roots[i : i + stride]))
            root_twisted_chunk = list(zip(*all_roots_twisted[i : i + stride]))
            root_chunk = [list(x) for x in root_chunk]
            root_twisted_chunk = [list(x) for x in root_twisted_chunk]
            roots = zip(root_chunk, root_twisted_chunk)
            res = [(z, stride) for x in roots for y in x for z in y]
            yield from res

    def get_roots_of_unity(self):
        """Yields roots of unity for NTT"""
        iters = self.iters.copy()
        if self.inverse:
            iters.reverse()
        for cur_iter, merged in iters:
            if self.print_label:
                yield (
                    f"roots_l"
                    f"{''.join([str(i) for i in range(cur_iter,cur_iter+merged)])}:"
                )
            yield from self.roots_of_unity_for_layer(cur_iter, merged)

    def _get_roots_of_unity_asm(self):
        """Yields roots of unity"""
        if self.bitsize == 16:
            twiddlesize = "short"
        else:
            assert self.bitsize == 32
            twiddlesize = "word"

        count = 0
        last_stride = None
        for x in self.get_roots_of_unity():
            if isinstance(x, str):
                yield x
                continue
            twiddle, stride = x
            if stride == 1:
                if self.widen_single_twiddles_to_words:
                    yield f".word {twiddle}"
                else:
                    yield f".{twiddlesize} {twiddle}"
                count += 1
            if stride > 1:
                if last_stride == 1:
                    if self.word_offset_mod_4 is not None:
                        yield f"// Word count until here: {count}"
                        cc4 = count % 4
                        diff = self.word_offset_mod_4 - cc4
                        if diff < 0:
                            diff += 4
                        if diff != 0:
                            yield "// Padding"
                            yield from [".word 0"] * diff
                if self.block_strided_twiddles:
                    yield from [f".{twiddlesize} {twiddle}"] * (
                        self.elements_per_vector // stride
                    )
                    count += self.elements_per_vector // stride
                else:
                    yield f".{twiddlesize} {twiddle}"
                    count += 1
            last_stride = stride

    def export(self, filename):
        """Export twiddle factors as file"""

        license_text = """
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

"""
        with open(filename, "w", encoding="utf-8") as f:
            f.write(license_text)
            f.write("\n".join(self._get_roots_of_unity_asm()))


def _main():

    ntt_kyber_l345 = NttRootGen(
        size=256,
        modulus=3329,
        root=17,
        layers=7,
        iters=[(0, 2), (2, 3), (5, 2)],
        word_offset_mod_4=2,
    )
    ntt_kyber_l345.export("../naive/ntt_kyber_12_345_67_twiddles.s")
    ntt_kyber_l345.export("../opt/ntt_kyber_12_345_67_twiddles.s")

    ntt_kyber_l123 = NttRootGen(
        size=256,
        modulus=3329,
        root=17,
        layers=7,
        iters=[(0, 3), (3, 2), (5, 2)],
        pad=[0, 3],
        print_label=True,
        widen_single_twiddles_to_words=False,
    )
    ntt_kyber_l123.export("../naive/ntt_kyber_123_45_67_twiddles.s")
    ntt_kyber_l123.export("../opt/ntt_kyber_123_45_67_twiddles.s")

    # For intt_kyber_123_4567.s
    intt_kyber_l123 = NttRootGen(
        size=256,
        modulus=3329,
        root=17,
        layers=7,
        iters=[(0, 3), (3, 2), (5, 2)],
        pad=[0, 3],
        print_label=True,
        widen_single_twiddles_to_words=False,
        inverse=True,
    )
    intt_kyber_l123.export("../naive/aarch64/intt_kyber_123_45_67_twiddles.s")
    intt_kyber_l123.export("../opt/aarch64/intt_kyber_123_45_67_twiddles.s")

    ntt_kyber = NttRootGen(size=256, modulus=3329, root=17, layers=7)
    ntt_kyber.export("../naive/ntt_kyber_1_23_45_67_twiddles.s")
    ntt_kyber.export("../opt/ntt_kyber_1_23_45_67_twiddles.s")

    intt_kyber = NttRootGen(size=256, inverse=True, modulus=3329, root=17, layers=7)
    intt_kyber.export("../naive/intt_kyber_1_23_45_67_twiddles.s")
    intt_kyber.export("../opt/intt_kyber_1_23_45_67_twiddles.s")

    ntt_dilithium = NttRootGen(
        size=256, bitsize=32, modulus=8380417, root=1753, layers=8, word_offset_mod_4=2
    )
    ntt_dilithium.export("../naive/ntt_dilithium_12_34_56_78_twiddles.s")
    ntt_dilithium.export("../opt/ntt_dilithium_12_34_56_78_twiddles.s")

    ntt_dilithium_l1234 = NttRootGen(
        size=256,
        bitsize=32,
        modulus=8380417,
        root=1753,
        layers=8,
        iters=[(0, 4), (4, 2), (6, 2)],
        pad=[0],
        print_label=True,
    )
    ntt_dilithium_l1234.export("../naive/aarch64/ntt_dilithium_1234_5678_twiddles.s")
    ntt_dilithium_l1234.export("../opt/aarch64/ntt_dilithium_1234_5678_twiddles.s")

    ntt_dilithium_l123 = NttRootGen(
        size=256,
        bitsize=32,
        modulus=8380417,
        root=1753,
        layers=8,
        iters=[(0, 3), (3, 3), (6, 2)],
    )
    ntt_dilithium_l123.export("../naive/ntt_dilithium_123_456_78_twiddles.s")
    ntt_dilithium_l123.export("../opt/ntt_dilithium_123_456_78_twiddles.s")

    intt_dilithium_l123 = NttRootGen(
        size=256,
        inverse=True,
        bitsize=32,
        modulus=8380417,
        root=1753,
        layers=8,
        print_label=True,
        pad=[0, 3],
        iters=[(0, 3), (3, 3), (6, 2)],
    )
    intt_dilithium_l123.export("../naive/aarch64/intt_dilithium_123_456_78_twiddles.s")
    intt_dilithium_l123.export("../opt/aarch64/intt_dilithium_123_456_78_twiddles.s")

    ntt_dilithium_l123 = NttRootGen(
        size=256,
        bitsize=32,
        modulus=8380417,
        root=1753,
        layers=8,
        print_label=True,
        pad=[0, 3],
        iters=[(0, 3), (3, 3), (6, 2)],
    )
    ntt_dilithium_l123.export("../naive/aarch64/ntt_dilithium_123_456_78_twiddles.s")
    ntt_dilithium_l123.export("../opt/aarch64/ntt_dilithium_123_456_78_twiddles.s")

    intt_dilithium = NttRootGen(
        size=256, inverse=True, bitsize=32, modulus=8380417, root=1753, layers=8
    )
    intt_dilithium.export("../naive/intt_dilithium_twiddles.s")
    intt_dilithium.export("../opt/intt_dilithium_twiddles.s")

    ntt_n256_s32_l6_test = NttRootGen(
        size=256,
        modulus=33556993,
        root=28678040,
        layers=6,
        bitsize=32,
        incomplete_root=False,
    )
    ntt_n256_s32_l6_test.export("../naive/ntt_n256_l6_s32_twiddles.s")
    ntt_n256_s32_l6_test.export("../opt/ntt_n256_l6_s32_twiddles.s")

    intt_n256_s32_l6_test = NttRootGen(
        size=256,
        inverse=True,
        modulus=33556993,
        root=28678040,
        layers=6,
        bitsize=32,
        incomplete_root=False,
    )
    intt_n256_s32_l6_test.export("../naive/intt_n256_l6_s32_twiddles.s")
    intt_n256_s32_l6_test.export("../opt/intt_n256_l6_s32_twiddles.s")

    ntt_n256_s32_l8_test = NttRootGen(
        size=256,
        modulus=33556993,
        root=28678040,
        layers=8,
        bitsize=32,
        incomplete_root=False,
    )
    ntt_n256_s32_l8_test.export("../naive/ntt_n256_l8_s32_twiddles.s")
    ntt_n256_s32_l8_test.export("../opt/ntt_n256_l8_s32_twiddles.s")

    intt_n256_s32_l8_test = NttRootGen(
        size=256,
        inverse=True,
        modulus=33556993,
        root=28678040,
        layers=8,
        bitsize=32,
        incomplete_root=False,
    )
    intt_n256_s32_l8_test.export("../naive/intt_n256_l8_s32_twiddles.s")
    intt_n256_s32_l8_test.export("../opt/intt_n256_l8_s32_twiddles.s")


if __name__ == "__main__":
    _main()
