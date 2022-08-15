import Foundation
import Dispatch

/// An object that bridges asynchronous work under structured concurrency
/// to Grand Central Dispatch (GCD or `libdispatch`) as `Operation`.
///
/// Using this object traditional `libdispatch` APIs can be used along with structured concurrency
/// making concurrent task management flexible in terms of managing dependencies.
///
/// You can start the operation by adding it to an `OperationQueue`,
/// or by manually calling the ``signal()`` or ``start()`` method.
/// Wait for operation completion asynchronously by calling ``wait()`` method
/// or its timeout variation ``wait(forNanoseconds:)``.
public final class TaskOperation<R: Sendable>: Operation, AsyncObject,
    @unchecked Sendable
{
    /// The dispatch queue used to synchronize data access and modifications.
    @usableFromInline
    let propQueue: DispatchQueue
    /// The asynchronous action to perform as part of the operation..
    private let underlyingAction: @Sendable () async throws -> R
    /// The top-level task that executes asynchronous action provided
    /// on behalf of the actor where operation started.
    private var execTask: Task<R, Error>?

    /// A Boolean value indicating whether the operation executes its task asynchronously.
    ///
    /// Always returns true, since the operation always executes its task asynchronously.
    public override var isAsynchronous: Bool { true }
    /// A Boolean value indicating whether the operation has been cancelled.
    ///
    /// Returns whether the underlying top-level task is cancelled or not.
    /// The default value of this property is `false`.
    /// Calling the ``cancel()`` method of this object sets the value of this property to `true`.
    public override var isCancelled: Bool { execTask?.isCancelled ?? false }

    /// Private store for boolean value indicating whether the operation is currently executing.
    private var _isExecuting: Bool = false
    /// A Boolean value indicating whether the operation is currently executing.
    ///
    /// The value of this property is true if the operation is currently executing
    /// provided asynchronous operation or false if it is not.
    public override private(set) var isExecuting: Bool {
        get { propQueue.sync { _isExecuting } }
        set {
            willChangeValue(forKey: "isExecuting")
            propQueue.sync(flags: [.barrier]) { _isExecuting = newValue }
            didChangeValue(forKey: "isExecuting")
        }
    }

    /// Private store for boolean value indicating whether the operation has finished executing its task.
    private var _isFinished: Bool = false
    /// A Boolean value indicating whether the operation has finished executing its task.
    ///
    /// The value of this property is true if the operation is finished executing or cancelled
    /// provided asynchronous operation or false if it is not.
    public override private(set) var isFinished: Bool {
        get { propQueue.sync { _isFinished } }
        set {
            willChangeValue(forKey: "isFinished")
            propQueue.sync(flags: [.barrier]) {
                _isFinished = newValue
                guard newValue, !continuations.isEmpty else { return }
                continuations.forEach { $0.value.resume() }
                continuations = [:]
            }
            didChangeValue(forKey: "isFinished")
        }
    }

    /// The result of provided asynchronous operation execution.
    ///
    /// Will be success if provided operation completed successfully,
    /// or failure returned with error.
    public var result: Result<R, Error> {
        get async { (await execTask?.result) ?? .failure(CancellationError()) }
    }

    /// Creates a new operation that executes the provided throwing asynchronous task.
    ///
    /// The provided dispatch queue is used to synchronize operation property access and modifications
    /// and prevent data races.
    ///
    /// - Parameters:
    ///   - queue: The dispatch queue to be used to synchronize data access and modifications.
    ///   - operation: The throwing asynchronous operation to execute.
    ///
    /// - Returns: The newly created asynchronous operation.
    public init(
        queue: DispatchQueue,
        operation: @escaping @Sendable () async throws -> R
    ) {
        self.propQueue = queue
        self.underlyingAction = operation
        super.init()
    }

    deinit { self.continuations.forEach { $0.value.cancel() } }

    /// Creates a new operation that executes the provided non-throwing asynchronous task.
    ///
    /// The provided dispatch queue is used to synchronize operation property access and modifications
    /// and prevent data races.
    ///
    /// - Parameters:
    ///   - queue: The dispatch queue to be used to synchronize data access and modifications.
    ///   - operation: The non-throwing asynchronous operation to execute.
    ///
    /// - Returns: The newly created asynchronous operation.
    public init(
        queue: DispatchQueue,
        operation: @escaping @Sendable () async -> R
    ) {
        self.propQueue = queue
        self.underlyingAction = operation
        super.init()
    }

    /// Begins the execution of the operation.
    ///
    /// Updates the execution state of the operation and
    /// runs the given operation asynchronously
    /// as part of a new top-level task on behalf of the current actor.
    public override func start() {
        guard !self.isFinished else { return }
        isFinished = false
        isExecuting = true
        main()
    }

    /// Performs the provided asynchronous task.
    ///
    /// Runs the given operation asynchronously
    /// as part of a new top-level task on behalf of the current actor.
    public override func main() {
        guard isExecuting, execTask == nil else { return }
        execTask = Task { [weak self] in
            guard let self = self else { throw CancellationError() }
            defer { self.finish() }
            let result = try await underlyingAction()
            return result
        }
    }

    /// Advises the operation object that it should stop executing its task.
    ///
    /// Initiates cooperative cancellation for provided asynchronous operation
    /// and moves to finished state.
    ///
    /// Calling this method on a task that doesn’t support cancellation has no effect.
    /// Likewise, if the task has already run past the last point where it would stop early,
    /// calling this method has no effect.
    public override func cancel() {
        execTask?.cancel()
        finish()
    }

    /// Moves this operation to finished state.
    ///
    /// Must be called either when operation completes or cancelled.
    @inline(__always)
    func finish() {
        isExecuting = false
        isFinished = true
    }

    // MARK: AsyncObject Impl
    /// The suspended tasks continuation type.
    @usableFromInline
    typealias Continuation = GlobalContinuation<Void, Error>
    /// The continuations stored with an associated key for all the suspended task that are waiting for operation completion.
    @usableFromInline
    private(set) var continuations: [UUID: Continuation] = [:]

    /// Add continuation with the provided key in `continuations` map.
    ///
    /// - Parameters:
    ///   - continuation: The `continuation` to add.
    ///   - key: The key in the map.
    @inlinable
    func addContinuation(
        _ continuation: Continuation,
        withKey key: UUID
    ) {
        propQueue.sync(flags: [.barrier]) {
            if isFinished { continuation.resume(); return }
            continuations[key] = continuation
        }
    }

    /// Remove continuation associated with provided key
    /// from `continuations` map.
    ///
    /// - Parameter key: The key in the map.
    @inlinable
    func removeContinuation(withKey key: UUID) {
        propQueue.sync(flags: [.barrier]) {
            let continuation = continuations.removeValue(forKey: key)
            continuation?.cancel()
        }
    }

    /// Suspends the current task, then calls the given closure with a throwing continuation for the current task.
    /// Continuation can be cancelled with error if current task is cancelled, by invoking `removeContinuation`.
    ///
    /// Spins up a new continuation and requests to track it with key by invoking `addContinuation`.
    /// This operation cooperatively checks for cancellation and reacting to it by invoking `removeContinuation`.
    /// Continuation can be resumed with error and some cleanup code can be run here.
    ///
    /// - Throws: If `resume(throwing:)` is called on the continuation, this function throws that error.
    @inlinable
    func withPromisedContinuation() async throws {
        let key = UUID()
        try await withTaskCancellationHandler { [weak self] in
            self?.removeContinuation(withKey: key)
        } operation: { () -> Continuation.Success in
            try await Continuation.with { continuation in
                self.addContinuation(continuation, withKey: key)
            }
        }
    }

    /// Starts operation asynchronously
    /// as part of a new top-level task on behalf of the current actor.
    @Sendable
    public func signal() {
        self.start()
    }

    /// Waits for operation to complete successfully or cancelled.
    ///
    /// Only waits asynchronously, if operation is executing,
    /// until it is completed or cancelled.
    @Sendable
    public func wait() async {
        guard !isFinished else { return }
        try? await withPromisedContinuation()
    }
}
