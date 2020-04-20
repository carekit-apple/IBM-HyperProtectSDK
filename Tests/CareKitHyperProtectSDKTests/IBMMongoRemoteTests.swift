import XCTest
@testable import CareKitHyperProtectSDK

final class IBMMongoRemoteTests: XCTestCase {
    
    func testInitializer() {
        _ = IBMMongoRemote(id: "", appleId: "")
    }
    
    static var allTests = [
        ("testInitializer", testInitializer)
    ]
}
