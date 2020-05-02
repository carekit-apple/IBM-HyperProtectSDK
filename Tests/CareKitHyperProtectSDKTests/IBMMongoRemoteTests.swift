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
@testable import CareKitHyperProtectSDK
@testable import CareKitStore

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
    
    _ = group.wait(timeout: .now() + 1.0) // seconds
        
    if let error = syncError {
        throw error
    }
}

class IBMMongoRemoteTests: XCTestCase {

    func testStoreSynchronizationSucceeds() {
        let sync = IBMMongoRemote(id: "", appleId: "")
        let store = OCKStore(name: "test", type: .inMemory, remote: sync)
        XCTAssertNoThrow(try store.syncAndWait())
    }
    
    func testSuccessfulSynchronizationIncrementsKnowledgeVector() {
        let sync = IBMMongoRemote(id: "", appleId: "")
        XCTAssertNoThrow(try performSynchronously {sync.clearRemote(completion: $0)})
        let store = OCKStore(name: "test", type: .inMemory, remote: sync)
        XCTAssert(store.context.knowledgeVector.clock == 1)
        XCTAssertNoThrow(try store.syncAndWait())
        XCTAssert(store.context.knowledgeVector.clock == 2)
    }
    
    func testSyncCanBeStartedIfPreviousSyncHasCompleted() {
        let sync = IBMMongoRemote(id: "", appleId: "")
        XCTAssertNoThrow(try performSynchronously {sync.clearRemote(completion: $0)})
        let store = OCKStore(name: "test", type: .inMemory, remote: sync)
        XCTAssertNoThrow(try store.syncAndWait())
        XCTAssertNoThrow(try store.syncAndWait())
    }
    
    func testRemoteStore() throws {
        let mongo = IBMMongoRemote(id: "", appleId: "")
        mongo.automaticallySynchronizes = false
        //XCTAssertNoThrow(try performSynchronously {mongo.clearRemote(completion: $0)})
        
        //let local = OCKStore(name: "remote", type: .inMemory, remote: mongo)
        
        let schedule = OCKSchedule.dailyAtTime(hour: 1, minutes: 42, start: Date(), end: nil, text: nil)
        var taskA = OCKTask(id: "A", title: "A", carePlanUUID: nil, schedule: schedule)
        //taskA = try local.addTaskAndWait(taskA);
        taskA.uuid = UUID()
        taskA.createdDate = Date()
        taskA.updatedDate = taskA.createdDate
        
        var outcomeA = OCKOutcome(taskUUID:  taskA.uuid!, taskOccurrenceIndex: 0, values: [])
        //try local.addOutcomeAndWait(outcomeA)
        outcomeA.uuid = UUID()
        outcomeA.createdDate = Date()
        outcomeA.updatedDate = taskA.createdDate
        
        let rev = OCKRevisionRecord(entities: [.task(taskA), .outcome(outcomeA)], knowledgeVector: .init())
        let jsonData = try! JSONEncoder().encode(rev)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        print(jsonString)

        //try local.syncAndWait()
    }

    func testNonConflictingSyncAcrossStores() throws {
        let mongo = IBMMongoRemote(id: "", appleId: "")
        mongo.automaticallySynchronizes = false
        XCTAssertNoThrow(try performSynchronously {mongo.clearRemote(completion: $0)})

        let remote = OCKStore(name: "remote", type: .inMemory, remote: mongo)
        
        let endpoint = OCKStoreEndpoint(remote: remote)
        endpoint.automaticallySynchronizes = false
        let local = OCKStore(name: "local", type: .inMemory, remote: endpoint)
        
        let schedule = OCKSchedule.dailyAtTime(hour: 1, minutes: 42, start: Date(), end: nil, text: nil)
        var taskA = OCKTask(id: "A", title: "A", carePlanUUID: nil, schedule: schedule)
        var taskB = OCKTask(id: "B", title: "B", carePlanUUID: nil, schedule: schedule)
        taskA = try remote.addTaskAndWait(taskA)
        taskB = try local.addTaskAndWait(taskB)
        
        let outcomeA = OCKOutcome(taskUUID:  taskA.uuid!, taskOccurrenceIndex: 0, values: [])
        let outcomeB = OCKOutcome(taskUUID: taskB.uuid!, taskOccurrenceIndex: 0, values: [])
        try remote.addOutcomeAndWait(outcomeA)
        try local.addOutcomeAndWait(outcomeB)
        
        XCTAssertNoThrow(try local.syncAndWait())

        let localTasks = try local.fetchTasksAndWait()
        let localOutcomes = try local.fetchOutcomesAndWait()
        let remoteTasks = try remote.fetchTasksAndWait()
        let remoteOutcomes = try remote.fetchOutcomesAndWait()

        XCTAssertNoThrow(try remote.syncAndWait())
        
        XCTAssert(localTasks == remoteTasks)
        XCTAssert(localOutcomes == remoteOutcomes)
        XCTAssert(localTasks.count == 2)
        XCTAssert(localOutcomes.count == 2)
    }
    
    func testKeepRemoteTaskWithFirstVersionOfTasks() throws {
        let mongoRemote = IBMMongoRemote(id: "", appleId: "")
        mongoRemote.automaticallySynchronizes = false
        XCTAssertNoThrow(try performSynchronously {mongoRemote.clearRemote(completion: $0)})

        let remote = OCKStore(name: "remote", type: .inMemory, remote: mongoRemote)
        
        let endpoint = OCKStoreEndpoint(remote: remote)
        endpoint.automaticallySynchronizes = false
        endpoint.conflictPolicy = .keepRemote
        let local = OCKStore(name: "local", type: .inMemory, remote: endpoint)
        
        let schedule = OCKSchedule.dailyAtTime(hour: 1, minutes: 42, start: Date(), end: nil, text: nil)
        
        var taskA = OCKTask(id: "abc", title: "A", carePlanUUID: nil, schedule: schedule)
        taskA = try remote.addTaskAndWait(taskA)
        
        var taskB = OCKTask(id: "abc", title: "B", carePlanUUID: nil, schedule: schedule)
        taskB = try local.addTaskAndWait(taskB)
        
        let outcomeA = OCKOutcome(taskUUID: taskA.uuid!, taskOccurrenceIndex: 0, values: [])
        let outcomeB = OCKOutcome(taskUUID: taskB.uuid!, taskOccurrenceIndex: 0, values: [])
        try remote.addOutcomeAndWait(outcomeA)
        try local.addOutcomeAndWait(outcomeB)
        
        XCTAssertNoThrow(try local.syncAndWait())
        
        let localTasks = try local.fetchTasksAndWait()
        let localOutcomes = try local.fetchOutcomesAndWait()
        let remoteTasks = try remote.fetchTasksAndWait()
        let remoteOutcomes = try remote.fetchOutcomesAndWait()
        
        XCTAssert(localTasks == remoteTasks)
        XCTAssert(localOutcomes == remoteOutcomes)
        XCTAssert(localOutcomes.count == 1)
    }
    
    func testKeepRemoteTaskReplacingEntireLocalVersionChain() throws {
        let mongoRemote = IBMMongoRemote(id: "", appleId: "")
        mongoRemote.automaticallySynchronizes = false
        XCTAssertNoThrow(try performSynchronously {mongoRemote.clearRemote(completion: $0)})

        let remote = OCKStore(name: "remote", type: .inMemory, remote: mongoRemote)
        
        let endpoint = OCKStoreEndpoint(remote: remote)
        endpoint.automaticallySynchronizes = false
        endpoint.conflictPolicy = .keepRemote
        let local = OCKStore(name: "local", type: .inMemory, remote: endpoint)
        
        let schedule = OCKSchedule.dailyAtTime(hour: 1, minutes: 42, start: Date(), end: nil, text: nil)
        
        var taskA = OCKTask(id: "abc", title: "A", carePlanUUID: nil, schedule: schedule)
        taskA = try remote.addTaskAndWait(taskA)
        
        var taskB = OCKTask(id: "abc", title: "B", carePlanUUID: nil, schedule: schedule)
        taskB = try local.addTaskAndWait(taskB)
        let taskC = OCKTask(id: "abc", title: "C", carePlanUUID: nil, schedule: schedule.offset(by: .init(day: 2)))
        try local.updateTaskAndWait(taskC)
        
        let outcomeA = OCKOutcome(taskUUID: taskA.uuid!, taskOccurrenceIndex: 0, values: [])
        let outcomeB = OCKOutcome(taskUUID: taskB.uuid!, taskOccurrenceIndex: 0, values: [])
        try remote.addOutcomeAndWait(outcomeA)
        try local.addOutcomeAndWait(outcomeB)
        
        XCTAssertNoThrow(try local.syncAndWait())
        
        let localTasks = try local.fetchTasksAndWait()
        let localOutcomes = try local.fetchOutcomesAndWait()
        let remoteTasks = try remote.fetchTasksAndWait()
        let remoteOutcomes = try remote.fetchOutcomesAndWait()
        
        XCTAssert(localTasks == remoteTasks)
        XCTAssert(localTasks.count == 1)
        XCTAssert(localTasks.first?.title == "A")
        XCTAssert(localOutcomes == remoteOutcomes)
        XCTAssert(localOutcomes.count == 1)
    }
    
    // device ---B---C (keep)
    // remote ---A
    func testKeepEntireLocalTaskVersionChain() throws {
        let mongoRemote = IBMMongoRemote(id: "", appleId: "")
        mongoRemote.automaticallySynchronizes = false
        XCTAssertNoThrow(try performSynchronously {mongoRemote.clearRemote(completion: $0)})

        let remote = OCKStore(name: "remote", type: .inMemory, remote: mongoRemote)
        
        let endpoint = OCKStoreEndpoint(remote: remote)
        endpoint.automaticallySynchronizes = false
        endpoint.conflictPolicy = .keepDevice
        let local = OCKStore(name: "local", type: .inMemory, remote: endpoint)
        
        let schedule = OCKSchedule.dailyAtTime(hour: 1, minutes: 42, start: Date(), end: nil, text: nil)
        
        var taskA = OCKTask(id: "abc", title: "A", carePlanUUID: nil, schedule: schedule)
        taskA = try remote.addTaskAndWait(taskA)
        
        var taskB = OCKTask(id: "abc", title: "B", carePlanUUID: nil, schedule: schedule)
        taskB = try local.addTaskAndWait(taskB)
        var taskC = OCKTask(id: "abc", title: "C", carePlanUUID: nil, schedule: schedule.offset(by: .init(day: 2)))
        taskC = try local.updateTaskAndWait(taskC)
        
        let outcomeA = OCKOutcome(taskUUID: taskA.uuid!, taskOccurrenceIndex: 0, values: [])
        let outcomeB = OCKOutcome(taskUUID: taskB.uuid!, taskOccurrenceIndex: 0, values: [])
        try remote.addOutcomeAndWait(outcomeA)
        try local.addOutcomeAndWait(outcomeB)
        
        try local.syncAndWait()
        
        let localTasks = try local.fetchTasksAndWait()
        let localOutcomes = try local.fetchOutcomesAndWait()
        let remoteTasks = try remote.fetchTasksAndWait()
        let remoteOutcomes = try remote.fetchOutcomesAndWait()
        
        XCTAssert(localTasks == remoteTasks)
        XCTAssert(localTasks.count == 2)
        XCTAssert(Set(localTasks.map { $0.title }) == Set(["B", "C"]))
        XCTAssert(localOutcomes == remoteOutcomes)
        XCTAssert(localOutcomes.count == 1)
    }
    
    //    /--B--C (Keep Remote)
    // A--
    //    \__D (Overwrite Local)
    func testOverwritePartialLocalTaskVersionChain() throws {
        let mongoRemote = IBMMongoRemote(id: "", appleId: "")
        mongoRemote.automaticallySynchronizes = false
        XCTAssertNoThrow(try performSynchronously {mongoRemote.clearRemote(completion: $0)})

        let remote = OCKStore(name: "remote", type: .inMemory, remote: mongoRemote)
        
        let endpoint = OCKStoreEndpoint(remote: remote)
        endpoint.automaticallySynchronizes = false
        endpoint.conflictPolicy = .keepRemote
        let local = OCKStore(name: "local", type: .inMemory, remote: endpoint)
        
        let schedule = OCKSchedule.dailyAtTime(hour: 1, minutes: 42, start: Date(), end: nil, text: nil)
        
        var taskA = OCKTask(id: "abc", title: "A", carePlanUUID: nil, schedule: schedule)

        taskA = try remote.addTaskAndWait(taskA)
        let outcomeA = OCKOutcome(taskUUID: taskA.uuid!, taskOccurrenceIndex: 0, values: [])
        try remote.addOutcomeAndWait(outcomeA)
        
        try local.syncAndWait()
        var localTasks = try local.fetchTasksAndWait()
        var localOutcomes = try local.fetchOutcomesAndWait()
        var remoteTasks = try remote.fetchTasksAndWait()
        var remoteOutcomes = try remote.fetchOutcomesAndWait()
        XCTAssert(localTasks == remoteTasks)
        XCTAssert(localOutcomes == remoteOutcomes)
        
        var taskB = OCKTask(id: "abc", title: "B", carePlanUUID: nil, schedule: schedule.offset(by: .init(day: 1)))
        taskB = try remote.updateTaskAndWait(taskB)
        var taskC = OCKTask(id: "abc", title: "C", carePlanUUID: nil, schedule: schedule.offset(by: .init(day: 2)))
        taskC = try remote.updateTaskAndWait(taskC)
        
        var taskD = OCKTask(id: "abc", title: "D", carePlanUUID: nil, schedule: schedule.offset(by: .init(day: 1)))
        taskD = try local.updateTaskAndWait(taskD)
        let outcomeD = OCKOutcome(taskUUID: taskD.uuid!, taskOccurrenceIndex: 1, values: [])
        try local.addOutcomeAndWait(outcomeD)
        
        try local.syncAndWait()
        localTasks = try local.fetchTasksAndWait()
        localOutcomes = try local.fetchOutcomesAndWait()
        remoteTasks = try remote.fetchTasksAndWait()
        remoteOutcomes = try remote.fetchOutcomesAndWait()
        
        XCTAssert(localTasks == remoteTasks)
        XCTAssert(localTasks.count == 3)
        XCTAssert(Set(localTasks.map { $0.title }) == Set(["A", "B", "C"]))
        XCTAssert(localOutcomes == remoteOutcomes)
        XCTAssert(localOutcomes.count == 1)
    }
}

private class OCKStoreEndpoint: OCKRemoteSynchronizable {
    private let store: OCKStore
    weak var delegate: OCKRemoteSynchronizableDelegate?
    
    var lastSync = Date()
    var conflictPolicy = OCKMergeConflictResolutionPolicy.keepRemote
    var automaticallySynchronizes = true
    
    init(remote: OCKStore) {
        self.store = remote
    }
    
    func pullRevisions(
        since knowledgeVector: OCKRevisionRecord.KnowledgeVector,
        mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void,
        completion: @escaping (Error?) -> Void) {
        
        let revision = store.computeRevision(since: knowledgeVector.clock)
        mergeRevision(revision, completion)
    }
    
    func pushRevisions(
        deviceRevision: OCKRevisionRecord,
        overwriteRemote: Bool,
        completion: @escaping (Error?) -> Void) {
        
        store.mergeRevision(deviceRevision, completion: completion)
    }
    
    func chooseConflicResolutionPolicy(
        _ conflict: OCKMergeConflictDescription,
        completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
        completion(conflictPolicy)
    }
}
