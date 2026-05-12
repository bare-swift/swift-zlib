// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Deflate

/// Internal driver for zlib encoding. Public entry is ``Zlib/encode(_:level:)``.
enum ZlibEncoder {
    static func encode(_ input: Bytes, level: Deflate.Encoder.Level) -> Bytes {
        var out = ContiguousArray<UInt8>()
        out.reserveCapacity(input.storage.count + 8)

        // RFC 1950 § 2.2 — CMF + FLG.
        // CMF: CM=8 (DEFLATE), CINFO=7 (32 KiB window — log2(32768) - 8 = 7).
        let cmf: UInt8 = 0x78
        // FLG: bits 0..4 = FCHECK, bit 5 = FDICT (0 here), bits 6..7 = FLEVEL.
        // Pick FLEVEL hint that matches the chosen level:
        //   0 = fastest, 1 = fast, 2 = default, 3 = maximum.
        let flevel: UInt8
        switch level {
        case .none, .fast: flevel = 0
        case .default:     flevel = 2
        case .best:        flevel = 3
        }
        // Compute FCHECK so (CMF * 256 + FLG) is divisible by 31.
        var flg: UInt8 = flevel << 6  // FDICT = 0
        let partial = (UInt32(cmf) << 8) | UInt32(flg)
        let remainder = partial % 31
        let fcheck = (31 - remainder) % 31
        flg |= UInt8(fcheck)
        out.append(cmf)
        out.append(flg)

        // DEFLATE body.
        let compressed = Deflate.encode(input, level: level)
        out.append(contentsOf: compressed.storage)

        // ADLER32 over the uncompressed input, big-endian per RFC 1950 § 2.2.
        let adler = Adler32.compute(input.storage)
        out.append(UInt8(truncatingIfNeeded: (adler >> 24) & 0xFF))
        out.append(UInt8(truncatingIfNeeded: (adler >> 16) & 0xFF))
        out.append(UInt8(truncatingIfNeeded: (adler >> 8) & 0xFF))
        out.append(UInt8(truncatingIfNeeded: adler & 0xFF))

        return Bytes(out)
    }
}
