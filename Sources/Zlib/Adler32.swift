// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// RFC 1950 § 9 ADLER-32 reference implementation.
///
/// The modulus is 65521 (the largest prime < 2^16). Folding after each
/// byte keeps the implementation small; chunked-fold optimization may
/// land later once profiling shows it matters.
enum Adler32 {
    static let modulus: UInt32 = 65521

    static func compute(_ bytes: ContiguousArray<UInt8>) -> UInt32 {
        var digest = Digest()
        digest.update(bytes)
        return digest.finalize()
    }

    /// Incremental ADLER-32. Initialize, feed bytes via ``update(_:)`` zero
    /// or more times, then ``finalize()`` to obtain the checksum value.
    struct Digest: Sendable {
        private var s1: UInt32 = 1
        private var s2: UInt32 = 0

        init() {}

        mutating func update(_ bytes: some Sequence<UInt8>) {
            for b in bytes {
                s1 = (s1 + UInt32(b)) % Adler32.modulus
                s2 = (s2 + s1) % Adler32.modulus
            }
        }

        func finalize() -> UInt32 {
            (s2 << 16) | s1
        }
    }
}
