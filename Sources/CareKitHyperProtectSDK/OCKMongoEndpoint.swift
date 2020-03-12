import Foundation
import CareKitStore
import MongoKitten

public final class OCKMongoEndpoint: OCKSyncEndpoint {
    
    private let db: MongoDatabase
    private let tasks: MongoCollection
    private let outcomes: MongoCollection
    private var transaction: MongoTransactionDatabase?
    private let encoder = BSONEncoder()
    private let decoder = BSONDecoder()
    private let isDirty = "isDirty"
    
    public init(databaseUri: String) throws {
        self.db = try MongoDatabase.synchronousConnect(databaseUri)
        self.tasks = self.db[String(describing: OCKTask.self)]
        self.outcomes = self.db[String(describing: OCKOutcome.self)]
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
        let dirtyTaskDocuments = try tasks.find([isDirty: true]).allResults().wait()
        let dirtyTasks = try dirtyTaskDocuments.map { try decoder.decode(OCKTask.self, from: $0) }
        let taskRecords = dirtyTasks.map { task in
            OCKChangeRecord(
                operation: .add,
                entity: .task(task),
                date: task.createdDate!)
        }
        
        let dirtyOutcomeDocuments = try outcomes.find([isDirty: true]).allResults().wait()
        let outcomeRecords = try dirtyOutcomeDocuments.map { doc -> OCKChangeRecord in
            let deletedDate = doc["deletedDate"] as? Date
            let outcome = try decoder.decode(OCKOutcome.self, from: doc)
            return OCKChangeRecord(
                operation: deletedDate == nil ? .add : .delete ,
                entity: .outcome(outcome),
                date: deletedDate == nil ? outcome.createdDate! : deletedDate!)
        }
        
        return OCKChangeSet(operations: taskRecords + outcomeRecords)
    }
    
    private func undirtySyncedRecords() throws {
        _ = try tasks.updateMany(where: [isDirty: true], setting: [isDirty: false], unsetting: nil).wait()
        _ = try outcomes.updateMany(where: [isDirty: true], setting: [isDirty: false], unsetting: nil).wait()
    }
    
    private func handle(_ record: OCKChangeRecord) throws {
        switch (record.entity, record.operation) {
        case let (.task(task), .add):
            var bson = try encoder.encode(task)
            bson.appendValue(false, forKey: isDirty)
            _ = try tasks.insert(bson).wait()
            
        case (.task, .delete):
            fatalError("This should never happen. Tasks are delete by adding a new version with a non-nil `deletedDate`")
            
        case let (.outcome(outcome), .add):
            var bson = try encoder.encode(outcome)
            bson.appendValue(false, forKey: isDirty)
            _ = try outcomes.insert(bson).wait()
            
        case let (.outcome(outcome), .delete):
            _ = try outcomes.deleteOne(where:[
                "taskUUID": outcome.taskUUID.uuidString,
                "taskOccurrenceIndex": outcome.taskOccurrenceIndex
            ]).wait()
        }
    }
}
