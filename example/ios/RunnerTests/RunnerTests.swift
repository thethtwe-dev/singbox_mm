import Flutter
import XCTest

@testable import singbox_mm

class RunnerTests: XCTestCase {
  func testGetStateReturnsDisconnectedByDefault() {
    let plugin = SingboxMmPlugin()
    let call = FlutterMethodCall(methodName: "getState", arguments: [])

    let resultExpectation = expectation(description: "result block must be called")
    plugin.handle(call) { result in
      XCTAssertEqual(result as? String, "disconnected")
      resultExpectation.fulfill()
    }

    waitForExpectations(timeout: 1)
  }
}
