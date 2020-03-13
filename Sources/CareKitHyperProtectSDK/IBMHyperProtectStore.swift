//
//  File.swift
//  
//
//  Created by Erik Hornberger on 3/12/20.
//

import CareKitStore

public final class IBMHyperProtectStore: OCKSynchronizedStore {
    
    public init(name: String, uri: String) throws {
        super.init(
            name: name,
            type: .onDisk,
            synchronizer: try IBMMongoEndpoint(databaseUri: uri))
    }
}
