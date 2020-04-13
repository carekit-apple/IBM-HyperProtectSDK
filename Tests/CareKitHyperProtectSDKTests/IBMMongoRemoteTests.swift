import XCTest
@testable import CareKitHyperProtectSDK

final class IBMMongoRemoteTests: XCTestCase {

    func testInitializer() {
        _ = IBMMongoRemote()
    }

    static var allTests = [
        ("testInitializer", testInitializer)
    ]
}
