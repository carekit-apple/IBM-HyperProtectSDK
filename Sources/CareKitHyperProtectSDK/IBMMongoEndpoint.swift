import Foundation
import CareKitStore
/*
Copyright (c) 2020, IBM, Apple Inc. All rights reserved.

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

import UIKit
import MongoKitten

private let userIDKey = "userID"
private let taskUUIDKey = "taskUUID"
private let occurenceKey = "taskOccurrenceIndex"
private let deletedDateKey = "deletedDate"

public final class IBMMongoEndpoint: OCKSyncEndpoint {
    
    private let userID: String
    private let db: MongoDatabase
    private let tasks: MongoCollection
    private let outcomes: MongoCollection
    private var transaction: MongoTransactionDatabase?
    private var pollingTimer: Timer?
    private let encoder = BSONEncoder()
    private let decoder = BSONDecoder()
    private let isDirtyKey: String
    
    public weak var delegate: OCKSyncEndpointDelegate?
    
    public init(databaseUri: String, userID: String) throws {
        self.userID = userID
        self.isDirtyKey = "isDirtyForDevice:\(UIDevice.current.identifierForVendor!.uuidString)"
        self.db = try MongoDatabase.synchronousConnect(databaseUri)
        self.tasks = self.db[String(describing: OCKTask.self)]
        self.outcomes = self.db[String(describing: OCKOutcome.self)]
        self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true, block: { [weak self] timer in
            guard let self = self else { return }
            self.delegate?.remoteEndpointRequestedSync(self)
        })
    }
    
    public func exchangeChangeSets(
        localChangeSet: OCKChangeSet,
        completion: @escaping (Result<OCKChangeSet, Error>) -> Void) {
        
        do {
            transaction = try db.startTransaction(autoCommitChanges: true)
    
            let remoteChangeSet = try currentChangeSet()
            let necessaryChanges = remoteChangeSet.resolveChanges(against: localChangeSet)
            try necessaryChanges.operations.forEach(handle)
            
            try undirtySyncedRecords()
            
            completion(.success(remoteChangeSet))
            
        } catch {
            completion(.failure(error))
        }
    }
    
    public func rollback() {
        try! transaction!.abort().wait()
        transaction = nil
    }
    
    public func commit() throws {
        try transaction?.commit().wait()
    }
    
    public func resolveConflict(
        localTask: OCKTask,
        remoteTask: OCKTask,
        affectedOutcomes: [OCKOutcome]) -> OCKConflictResolutionStrategy {
        .deleteOutcomes
    }
    
    public func resolveConflict(
        task: OCKTask,
        outcome: OCKOutcome) -> OCKConflictResolutionStrategy {
        .deleteOutcomes
    }
    
    private func currentChangeSet() throws -> OCKChangeSet {
        let dirtyTaskDocuments = try tasks.find([
            userIDKey: userID,
            isDirtyKey: true
        ]).allResults().wait()
        
        let dirtyTasks = try dirtyTaskDocuments.map { try decoder.decode(OCKTask.self, from: $0) }
        let taskRecords = dirtyTasks.map { task in
            OCKChangeRecord(
                operation: .add,
                entity: .task(task),
                date: task.createdDate!)
        }
        
        let dirtyOutcomeDocuments = try outcomes.find([
            userIDKey: userID,
            isDirtyKey: true
        ]).allResults().wait()
        
        let outcomeRecords = try dirtyOutcomeDocuments.map { doc -> OCKChangeRecord in
            let deletedDate = doc[deletedDateKey] as? Date
            let outcome = try decoder.decode(OCKOutcome.self, from: doc)
            return OCKChangeRecord(
                operation: deletedDate == nil ? .add : .delete ,
                entity: .outcome(outcome),
                date: deletedDate == nil ? outcome.createdDate! : deletedDate!)
        }
        
        return OCKChangeSet(operations: taskRecords + outcomeRecords)
    }
    
    private func undirtySyncedRecords() throws {
        _ = try tasks.updateMany(where: [
            userIDKey: userID,
            isDirtyKey: true
        ], setting: [isDirtyKey: false], unsetting: nil).wait()
        
        _ = try outcomes.updateMany(where: [
            userIDKey: userID,
            isDirtyKey: true
        ], setting: [isDirtyKey: false], unsetting: nil).wait()
    }
    
    private func handle(_ record: OCKChangeRecord) throws {
        switch (record.entity, record.operation) {
        case let (.task(task), .add):
            var bson = try encoder.encode(task)
            bson.appendValue(false, forKey: isDirtyKey)
            bson.appendValue(userID, forKey: userIDKey)
            
            _ = try tasks.insert(bson).wait()
            
        case (.task, .delete):
            fatalError("This should never happen. Tasks are delete by adding a new version with a non-nil `deletedDate`")
            
        case let (.outcome(outcome), .add):
            var bson = try encoder.encode(outcome)
            bson.appendValue(false, forKey: isDirtyKey)
            bson.appendValue(userID, forKey: userIDKey)
            _ = try outcomes.insert(bson).wait()
            
        case let (.outcome(outcome), .delete):
            _ = try outcomes.deleteOne(where:[
                userIDKey: userID,
                taskUUIDKey: outcome.taskUUID.uuidString,
                occurenceKey: outcome.taskOccurrenceIndex
            ]).wait()
        }
    }
}
