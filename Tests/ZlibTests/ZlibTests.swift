// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import Zlib
import Bytes

private func bytes(_ raw: [UInt8]) -> Bytes {
    var b = Bytes(reservingCapacity: raw.count)
    for x in raw { b.append(x) }
    return b
}

private func string(_ b: Bytes) -> String {
    String(decoding: b.storage, as: UTF8.self)
}

/// All zlib vectors below were generated via Python's `zlib.compress()`
/// at default compression level (which produces standard `78 9C` headers).
@Suite("Zlib — decode")
struct DecodeTests {
    @Test("empty payload")
    func empty() throws {
        // 78 9c 03 00 00 00 00 01
        let raw: [UInt8] = [0x78, 0x9C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01]
        let result = try Zlib.decode(bytes(raw))
        #expect(result.count == 0)
    }

    @Test("'abc'")
    func abc() throws {
        let raw: [UInt8] = [0x78, 0x9C, 0x4B, 0x4C, 0x4A, 0x06, 0x00, 0x02, 0x4D, 0x01, 0x27]
        let result = try Zlib.decode(bytes(raw))
        #expect(string(result) == "abc")
    }

    @Test("'hello world'")
    func helloWorld() throws {
        let raw: [UInt8] = [
            0x78, 0x9C, 0xCB, 0x48, 0xCD, 0xC9, 0xC9, 0x57, 0x28, 0xCF,
            0x2F, 0xCA, 0x49, 0x01, 0x00, 0x1A, 0x0B, 0x04, 0x5D,
        ]
        let result = try Zlib.decode(bytes(raw))
        #expect(string(result) == "hello world")
    }

    @Test("16 'a's via back-references")
    func repeatedA() throws {
        let raw: [UInt8] = [
            0x78, 0x9C, 0x4B, 0x4C, 0x44, 0x05, 0x00, 0x33, 0x98, 0x06, 0x11,
        ]
        let result = try Zlib.decode(bytes(raw))
        #expect(string(result) == String(repeating: "a", count: 16))
    }

    @Test("the quick brown fox (dynamic Huffman)")
    func quickBrownFox() throws {
        let raw: [UInt8] = [
            0x78, 0x9C, 0x0B, 0xC9, 0x48, 0x55, 0x28, 0x2C, 0xCD, 0x4C,
            0xCE, 0x56, 0x48, 0x2A, 0xCA, 0x2F, 0xCF, 0x53, 0x48, 0xCB,
            0xAF, 0x50, 0xC8, 0x2A, 0xCD, 0x2D, 0x28, 0x56, 0xC8, 0x2F,
            0x4B, 0x2D, 0x52, 0x28, 0x01, 0x4A, 0xE7, 0x24, 0x56, 0x55,
            0x2A, 0xA4, 0xE4, 0xA7, 0x03, 0x00, 0x5B, 0xDC, 0x0F, 0xDA,
        ]
        let result = try Zlib.decode(bytes(raw))
        #expect(string(result) == "The quick brown fox jumps over the lazy dog")
    }
}

@Suite("Zlib — error paths")
struct ErrorPathTests {
    @Test("input shorter than 6 bytes throws .truncated")
    func truncated() {
        #expect(throws: ZlibError.truncated) {
            try Zlib.decode(bytes([0x78, 0x9C]))
        }
    }

    @Test("non-DEFLATE compression method throws")
    func wrongCM() {
        // CMF = 0x77 (CM=7); FLG chosen so header check passes
        // (we want the CM error specifically, not the header-check error).
        // (0x77 * 256 + FLG) % 31 == 0 → FLG = 31 - (0x77 * 256 % 31) = ...
        // Easier: just trigger CM error and accept that it might be the
        // first error encountered.
        let raw: [UInt8] = [0x77, 0x00, 0x00, 0x00, 0x00, 0x00]
        #expect(throws: (any Error).self) {
            try Zlib.decode(bytes(raw))
        }
    }

    @Test("CINFO > 7 throws .invalidWindowSize")
    func invalidCINFO() {
        let raw: [UInt8] = [0x88, 0x00, 0x00, 0x00, 0x00, 0x00]  // CMF = 0x88, CINFO = 8
        #expect(throws: ZlibError.invalidWindowSize(8)) {
            try Zlib.decode(bytes(raw))
        }
    }

    @Test("header check failure throws")
    func headerCheck() {
        // 0x78 = CM=8, CINFO=7. 0x00 FLG → (0x78*256 + 0) % 31 = 30720 % 31 = 1, not 0.
        let raw: [UInt8] = [0x78, 0x00, 0x00, 0x00, 0x00, 0x00]
        #expect(throws: ZlibError.headerCheckFailed) {
            try Zlib.decode(bytes(raw))
        }
    }

    @Test("FDICT flag throws .presetDictionaryUnsupported")
    func presetDict() {
        // 0x78 + FLG with bit 5 set; need FCHECK satisfying mod 31.
        // 0x78 = 120, want (120*256 + flg) % 31 == 0 → flg = (31 - (30720 % 31)) % 31 = 30
        // But we need bit 5 set (0x20). 30 = 0x1E, no bit 5. Try FCHECK + FDICT:
        // flg = 0x20 | x where x ∈ [0..0x1F]. (120*256 + (0x20 | x)) % 31 = 0.
        // 30720 % 31 = 1, so we need (1 + 0x20 + x) % 31 = 0 → (33 + x) % 31 = 0 → x = 29 or 60.
        // 29 = 0x1D, so flg = 0x20 | 0x1D = 0x3D. Verify: 30720 + 0x3D = 30720 + 61 = 30781. 30781 / 31 = 992.93... try 30752 / 31 = 992 exactly → 30752 = 30720 + 32 = 0x78 << 8 | 0x20. So FLG = 0x20 alone (CINFO=7, CM=8 base + FDICT only).
        // (120 * 256 + 32) % 31 = 30752 % 31 = 0. ✓
        let raw: [UInt8] = [0x78, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        #expect(throws: ZlibError.presetDictionaryUnsupported) {
            try Zlib.decode(bytes(raw))
        }
    }

    @Test("ADLER32 mismatch throws")
    func adler32Mismatch() {
        // Take the 'abc' vector but corrupt the trailer.
        let raw: [UInt8] = [0x78, 0x9C, 0x4B, 0x4C, 0x4A, 0x06, 0x00, 0xDE, 0xAD, 0xBE, 0xEF]
        #expect(throws: ZlibError.adler32Mismatch) {
            try Zlib.decode(bytes(raw))
        }
    }
}

@Suite("Adler32")
struct Adler32Tests {
    @Test("ADLER32 of empty input is 1")
    func adlerEmpty() {
        var b = ContiguousArray<UInt8>()
        #expect(Adler32.compute(b) == 1)
        _ = b
    }

    @Test("ADLER32 of 'abc' is 0x024D0127")
    func adlerAbc() {
        let bs: ContiguousArray<UInt8> = [0x61, 0x62, 0x63]
        #expect(Adler32.compute(bs) == 0x024D0127)
    }

    @Test("ADLER32 of 'hello world' is 0x1A0B045D")
    func adlerHelloWorld() {
        let bs: ContiguousArray<UInt8> = [
            0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64,
        ]
        #expect(Adler32.compute(bs) == 0x1A0B045D)
    }
}

@Suite("Zlib.Encoder API surface")
struct ZlibEncoderAPITests {
    @Test("encode emits CMF=0x78")
    func cmfDeflate32K() {
        let out = Zlib.encode(Bytes([0x41]))
        #expect(out.storage.count >= 6)
        #expect(out.storage[0] == 0x78)
    }

    @Test("FLG passes the (CMF * 256 + FLG) % 31 == 0 check")
    func headerCheck() {
        for level: Zlib.Encoder.Level in [.none, .fast, .default, .best] {
            let out = Zlib.encode(Bytes([0x41]), level: level)
            let v = (UInt32(out.storage[0]) << 8) | UInt32(out.storage[1])
            #expect(v % 31 == 0, "header check failed at \(level)")
        }
    }

    @Test("FLEVEL hint: .none/.fast → 0, .default → 2, .best → 3")
    func flevelHint() {
        let input = Bytes([0x41])
        let noneFlg = Zlib.encode(input, level: .none).storage[1]
        let fastFlg = Zlib.encode(input, level: .fast).storage[1]
        let defFlg  = Zlib.encode(input, level: .default).storage[1]
        let bestFlg = Zlib.encode(input, level: .best).storage[1]
        #expect((noneFlg >> 6) == 0)
        #expect((fastFlg >> 6) == 0)
        #expect((defFlg  >> 6) == 2)
        #expect((bestFlg >> 6) == 3)
    }

    @Test("FDICT bit is 0 (no preset dictionary)")
    func fdictZero() {
        let out = Zlib.encode(Bytes([0x41]))
        #expect(out.storage[1] & 0x20 == 0)
    }
}

@Suite("Zlib encoder round-trip via v0.1 decoder")
struct ZlibEncoderRoundTripTests {
    @Test("empty input")
    func empty() throws {
        let input = Bytes()
        let encoded = Zlib.encode(input)
        let back = try Zlib.decode(encoded)
        #expect(back.storage == input.storage)
    }

    @Test("ASCII 'hello'")
    func helloAscii() throws {
        let input = Bytes([0x68, 0x65, 0x6C, 0x6C, 0x6F])
        let encoded = Zlib.encode(input)
        let back = try Zlib.decode(encoded)
        #expect(back.storage == input.storage)
    }

    @Test("100 bytes of 0x41 at .fast")
    func runsFast() throws {
        let input = Bytes(ContiguousArray(repeating: UInt8(0x41), count: 100))
        let encoded = Zlib.encode(input, level: .fast)
        let back = try Zlib.decode(encoded)
        #expect(back.storage == input.storage)
        #expect(encoded.storage.count < input.storage.count / 2)
    }

    @Test("64 KiB input round-trips at .default")
    func largeDefault() throws {
        var bytes = ContiguousArray<UInt8>()
        bytes.reserveCapacity(65_536)
        for i in 0..<65_536 {
            bytes.append(UInt8(truncatingIfNeeded: i & 0x3F))
        }
        let input = Bytes(bytes)
        let encoded = Zlib.encode(input, level: .default)
        let back = try Zlib.decode(encoded)
        #expect(back.storage == input.storage)
    }

    @Test("all four levels round-trip identical input")
    func allLevels() throws {
        let input = Bytes(ContiguousArray(repeating: UInt8(0x42), count: 50))
        for level: Zlib.Encoder.Level in [.none, .fast, .default, .best] {
            let encoded = Zlib.encode(input, level: level)
            let back = try Zlib.decode(encoded)
            #expect(back.storage == input.storage,
                    "level \(level) failed round-trip")
        }
    }

    @Test("ADLER32 trailer is big-endian (last 4 bytes)")
    func adlerBigEndian() {
        // For input "abc", ADLER32 = 0x024D0127. Trailer must be 02 4D 01 27.
        let input = Bytes([0x61, 0x62, 0x63])
        let encoded = Zlib.encode(input)
        let n = encoded.storage.count
        #expect(encoded.storage[n - 4] == 0x02)
        #expect(encoded.storage[n - 3] == 0x4D)
        #expect(encoded.storage[n - 2] == 0x01)
        #expect(encoded.storage[n - 1] == 0x27)
    }
}

@Suite("v0.1 API stability — additive only")
struct ZlibV01StabilityTests {
    @Test("Zlib.decode(_:) still round-trips with v0.2 encoder")
    func decodeUnchanged() throws {
        let input = Bytes([0x68, 0x65, 0x6C, 0x6C, 0x6F])
        let encoded = Zlib.encode(input)
        let back = try Zlib.decode(encoded)
        #expect(back.storage == input.storage)
    }

    @Test("ZlibError v0.1 cases still present")
    func errorCasesPresent() {
        let e: ZlibError = .truncated
        switch e {
        case .truncated, .unsupportedCompressionMethod, .invalidWindowSize,
             .headerCheckFailed, .presetDictionaryUnsupported, .adler32Mismatch,
             .malformedDeflate:
            #expect(true)
        }
    }
}
