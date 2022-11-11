#if swift(>=5.7)
import Foundation
#else
@preconcurrency import Foundation
#endif

/// An object that eventually produces a single value and then finishes or fails.
///
/// Use a future to perform some work and then asynchronously publish a single element.
/// You can initialize the future with a closure that takes a ``Future/Promise``;
/// the closure calls the promise with a `Result` that indicates either success or failure.
///
/// Otherwise, you can create future and fulfill it with a `Result` that indicates either success or failure
/// by using ``fulfill(with:)`` method. In the success case,
/// the future’s downstream subscriber receives the element prior to the publishing stream finishing normally.
/// If the result is an error, publishing terminates with that error.
///
/// ```swift
/// // create a new unfulfilled future that is cancellable
/// let future = Future<Int, Error>()
/// // or create a new unfulfilled future
/// // that is assured to be fulfilled
/// let future = Future<Int, Never>()
/// // or create a future passing callback
/// // that fulfills the future
/// let future = Future<Int, Never> { promise in
///     DispatchQueue.global(qos: .background)
///         .asyncAfter(deadline: .now() + 2) {
///             promise(.success(5))
///         }
/// }
///
/// // wait for future to be fulfilled with some value
/// // or cancelled with some error
/// let value = try await future.value
///
/// // fulfill future with some value
/// await future.fulfill(producing: 5)
/// // or cancel future with error
/// await future.fulfill(throwing: CancellationError())
/// ```
public actor Future<Output: Sendable, Failure: Error> {
    /// A type that represents a closure to invoke in the future, when an element or error is available.
    ///
    /// The promise closure receives one parameter: a `Result` that contains
    /// either a single element published by a ``Future``, or an error.
    public typealias Promise = (FutureResult) -> Void
    /// A type that represents the result in the future, when an element or error is available.
    public typealias FutureResult = Result<Output, Failure>
    /// The suspended tasks continuation type.
    @usableFromInline
    internal typealias Continuation = SafeContinuation<
        GlobalContinuation<Output, Failure>
    >
    /// The platform dependent lock used to synchronize continuations tracking.
    @usableFromInline
    internal let locker: Locker = .init()
    /// The continuations stored with an associated key for all the suspended task
    /// that are waiting for future to be fulfilled.
    @usableFromInline
    internal private(set) var continuations: [UUID: Continuation] = [:]
    /// The underlying `Result` that indicates either future fulfilled or rejected.
    ///
    /// If future isn't fulfilled or rejected, the value is `nil`.
    public private(set) var result: FutureResult?

    /// Add continuation with the provided key in `continuations` map.
    ///
    /// - Parameters:
    ///   - continuation: The `continuation` to add.
    ///   - key: The key in the map.
    @inlinable
    internal func _addContinuation(
        _ continuation: Continuation,
        withKey key: UUID = .init()
    ) {
        guard !continuation.resumed else { return }
        if let result = result { continuation.resume(with: result); return }
        continuations[key] = continuation
    }

    /// Creates a future that can be fulfilled later by ``fulfill(with:)`` or
    /// any other variation of this methods.
    ///
    /// - Returns: The newly created future.
    public init() {}

    /// Create an already fulfilled promise with the provided `Result`.
    ///
    /// - Parameter result: The result of the future.
    ///
    /// - Returns: The newly created future.
    public init(with result: FutureResult) {
        self.result = result
    }

    #if swift(>=5.7)
    /// Creates a future that invokes a promise closure when the publisher emits an element.
    ///
    /// - Parameters:
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///   - attemptToFulfill: A ``Future/Promise`` that the publisher invokes
    ///                       when the publisher emits an element or terminates with an error.
    ///
    /// - Returns: The newly created future.
    public init(
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line,
        attemptToFulfill: @Sendable @escaping (
            @escaping Promise
        ) async -> Void
    ) {
        self.init()
        Task {
            await attemptToFulfill { result in
                Task { [weak self] in
                    await self?.fulfill(
                        with: result,
                        file: file,
                        function: function,
                        line: line
                    )
                }
            }
        }
    }
    #else
    /// Creates a future that invokes a promise closure when the publisher emits an element.
    ///
    /// - Parameters:
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///   - attemptToFulfill: A ``Future/Promise`` that the publisher invokes
    ///                       when the publisher emits an element or terminates with an error.
    ///
    /// - Returns: The newly created future.
    public convenience init(
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line,
        attemptToFulfill: @Sendable @escaping (
            @escaping Promise
        ) async -> Void
    ) {
        self.init()
        Task {
            await attemptToFulfill { result in
                Task { [weak self] in
                    await self?.fulfill(
                        with: result,
                        file: file,
                        function: function,
                        line: line
                    )
                }
            }
        }
    }
    #endif

    deinit {
        guard Failure.self is Error.Protocol else { return }
        (continuations as! [UUID: GlobalContinuation<Output, Error>])
            .forEach { $0.value.cancel() }
    }

    /// Fulfill the future by producing the given value and notify subscribers.
    ///
    /// A future must be fulfilled exactly once. If the future has already been fulfilled,
    /// then calling this method has no effect and returns immediately.
    ///
    /// - Parameters:
    ///   - value: The value to produce from the future.
    ///   - file: The file future fulfillment originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future fulfillment originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future fulfillment originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    public func fulfill(
        producing value: Output,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.fulfill(
            with: .success(value),
            file: file,
            function: function,
            line: line
        )
    }

    /// Terminate the future with the given error and propagate error to subscribers.
    ///
    /// A future must be fulfilled exactly once. If the future has already been fulfilled,
    /// then calling this method has no effect and returns immediately.
    ///
    /// - Parameters:
    ///   - error: The error to throw to the callers.
    ///   - file: The file future fulfillment originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future fulfillment originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future fulfillment originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    public func fulfill(
        throwing error: Failure,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.fulfill(
            with: .failure(error),
            file: file,
            function: function,
            line: line
        )
    }

    /// Fulfill the future by returning or throwing the given result value.
    ///
    /// A future must be fulfilled exactly once. If the future has already been fulfilled,
    /// then calling this method has no effect and returns immediately.
    ///
    /// - Parameters:
    ///   - result: The result. If it contains a `.success` value,
    ///             that value delivered asynchronously to callers;
    ///             otherwise, the awaiting caller receives the `.error` instead.
    ///   - file: The file future fulfillment originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future fulfillment originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future fulfillment originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    public func fulfill(
        with result: FutureResult,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        guard self.result == nil else { return }
        self.result = result
        continuations.forEach { $0.value.resume(with: result) }
        continuations = [:]
    }
}

// MARK: Non-Throwing Future
extension Future where Failure == Never {
    /// Suspends the current task, then calls the given closure with a non-throwing continuation for the current task.
    ///
    /// Spins up a new continuation and requests to track it with key by invoking `_addContinuation`.
    /// This operation doesn't check for cancellation.
    ///
    /// - Returns: The value continuation is resumed with.
    @inlinable
    internal nonisolated func _withPromisedContinuation() async -> Output {
        return await Continuation.with { continuation in
            Task { [weak self] in
                await self?._addContinuation(continuation)
            }
        }
    }

    /// The published value of the future, delivered asynchronously.
    ///
    /// This property exposes the fulfilled value for the `Future` asynchronously.
    /// Immediately returns if `Future` is fulfilled otherwise waits asynchronously
    /// for `Future` to be fulfilled.
    ///
    /// - Parameters:
    ///   - file: The file value request originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function value request originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line value request originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    public func get(
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) async -> Output {
        if let result = result { return try! result.get() }
        return await _withPromisedContinuation()
    }

    /// Combines into a single future, for all futures to be fulfilled.
    ///
    /// If the returned future fulfills, it is fulfilled with an aggregating array of the values from the fulfilled futures,
    /// in the same order as provided.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: Already fulfilled future if no future provided, or a pending future
    ///            combining provided futures.
    public static func all(
        _ futures: [Future<Output, Failure>],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<[Output], Failure> {
        typealias IndexedOutput = (index: Int, value: Output)
        guard !futures.isEmpty else { return .init(with: .success([])) }
        return .init { promise in
            await withTaskGroup(of: IndexedOutput.self) { group in
                var result: [IndexedOutput] = []
                result.reserveCapacity(futures.count)
                for (index, future) in futures.enumerated() {
                    group.addTask {
                        return (
                            index: index,
                            value: await future.get(
                                file: file,
                                function: function,
                                line: line
                            )
                        )
                    }
                }
                for await item in group { result.append(item) }
                promise(
                    .success(
                        result.sorted { $0.index < $1.index }.map(\.value)
                    )
                )
            }
        }
    }

    /// Combines into a single future, for all futures to be fulfilled.
    ///
    /// If the returned future fulfills, it is fulfilled with an aggregating array of the values from the fulfilled futures,
    /// in the same order as provided.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: Already fulfilled future if no future provided, or a pending future
    ///            combining provided futures.
    public static func all(
        _ futures: Future<Output, Failure>...,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<[Output], Failure> {
        return Self.all(futures, file: file, function: function, line: line)
    }

    /// Combines into a single future, for all futures to have settled.
    ///
    /// Returns a future that fulfills after all of the given futures is fulfilled,
    /// with an array of `Result`s that each describe the outcome of each future
    /// in the same order as provided.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: Already fulfilled future if no future provided, or a pending future
    ///            combining provided futures.
    public static func allSettled(
        _ futures: [Future<Output, Failure>],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<[FutureResult], Never> {
        typealias IndexedOutput = (index: Int, value: FutureResult)
        guard !futures.isEmpty else { return .init(with: .success([])) }
        return .init { promise in
            await withTaskGroup(of: IndexedOutput.self) { group in
                var result: [IndexedOutput] = []
                result.reserveCapacity(futures.count)
                for (index, future) in futures.enumerated() {
                    group.addTask {
                        return (
                            index: index,
                            value: .success(
                                await future.get(
                                    file: file,
                                    function: function,
                                    line: line
                                )
                            )
                        )
                    }
                }
                for await item in group { result.append(item) }
                promise(
                    .success(
                        result.sorted { $0.index < $1.index }.map(\.value)
                    )
                )
            }
        }
    }

    /// Combines into a single future, for all futures to have settled.
    ///
    /// Returns a future that fulfills after all of the given futures is fulfilled,
    /// with an array of `Result`s that each describe the outcome of each future
    /// in the same order as provided.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: Already fulfilled future if no future provided, or a pending future
    ///            combining provided futures.
    public static func allSettled(
        _ futures: Future<Output, Failure>...,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<[FutureResult], Never> {
        return Self.allSettled(
            futures,
            file: file,
            function: function,
            line: line
        )
    }

    /// Takes multiple futures and, returns a single future that fulfills with the value
    /// as soon as any of the futures is fulfilled.
    ///
    /// If the returned future fulfills, it is fulfilled with the value of the first future that fulfilled.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: A pending future combining provided futures, or a forever pending future
    ///            if no future provided.
    public static func race(
        _ futures: [Future<Output, Failure>],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<Output, Failure> {
        return .init { promise in
            await withTaskGroup(of: Output.self) { group in
                futures.forEach { future in
                    group.addTask {
                        await future.get(
                            file: file,
                            function: function,
                            line: line
                        )
                    }
                }
                if let first = await group.next() {
                    promise(.success(first))
                }
                group.cancelAll()
            }
        }
    }

    /// Takes multiple futures and, returns a single future that fulfills with the value
    /// as soon as any of the futures is fulfilled.
    ///
    /// If the returned future fulfills, it is fulfilled with the value of the first future that fulfilled.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: A pending future combining provided futures, or a forever pending future
    ///            if no future provided.
    public static func race(
        _ futures: Future<Output, Failure>...,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<Output, Failure> {
        return Self.race(futures, file: file, function: function, line: line)
    }

    /// Takes multiple futures and, returns a single future that fulfills with the value as soon as one of the futures fulfills.
    ///
    /// If the returned future fulfills, it is fulfilled with the value of the first future that fulfilled.
    ///
    /// - Parameters:
    ///   - futures: The futures to wait for.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: A pending future waiting for first fulfilled future from provided futures,
    ///            or a forever pending future if no future provided.
    public static func any(
        _ futures: [Future<Output, Failure>],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<Output, Failure> {
        return Self.race(futures, file: file, function: function, line: line)
    }

    /// Takes multiple futures and, returns a single future that fulfills with the value as soon as one of the futures fulfills.
    ///
    /// If the returned future fulfills, it is fulfilled with the value of the first future that fulfilled.
    ///
    /// - Parameters:
    ///   - futures: The futures to wait for.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: A pending future waiting for first fulfilled future from provided futures,
    ///            or a forever pending future if no future provided.
    public static func any(
        _ futures: Future<Output, Failure>...,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<Output, Failure> {
        return Self.any(futures, file: file, function: function, line: line)
    }
}

// MARK: Throwing Future
extension Future where Failure == Error {
    /// Remove continuation associated with provided key
    /// from `continuations` map and resumes with `CancellationError`.
    ///
    /// - Parameter key: The key in the map.
    @inlinable
    internal func _removeContinuation(withKey key: UUID) {
        continuations.removeValue(forKey: key)
    }

    /// Suspends the current task, then calls the given closure with a throwing continuation for the current task.
    /// Continuation can be cancelled with error if current task is cancelled, by invoking `_removeContinuation`.
    ///
    /// Spins up a new continuation and requests to track it with key by invoking `_addContinuation`.
    /// This operation cooperatively checks for cancellation and reacting to it by invoking `_removeContinuation`.
    /// Continuation can be resumed with error and some cleanup code can be run here.
    ///
    /// - Returns: The value continuation is resumed with.
    ///
    /// - Throws: If `resume(throwing:)` is called on the continuation, this function throws that error.
    @inlinable
    internal nonisolated func _withPromisedContinuation() async throws -> Output
    {
        let key = UUID()
        return try await Continuation.withCancellation(
            synchronizedWith: locker
        ) {
            Task { [weak self] in
                await self?._removeContinuation(withKey: key)
            }
        } operation: { continuation in
            Task { [weak self] in
                await self?._addContinuation(continuation, withKey: key)
            }
        }
    }

    /// The published value of the future or an error, delivered asynchronously.
    ///
    /// This property exposes the fulfilled value for the `Future` asynchronously.
    /// Immediately returns if `Future` is fulfilled otherwise waits asynchronously
    /// for `Future` to be fulfilled. If the Future terminates with an error,
    /// the awaiting caller receives the error instead.
    ///
    /// - Parameters:
    ///   - file: The file value request originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function value request originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line value request originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Throws: If future rejected with error or `CancellationError` if cancelled.
    public func get(
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) async throws -> Output {
        if let result = result { return try result.get() }
        return try await _withPromisedContinuation()
    }

    /// Combines into a single future, for all futures to be fulfilled, or for any to be rejected.
    ///
    /// If the returned future fulfills, it is fulfilled with an aggregating array of the values from the fulfilled futures,
    /// in the same order as provided.
    ///
    /// If it rejects, it is rejected with the error from the first future that was rejected.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: Already fulfilled future if no future provided, or a pending future
    ///            combining provided futures.
    public static func all(
        _ futures: [Future<Output, Failure>],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<[Output], Failure> {
        typealias IndexedOutput = (index: Int, value: Output)
        guard !futures.isEmpty else { return .init(with: .success([])) }
        return .init { promise in
            await withThrowingTaskGroup(of: IndexedOutput.self) { group in
                var result: [IndexedOutput] = []
                result.reserveCapacity(futures.count)
                for (index, future) in futures.enumerated() {
                    group.addTask {
                        (
                            index: index,
                            value: try await future.get(
                                file: file,
                                function: function,
                                line: line
                            )
                        )
                    }
                }
                do {
                    for try await item in group { result.append(item) }
                    promise(
                        .success(
                            result.sorted { $0.index < $1.index }.map(\.value)
                        )
                    )
                } catch {
                    group.cancelAll()
                    promise(.failure(error))
                }
            }
        }
    }

    /// Combines into a single future, for all futures to be fulfilled, or for any to be rejected.
    ///
    /// If the returned future fulfills, it is fulfilled with an aggregating array of the values from the fulfilled futures,
    /// in the same order as provided.
    ///
    /// If it rejects, it is rejected with the error from the first future that was rejected.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: Already fulfilled future if no future provided, or a pending future
    ///            combining provided futures.
    public static func all(
        _ futures: Future<Output, Failure>...,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<[Output], Failure> {
        return Self.all(futures, file: file, function: function, line: line)
    }

    /// Combines into a single future, for all futures to have settled (each may fulfill or reject).
    ///
    /// Returns a future that fulfills after all of the given futures is either fulfilled or rejected,
    /// with an array of `Result`s that each describe the outcome of each future
    /// in the same order as provided.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: Already fulfilled future if no future provided, or a pending future
    ///            combining provided futures.
    public static func allSettled(
        _ futures: [Future<Output, Failure>],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<[FutureResult], Never> {
        typealias IndexedOutput = (index: Int, value: FutureResult)
        guard !futures.isEmpty else { return .init(with: .success([])) }
        return .init { promise in
            await withTaskGroup(of: IndexedOutput.self) { group in
                var result: [IndexedOutput] = []
                result.reserveCapacity(futures.count)
                for (index, future) in futures.enumerated() {
                    group.addTask {
                        do {
                            let value = try await future.get(
                                file: file,
                                function: function,
                                line: line
                            )
                            return (index: index, value: .success(value))
                        } catch {
                            return (index: index, value: .failure(error))
                        }
                    }
                }
                for await item in group { result.append(item) }
                promise(
                    .success(
                        result.sorted { $0.index < $1.index }.map(\.value)
                    )
                )
            }
        }
    }

    /// Combines into a single future, for all futures to have settled (each may fulfill or reject).
    ///
    /// Returns a future that fulfills after all of the given futures is either fulfilled or rejected,
    /// with an array of `Result`s that each describe the outcome of each future
    /// in the same order as provided.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: Already fulfilled future if no future provided, or a pending future
    ///            combining provided futures.
    public static func allSettled(
        _ futures: Future<Output, Failure>...,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<[FutureResult], Never> {
        return Self.allSettled(
            futures,
            file: file,
            function: function,
            line: line
        )
    }

    /// Takes multiple futures and, returns a single future that fulfills with the value
    /// as soon as any of the futures is fulfilled or rejected.
    ///
    /// If the returned future fulfills, it is fulfilled with the value of the first future that fulfilled.
    ///
    /// If it rejects, it is rejected with the error from the first future that was rejected.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: A pending future combining provided futures, or a forever pending future
    ///            if no future provided.
    public static func race(
        _ futures: [Future<Output, Failure>],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<Output, Failure> {
        return .init { promise in
            await withThrowingTaskGroup(of: Output.self) { group in
                futures.forEach { future in
                    group.addTask {
                        try await future.get(
                            file: file,
                            function: function,
                            line: line
                        )
                    }
                }
                do {
                    if let first = try await group.next() {
                        promise(.success(first))
                    }
                } catch {
                    promise(.failure(error))
                }
                group.cancelAll()
            }
        }
    }

    /// Takes multiple futures and, returns a single future that fulfills with the value
    /// as soon as any of the futures is fulfilled or rejected.
    ///
    /// If the returned future fulfills, it is fulfilled with the value of the first future that fulfilled.
    ///
    /// If it rejects, it is rejected with the error from the first future that was rejected.
    ///
    /// - Parameters:
    ///   - futures: The futures to combine.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: A pending future combining provided futures, or a forever pending future
    ///            if no future provided.
    public static func race(
        _ futures: Future<Output, Failure>...,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<Output, Failure> {
        return Self.race(futures, file: file, function: function, line: line)
    }

    /// Takes multiple futures and, returns a single future that fulfills with the value as soon as one of the futures fulfills.
    ///
    /// If the returned future fulfills, it is fulfilled with the value of the first future that fulfilled.
    ///
    /// If all the provided futures are rejected, it rejects with `CancellationError`.
    ///
    /// - Parameters:
    ///   - futures: The futures to wait for.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: A pending future waiting for first fulfilled future from provided futures,
    ///            or a future rejected with `CancellationError` if no future provided.
    public static func any(
        _ futures: [Future<Output, Failure>],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<Output, Failure> {
        guard !futures.isEmpty else { return .init(with: .cancelled) }
        return .init { promise in
            await withTaskGroup(of: FutureResult.self) { group in
                futures.forEach { future in
                    group.addTask {
                        do {
                            let value = try await future.get(
                                file: file,
                                function: function,
                                line: line
                            )
                            return .success(value)
                        } catch {
                            return .failure(error)
                        }
                    }
                }

                var fulfilled = false
                iterateFuture: for await item in group {
                    switch item {
                    case .success(let value):
                        promise(.success(value))
                        fulfilled = true
                        break iterateFuture
                    case .failure:
                        continue iterateFuture
                    }
                }

                if !fulfilled {
                    promise(.failure(CancellationError()))
                }
                group.cancelAll()
            }
        }
    }

    /// Takes multiple futures and, returns a single future that fulfills with the value as soon as one of the futures fulfills.
    ///
    /// If the returned future fulfills, it is fulfilled with the value of the first future that fulfilled.
    ///
    /// If all the provided futures are rejected, it rejects with `CancellationError`.
    ///
    /// - Parameters:
    ///   - futures: The futures to wait for.
    ///   - file: The file future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#fileID`).
    ///   - function: The function future initialization originates from (there's usually no need to
    ///               pass it explicitly as it defaults to `#function`).
    ///   - line: The line future initialization originates from (there's usually no need to pass it
    ///           explicitly as it defaults to `#line`).
    ///
    /// - Returns: A pending future waiting for first fulfilled future from provided futures,
    ///            or a future rejected with `CancellationError` if no future provided.
    public static func any(
        _ futures: Future<Output, Failure>...,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Future<Output, Failure> {
        return Self.any(futures, file: file, function: function, line: line)
    }
}

private extension Result where Failure == Error {
    /// The cancelled error result.
    static var cancelled: Self { .failure(CancellationError()) }
}
