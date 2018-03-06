import XCTest
@testable import Variable

class VariableTests: XCTestCase {
    func testInitiate() {
        expectFulfillment { fulfill in
            var count = 1
            let variable = Variable<Int>()

            variable.subscribe { value in
                XCTAssertEqual(value, count)
                count += 1

                if count == 4 {
                    fulfill()
                }
            }

            variable.next(value: 1)
            variable.next(value: 2)
            variable.next(value: 3)
        }
    }

    func testSubscribe() {
        expectFulfillment { fulfill in
            var count = 0
            let variable = Variable(value: 0)

            variable.subscribe { value in
                XCTAssertEqual(value, count)
                count += 1

                if count == 4 {
                    fulfill()
                }
            }

            variable.next(value: 1)
            variable.next(value: 2)
            variable.next(value: 3)
        }
    }

    func testCancel() {
        expectFulfillment { fulfill in
            let max: Int = 200
            var count: Int = 0
            let variable = Variable(value: 0)
            let subscribable = Variable.Subscribable(variable)

            subscribable.subscribe { value in
                XCTAssertEqual(value, count)
                count += 1

                if count == max {
                    fulfill()
                }
            }

            var subscription: Subscription?
            subscription = subscribable.subscribe { value in
                if value == max / 2 {
                    subscription?.cancel()
                }
                else if value > max / 2 {
                    XCTFail("Should not receive value")
                }
            }

            for value in 1 ... max {
                variable.next(value: value)
            }
        }
    }

    static var allTests = [
        ("testInitiate", testInitiate),
        ("testSubscribe", testSubscribe),
        ("testCancel", testCancel)
    ]
}

extension XCTestCase {
    func expectFulfillment(timeout: Double = 3, testcase: @escaping (@escaping () -> Void) -> Void) {
        let expect = expectation(description: "expectingFulfillment")
        testcase {
            expect.fulfill()
        }
        waitForExpectations(timeout: timeout) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout error: \(error)")
            }
        }
    }
}