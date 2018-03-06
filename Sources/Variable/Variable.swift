import class Dispatch.DispatchQueue

/// Subscription
public protocol Subscription {
    var isCancelled: Bool { get }
    func cancel()
}

internal let variableSerialQueue = DispatchQueue(label: "Variable")

/// The `Variable` object is used as proxy to continuously forward its value subscribers.
public class Variable<Value> {
    private var _value: Value?

    fileprivate let queue: DispatchQueue
    fileprivate var ticking: Bool

    fileprivate var subscriberHead: Subscriber?
    fileprivate var subscriberTail: Subscriber?

    fileprivate var eventHead: Event?
    fileprivate var eventTail: Event?

    /// Allocates a variable without initiating it.
    ///
    /// > Retrieving the value of uninitiated variable will cause `fatalError`.
    public init() {
        self._value = nil
        self.queue = variableSerialQueue
        self.ticking = false
    }

    /// Initiates a `Variable` instance.
    ///
    /// - Parameter value: The initial value of variable.
    public init(value: Value) {
        self._value = value
        self.queue = variableSerialQueue
        self.ticking = false
    }

    /// Returns the current value of variable.
    ///
    /// > Retrieving the value of uninitiated variable will cause `fatalError`.
    public var value: Value {
        guard let value = self._value else {
            fatalError("Retrieving variable value before initiation.")
        }
        return value
    }

    /// Saves the given value to variable and asynchronously forward it to subscribers.
    ///
    /// - Parameter value: The latest value of variable.
    public func next(value: Value) {
        self._value = value
        self.queue.async {
            let event = Event(value: value)
            if let eventTail = self.eventTail {
                eventTail.next = event
                self.eventTail = event
            }
            else {
                self.eventHead = event
                self.eventTail = event
            }
            self.tick()
        }
    }

    /// Adds a listener to the variable.
    ///
    /// - Parameters:
    ///   - queue: An optional `DispatchQueue` to execute in. If it is not given,
    ///   the default `DispatchQueue.global()` will be employed instead.
    ///   - body: A closure with a value parameter from the variable.
    ///
    /// - Returns: A `Subscription`.
    @discardableResult
    public func subscribe(in queue: DispatchQueue? = nil, execute body: @escaping (Value) -> Void) -> Subscription {
        let initialValue = self._value
        let subscriber = Subscriber(
            variable: self,
            initialValue: initialValue,
            in: queue ?? DispatchQueue.global(),
            execute: body
        )
        self.queue.async {
            if subscriber.removed {
                return
            }

            // Appends the subscribers pool.
            if let subscriberTail = self.subscriberTail {
                subscriberTail.next = subscriber
                subscriber.previous = subscriberTail
            }
            else {
                self.subscriberHead = subscriber
            }
            self.subscriberTail = subscriber

            // Appends the initial value to Event pool.
            if let value = initialValue {
                let event = Event(value: value, subscriber: subscriber)
                if let eventTail = self.eventTail {
                    eventTail.next = event
                }
                else {
                    self.eventHead = event
                }
                self.eventTail = event
                self.tick()
            }
        }
        return subscriber
    }
}

/// Variable.Subscribable
extension Variable {
    public struct Subscribable {
        private let variable: Variable

        public init(_ variable: Variable) {
            self.variable = variable
        }

        @discardableResult
        public func subscribe(in queue: DispatchQueue? = nil, execute body: @escaping (Value) -> Void) -> Subscription {
            return variable.subscribe(in: queue, execute: body)
        }
    }
}

// PRIVATE classes
extension Variable {
    fileprivate class Subscriber {
        weak var variable: Variable?
        var initialValue: Value?

        var removed: Bool
        var previous: Subscriber?
        var next: Subscriber?

        let queue: DispatchQueue
        let execute: (Value) -> Void

        init(variable: Variable, initialValue: Value?, in queue: DispatchQueue, execute: @escaping (Value) -> Void) {
            self.variable = variable
            self.initialValue = initialValue
            self.removed = false
            self.previous = nil
            self.next = nil
            self.queue = queue
            self.execute = execute
        }
    }

    fileprivate class Event {
        let value: Value
        let subscriber: Subscriber? // initial value for this subscriber only
        var next: Event?
        var matchedCount: Int
        var invokedCount: Int

        init(value: Value, subscriber: Subscriber? = nil) {
            self.value = value
            self.subscriber = subscriber
            self.next = nil
            self.matchedCount = 0
            self.invokedCount = 0
        }
    }
}

// forward values
extension Variable {
    fileprivate func tick() {
        if self.ticking {
            return
        }
        self.ticking = true

        // Pull an value from the values queue.
        guard let event = self.eventHead else {
            self.ticking = false
            return
        }
        self.eventHead = event.next
        if self.eventHead == nil {
            self.eventTail = nil
        }

        // This is event to emit initial value for the specified subscriber only.
        if let subscriber = event.subscriber {
            guard subscriber.initialValue != nil else {
                self.queue.async {
                    self.ticking = false
                    self.tick()
                }
                return
            }
            subscriber.initialValue = nil
            subscriber.queue.async {
                subscriber.execute(event.value)
                self.queue.async {
                    self.ticking = false
                    self.tick()
                }
            }
            return
        }

        // Traverse all the subscribers
        var subscriberNode = self.subscriberHead
        while let subscriber = subscriberNode {

            // Do not forward value to removed subscribers, and
            // those who have sent its initial value, aka, this value appended prior to them.
            if !subscriber.removed && subscriber.initialValue == nil {
                invoke(subscriber: subscriber, with: event)
            }

            subscriberNode = subscriber.next
        }

        // No subscribers for the event, tick for next event till the event pool is empty.
        if event.matchedCount == 0 {
            self.queue.async {
                self.ticking = false
                self.tick()
            }
        }
    }

    private func invoke(subscriber: Subscriber, with event: Event) {
        event.matchedCount += 1
        subscriber.queue.async {
            subscriber.execute(event.value)
            self.queue.async {
                event.invokedCount += 1
                if event.invokedCount == event.matchedCount {
                    self.ticking = false
                    self.tick()
                }
            }
        }
    }
}

// Subscriber as Subscription
extension Variable.Subscriber: Subscription {
    public var isCancelled: Bool {
        return self.removed
    }

    public func cancel() {
        guard !self.removed, let variable = self.variable else {
            return
        }
        self.removed = true
        variable.queue.async {
            if let previous = self.previous {
                previous.next = self.next
            }
            else if self === variable.subscriberHead {
                variable.subscriberHead = self.next
            }
            if let next = self.next {
                next.previous = self.previous
            }
            else if self === variable.subscriberTail {
                variable.subscriberTail = self.previous
            }
            self.previous = nil
            self.next = nil
        }
    }
}
