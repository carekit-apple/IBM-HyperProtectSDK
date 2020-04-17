import XCTest
@testable import CareKitHyperProtectSDK

final class IBMMongoRemoteTests: XCTestCase {
    
    func testInitializer() {
        _ = IBMMongoRemote(appleId: "")
    }
    
    static var allTests = [
        ("testInitializer", testInitializer)
    ]
}
