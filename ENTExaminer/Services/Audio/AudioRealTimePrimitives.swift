import Foundation

// MARK: - Lock-Free Ring Buffer

/// A single-producer, single-consumer ring buffer safe for use on the real-time audio thread.
/// The producer (audio render callback) writes without locks; the consumer reads from the actor.
final class SPSCRingBuffer: @unchecked Sendable {
    private let capacity: Int
    private let buffer: UnsafeMutablePointer<UInt8>
    private let head: UnsafeMutablePointer<Int>  // write position (producer)
    private let tail: UnsafeMutablePointer<Int>  // read position (consumer)

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = .allocate(capacity: capacity)
        self.buffer.initialize(repeating: 0, count: capacity)
        self.head = .allocate(capacity: 1)
        self.head.initialize(to: 0)
        self.tail = .allocate(capacity: 1)
        self.tail.initialize(to: 0)
    }

    deinit {
        buffer.deallocate()
        head.deallocate()
        tail.deallocate()
    }

    var availableToRead: Int {
        let h = head.pointee
        let t = tail.pointee
        if h >= t {
            return h - t
        }
        return capacity - t + h
    }

    /// Write bytes from the real-time audio thread. Returns the number of bytes actually written.
    @discardableResult
    func write(_ source: UnsafeRawPointer, count: Int) -> Int {
        let h = head.pointee
        let t = tail.pointee
        let free: Int
        if h >= t {
            free = capacity - h + t - 1
        } else {
            free = t - h - 1
        }

        let toWrite = min(count, free)
        guard toWrite > 0 else { return 0 }

        let src = source.bindMemory(to: UInt8.self, capacity: toWrite)

        let firstChunk = min(toWrite, capacity - h)
        buffer.advanced(by: h).update(from: src, count: firstChunk)

        if toWrite > firstChunk {
            buffer.update(from: src.advanced(by: firstChunk), count: toWrite - firstChunk)
        }

        head.pointee = (h + toWrite) % capacity

        return toWrite
    }

    /// Read bytes from the consumer side. Returns the number of bytes actually read.
    @discardableResult
    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        let h = head.pointee
        let t = tail.pointee
        let available: Int
        if h >= t {
            available = h - t
        } else {
            available = capacity - t + h
        }

        let toRead = min(count, available)
        guard toRead > 0 else { return 0 }

        let firstChunk = min(toRead, capacity - t)
        destination.update(from: buffer.advanced(by: t), count: firstChunk)

        if toRead > firstChunk {
            destination.advanced(by: firstChunk).update(from: buffer, count: toRead - firstChunk)
        }

        tail.pointee = (t + toRead) % capacity

        return toRead
    }
}

// MARK: - Atomic Float Array

/// A fixed-size array of floats written from the real-time thread, read from the main/actor thread.
/// Uses os_unfair_lock for minimal-latency synchronization (safe because the critical section is
/// a trivial memcpy with bounded, constant time).
final class AtomicFloatArray: @unchecked Sendable {
    private let storage: UnsafeMutablePointer<Float>
    private let lockPtr: UnsafeMutablePointer<os_unfair_lock>
    let count: Int

    init(count: Int) {
        self.count = count
        self.storage = .allocate(capacity: count)
        self.storage.initialize(repeating: 0, count: count)
        self.lockPtr = .allocate(capacity: 1)
        self.lockPtr.initialize(to: os_unfair_lock())
    }

    deinit {
        storage.deallocate()
        lockPtr.deallocate()
    }

    func write(_ values: UnsafePointer<Float>, count: Int) {
        let n = min(count, self.count)
        os_unfair_lock_lock(lockPtr)
        storage.update(from: values, count: n)
        os_unfair_lock_unlock(lockPtr)
    }

    func read() -> [Float] {
        var result = [Float](repeating: 0, count: count)
        os_unfair_lock_lock(lockPtr)
        result.withUnsafeMutableBufferPointer { buf in
            buf.baseAddress!.update(from: storage, count: count)
        }
        os_unfair_lock_unlock(lockPtr)
        return result
    }
}

// MARK: - Atomic Bool

/// A simple atomic boolean for real-time thread communication.
final class AtomicBool: @unchecked Sendable {
    private let value: UnsafeMutablePointer<Int32>

    init(_ initial: Bool) {
        self.value = .allocate(capacity: 1)
        self.value.initialize(to: initial ? 1 : 0)
    }

    deinit {
        value.deallocate()
    }

    var load: Bool {
        OSAtomicAdd32(0, value) != 0
    }

    func store(_ newValue: Bool) {
        if newValue {
            OSAtomicTestAndSet(0, value)
        } else {
            OSAtomicTestAndClear(0, value)
        }
    }
}
