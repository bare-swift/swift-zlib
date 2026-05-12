// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// RFC 1950 § 9 ADLER-32 reference implementation.
///
/// The modulus is 65521 (the largest prime < 2^16). Folding after each
/// byte keeps the implementation small; chunked-fold optimization may
/// land later once profiling shows it matters.
enum Adler32 {
    static func compute(_ bytes: ContiguousArray<UInt8>) -> UInt32 {
        let mod: UInt32 = 65521
        var s1: UInt32 = 1
        var s2: UInt32 = 0
        for b in bytes {
            s1 = (s1 + UInt32(b)) % mod
            s2 = (s2 + s1) % mod
        }
        return (s2 << 16) | s1
    }
}
