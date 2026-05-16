// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
import Bytes
@testable import Zlib

@Suite("Streaming encoder")
struct StreamingTests {
    // MARK: - Helpers

    private static func bytesFromString(_ s: String) -> Bytes {
        var b = Bytes()
        b.append(contentsOf: Array(s.utf8))
        return b
    }

    private static func bytesFromArray(_ a: [UInt8]) -> Bytes {
        var b = Bytes()
        b.append(contentsOf: a)
        return b
    }

    // MARK: - Round-trip

    @Test("empty stream round-trips to empty Bytes")
    func emptyStream() throws {
        var encoder = Zlib.Streaming.Encoder()
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(plain.storage.count == 0)
    }

    @Test("single chunk round-trips")
    func singleChunkRoundTrip() throws {
        let payload = Self.bytesFromString("hello")
        var encoder = Zlib.Streaming.Encoder()
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("two chunks round-trip to concatenation")
    func twoChunkRoundTrip() throws {
        let chunk1 = Self.bytesFromString("hel")
        let chunk2 = Self.bytesFromString("lo")
        var encoder = Zlib.Streaming.Encoder()
        encoder.update(chunk1)
        encoder.update(chunk2)
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == Array("hello".utf8))
    }

    @Test("many tiny 1-byte chunks round-trip")
    func manyTinyChunks() throws {
        let payload: [UInt8] = (0..<100).map { UInt8($0 & 0xFF) }
        var encoder = Zlib.Streaming.Encoder()
        for byte in payload {
            encoder.update(Self.bytesFromArray([byte]))
        }
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == payload)
    }

    @Test("large 70 KiB chunk round-trips")
    func largeChunk() throws {
        let size = 70 * 1024
        let payload = [UInt8](repeating: 0x41, count: size)
        var encoder = Zlib.Streaming.Encoder()
        encoder.update(Self.bytesFromArray(payload))
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(plain.storage.count == size)
        #expect(Array(plain.storage) == payload)
    }

    @Test("mixed-size chunks round-trip")
    func mixedSizeChunks() throws {
        let pangram = Self.bytesFromString("The quick brown fox jumps over the lazy dog. ")
        let small = Self.bytesFromString("XY")
        let medium = Self.bytesFromArray([UInt8](repeating: 0x42, count: 256))
        var encoder = Zlib.Streaming.Encoder()
        encoder.update(pangram)
        encoder.update(small)
        encoder.update(medium)
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        let expected = Array(pangram.storage) + Array(small.storage) + Array(medium.storage)
        #expect(Array(plain.storage) == expected)
    }

    @Test("empty chunk in middle is a no-op")
    func emptyChunkInMiddle() throws {
        var encoder = Zlib.Streaming.Encoder()
        encoder.update(Self.bytesFromString("a"))
        encoder.update(Bytes())
        encoder.update(Self.bytesFromString("b"))
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == Array("ab".utf8))
    }

    // MARK: - Level coverage

    @Test(".none level round-trip")
    func levelNone() throws {
        let payload = Self.bytesFromString("hello world")
        var encoder = Zlib.Streaming.Encoder(level: .none)
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test(".fast level round-trip")
    func levelFast() throws {
        let payload = Self.bytesFromString("The quick brown fox jumps over the lazy dog.")
        var encoder = Zlib.Streaming.Encoder(level: .fast)
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test(".default level round-trip")
    func levelDefault() throws {
        let payload = Self.bytesFromString("The quick brown fox jumps over the lazy dog.")
        var encoder = Zlib.Streaming.Encoder(level: .default)
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test(".best level round-trip")
    func levelBest() throws {
        let payload = Self.bytesFromArray([UInt8](repeating: 0x5A, count: 1024))
        var encoder = Zlib.Streaming.Encoder(level: .best)
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    // MARK: - Header check

    @Test("CMF/FLG header check is divisible by 31")
    func headerCheckValid() throws {
        var encoder = Zlib.Streaming.Encoder(level: .default)
        encoder.update(Self.bytesFromString("x"))
        let compressed = try encoder.finish()
        let cmf = UInt32(compressed.storage[0])
        let flg = UInt32(compressed.storage[1])
        let check = (cmf * 256 + flg) % 31
        #expect(check == 0)
    }

    // MARK: - Error / edge cases

    @Test("double-finish throws encoderFinished")
    func doubleFinishThrows() throws {
        var encoder = Zlib.Streaming.Encoder()
        encoder.update(Self.bytesFromString("data"))
        _ = try encoder.finish()
        do {
            _ = try encoder.finish()
            Issue.record("expected throw")
        } catch ZlibError.encoderFinished {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("update after finish is silent no-op (then double-finish throws)")
    func updateAfterFinishNoOp() throws {
        var encoder = Zlib.Streaming.Encoder()
        encoder.update(Self.bytesFromString("first"))
        let compressed = try encoder.finish()
        encoder.update(Self.bytesFromString("second"))
        do {
            _ = try encoder.finish()
            Issue.record("expected throw")
        } catch ZlibError.encoderFinished {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == Array("first".utf8))
    }

    @Test("single-byte stream round-trips")
    func singleByteStream() throws {
        let payload = Self.bytesFromArray([0x7F])
        var encoder = Zlib.Streaming.Encoder()
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try Zlib.decode(compressed)
        #expect(Array(plain.storage) == [0x7F])
    }
}
