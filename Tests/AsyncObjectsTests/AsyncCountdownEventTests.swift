import XCTest
@testable import AsyncObjects

@MainActor
class AsyncCountdownEventTests: XCTestCase {

    func testCountdownWaitWithoutIncrement() async throws {
        let event = AsyncCountdownEvent()
        try await Self.checkExecInterval(durationInSeconds: 0) {
            try await event.wait()
        }
    }

    func testCountdownWaitZeroTimeoutWithoutIncrement() async throws {
        let event = AsyncCountdownEvent()
        try await Self.checkExecInterval(durationInSeconds: 0) {
            try await event.wait(forSeconds: 0)
        }
    }

    static func signalCountdownEvent(
        _ event: AsyncCountdownEvent,
        times count: UInt
    ) {
        Task.detached {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<count {
                    group.addTask {
                        try await Self.sleep(seconds: (Double(i) + 1) * 0.5)
                        event.signal(repeat: 1)
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    func testCountdownWaitWithIncrement() async throws {
        let event = AsyncCountdownEvent()
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Self.signalCountdownEvent(event, times: 10)
        try await Self.checkExecInterval(durationInSeconds: 5) {
            try await event.wait()
        }
    }

    func testCountdownWaitTimeoutWithIncrement() async throws {
        let event = AsyncCountdownEvent()
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Self.signalCountdownEvent(event, times: 10)
        await Self.checkExecInterval(durationInSeconds: 3) {
            do {
                try await event.wait(forSeconds: 3)
                XCTFail("Unexpected task progression")
            } catch {
                XCTAssertTrue(type(of: error) == DurationTimeoutError.self)
            }
        }
    }

    func testCountdownWaitWithLimitAndIncrement() async throws {
        let event = AsyncCountdownEvent(until: 3)
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Self.signalCountdownEvent(event, times: 10)
        try await Self.checkExecInterval(durationInRange: 3.5..<4.3) {
            try await event.wait()
        }
    }

    func testCountdownWaitTimeoutWithLimitAndIncrement() async throws {
        let event = AsyncCountdownEvent(until: 3)
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Self.signalCountdownEvent(event, times: 10)
        await Self.checkExecInterval(durationInSeconds: 2) {
            do {
                try await event.wait(forSeconds: 2)
                XCTFail("Unexpected task progression")
            } catch {
                XCTAssertTrue(type(of: error) == DurationTimeoutError.self)
            }
        }
    }

    func testCountdownWaitWithLimitInitialCountAndIncrement() async throws {
        let event = AsyncCountdownEvent(until: 3, initial: 2)
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Self.signalCountdownEvent(event, times: 10)
        try await Self.checkExecInterval(durationInRange: 4.5..<5.3) {
            try await event.wait()
        }
    }

    func testCountdownWaitTimeoutWithLimitInitialCountAndIncrement()
        async throws
    {
        let event = AsyncCountdownEvent(until: 3, initial: 3)
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Self.signalCountdownEvent(event, times: 10)
        await Self.checkExecInterval(durationInSeconds: 3) {
            do {
                try await event.wait(forSeconds: 3)
                XCTFail("Unexpected task progression")
            } catch {
                XCTAssertTrue(type(of: error) == DurationTimeoutError.self)
            }
        }
    }

    func testCountdownWaitWithIncrementAndReset() async throws {
        let event = AsyncCountdownEvent()
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Task.detached {
            try await Self.sleep(seconds: 3)
            event.reset()
        }
        try await Self.checkExecInterval(durationInSeconds: 3) {
            try await event.wait()
        }
    }

    func testCountdownWaitWithIncrementAndResetToCount() async throws {
        let event = AsyncCountdownEvent()
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Task.detached {
            try await Self.sleep(seconds: 3)
            event.reset(to: 2)
            await Self.signalCountdownEvent(event, times: 10)
        }
        try await Self.checkExecInterval(durationInSeconds: 4) {
            try await event.wait()
        }
    }

    func testCountdownWaitTimeoutWithIncrementAndReset() async throws {
        let event = AsyncCountdownEvent()
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Task.detached {
            try await Self.sleep(seconds: 3)
            event.reset()
        }
        await Self.checkExecInterval(durationInSeconds: 2) {
            do {
                try await event.wait(forSeconds: 2)
                XCTFail("Unexpected task progression")
            } catch {
                XCTAssertTrue(type(of: error) == DurationTimeoutError.self)
            }
        }
    }

    func testCountdownWaitTimeoutWithIncrementAndResetToCount() async throws {
        let event = AsyncCountdownEvent()
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Task.detached {
            try await Self.sleep(seconds: 3)
            event.reset(to: 6)
            await Self.signalCountdownEvent(event, times: 10)
        }
        await Self.checkExecInterval(durationInSeconds: 3) {
            do {
                try await event.wait(forSeconds: 3)
                XCTFail("Unexpected task progression")
            } catch {
                XCTAssertTrue(type(of: error) == DurationTimeoutError.self)
            }
        }
    }

    func testCountdownWaitWithConcurrentIncrementAndResetToCount() async throws
    {
        let event = AsyncCountdownEvent()
        event.increment(by: 10)
        try await Self.sleep(seconds: 0.001)
        Task.detached {
            try await Self.sleep(seconds: 2)
            event.reset(to: 2)
        }
        Self.signalCountdownEvent(event, times: 10)
        try await Self.checkExecInterval(durationInRange: 2.5...3.2) {
            try await event.wait()
        }
    }

    func testDeinit() async throws {
        let event = AsyncCountdownEvent(until: 0, initial: 1)
        Task.detached {
            try await Self.sleep(seconds: 1)
            event.signal()
        }
        try await event.wait()
        self.addTeardownBlock { [weak event] in
            try await Self.sleep(seconds: 1)
            XCTAssertNil(event)
        }
    }

    func testWaitCancellationWhenTaskCancelled() async throws {
        let event = AsyncCountdownEvent(initial: 1)
        let task = Task.detached {
            try await Self.checkExecInterval(durationInSeconds: 0) {
                try await event.wait()
            }
        }
        task.cancel()
        try? await task.value
    }

    func testWaitCancellationForAlreadyCancelledTask() async throws {
        let event = AsyncCountdownEvent(initial: 1)
        let task = Task.detached {
            try await Self.checkExecInterval(durationInSeconds: 0) {
                do {
                    try await Self.sleep(seconds: 5)
                    XCTFail("Unexpected task progression")
                } catch {}
                XCTAssertTrue(Task.isCancelled)
                try await event.wait()
            }
        }
        task.cancel()
        try? await task.value
    }

    func testConcurrentAccess() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let event = AsyncCountdownEvent(initial: 1)
                    try await Self.checkExecInterval(durationInSeconds: 0) {
                        try await withThrowingTaskGroup(of: Void.self) { g in
                            g.addTask { try await event.wait() }
                            g.addTask { event.signal() }
                            try await g.waitForAll()
                        }
                    }
                }
                try await group.waitForAll()
            }
        }
    }
}
