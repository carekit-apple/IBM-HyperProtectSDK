/*
 Copyright (c) 2020, Apple, IBM Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3. Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import XCTest
import CareKitStore
@testable import IBMHyperProtectSDK

final class IBMMongoRemoteTests: XCTestCase {
    
    private func performSynchronously(
        _ closure: @escaping (@escaping (Error?) -> Void) -> Void) throws {

        let group = DispatchGroup()
        group.enter()

        var syncError: Error?

        DispatchQueue.global(qos: .background).async {
            closure({ error in
                syncError = error
                group.leave()
            })
        }

        group.wait()

        if let error = syncError {
            throw error
        }
    }
    
    private func performSynchronously<T>(
        _ closure: @escaping (@escaping (Result<T, OCKStoreError>) -> Void) -> Void) throws -> T {

        let timeout: TimeInterval = 10.0
        let dispatchGroup = DispatchGroup()
        var closureResult: Result<T, OCKStoreError> = .failure(.timedOut(
            reason: "Timed out after \(timeout) seconds."))
        dispatchGroup.enter()
        DispatchQueue.global(qos: .background).async {
            closure { result in
                closureResult = result
                dispatchGroup.leave()
            }
        }
        _ = dispatchGroup.wait(timeout: .now() + timeout)
        return try closureResult.get()
    }
    
    /**
     Creates a remote store. Input apiLocation.
     */
    func createStore(taskID: UUID, completion: @escaping (OCKStore?, UUID?, Error?) -> Void) {
        // Uncomment to test remote
        let remote = IBMMongoRemote(apiLocation: "http://localhost:3000/")
        let store = OCKStore(name: "CareStore", type: .inMemory, remote: remote)
        let schedule = OCKSchedule.dailyAtTime(hour: 0, minutes: 0, start: Date(), end: nil, text: nil)
        let task = OCKTask(id: "\(taskID)", title: nil, carePlanUUID: nil, schedule: schedule)
        
        store.addTask(task)
        
        store.fetchTask(withID: "\(taskID)") { result in
            switch result {
            case .success(let task):
                completion(store, task.uuid!, nil)
            case .failure(let error):
                completion(nil, nil, error)
            }
        }
    }
    
    func testInitializer() {
        
    }
    
    /**
     Checks if a small payload can successfully save to CareKitStore.
     */
    func testSmallPayload() {
        let expectation = self.expectation(description: "Add Outcome")
        
        createStore(taskID: UUID()) { store, uuid, error in
            if let store = store, let uuid = uuid {
                let outcome = OCKOutcome(taskUUID: uuid, taskOccurrenceIndex: 0, values: [OCKOutcomeValue(String(repeating: "0", count: 2))])
                
                 store.addOutcome(outcome, callbackQueue: .main) { result in
                    switch result {
                    case .success(_):
                        // Uncomment to test remote
                        try! self.performSynchronously { _ in
                        store.synchronize() { error in
                            if let error = error {
                                print(error.localizedDescription)
                                XCTAssert(false)
                            } else {
                                XCTAssert(true)
                            }
                            
                            expectation.fulfill()
                        }
                        }
                        
                        // Comment to test Remote
                        //XCTAssert(true)
                        expectation.fulfill()
                    case .failure(let error):
                        print(error.localizedDescription)
                        XCTAssert(false)
                        
                        expectation.fulfill()
                    }
                }
                
            } else {
                if let error = error {
                    print(error.localizedDescription)
                }
                
                XCTAssert(false)
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    /**
     Checks if a large payload can successfully save to CareKitStore.
     */
    func testLargePayload() {
        let expectation = self.expectation(description: "Add Outcome")
        
        createStore(taskID: UUID()) { store, uuid, error in
            if let store = store, let uuid = uuid {
                let outcome = OCKOutcome(taskUUID: uuid, taskOccurrenceIndex: 0, values: [OCKOutcomeValue(String(repeating: "0", count: 100000))])
                
                store.addOutcome(outcome, callbackQueue: .main) { result in
                    switch result {
                    case .success(_):
                        // Uncomment to test remote
                        store.synchronize() { error in
                            if let error = error {
                                print(error.localizedDescription)
                                XCTAssert(false)
                            } else {
                                XCTAssert(true)
                            }
                            
                            expectation.fulfill()
                        }
                        
                        // Comment to test remote
                        //XCTAssert(true)
                        expectation.fulfill()
                    case .failure(let error):
                        print(error.localizedDescription)
                        XCTAssert(false)
                        
                        expectation.fulfill()
                    }
                }
            } else {
                if let error = error {
                    print(error.localizedDescription)
                }
                
                XCTAssert(false)
            }
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    /**
     Checks if two small payloads in an array can successfully save to CareKitStore.
     */
    func testPayloadArray() {
        let expectation = self.expectation(description: "Add Outcome")
        
        createStore(taskID: UUID()) { store, uuid, error in
            if let store = store, let uuid = uuid {
                let outcome1 = OCKOutcome(taskUUID: uuid, taskOccurrenceIndex: 0, values: [OCKOutcomeValue(String(repeating: "0", count: 50000))])
                let outcome2 = OCKOutcome(taskUUID: uuid, taskOccurrenceIndex: 1, values: [OCKOutcomeValue(String(repeating: "0", count: 50000))])
                
                store.addOutcomes([outcome1, outcome2], callbackQueue: .main) { result in
                    switch result {
                    case .success(_):
                        // Uncomment to test remote
                        store.synchronize() { error in
                            if let error = error {
                                print(error.localizedDescription)
                                XCTAssert(false)
                            } else {
                                XCTAssert(true)
                            }
                            
                            expectation.fulfill()
                        }
                        
                        // Comment to test remote
                        //XCTAssert(true)
                        expectation.fulfill()
                    case .failure(let error):
                        print(error.localizedDescription)
                        XCTAssert(false)
                        
                        expectation.fulfill()
                    }
                }
            } else {
                if let error = error {
                    print(error.localizedDescription)
                }
                
                XCTAssert(false)
            }
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    static var allTests = [
        ("testInitializer", testInitializer),
        ("testPayloadTooLarge", testSmallPayload),
        ("testLargePayload", testLargePayload),
        ("testPayloadArray", testPayloadArray)
    ]
}
