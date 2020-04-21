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
import CareKitStore

public final class IBMMongoRemote: OCKRemoteSynchronizable {
    private var url: String
    private var timeout: Int // seconds
    private var id: String
    private var appleId: String
    private var conflictPolicy: OCKMergeConflictResolutionPolicy
    
    private enum Method : String {
        case GET
        case POST
        case DELETE
        case PATCH
    }
    
    ///
    /// - Parameters:
    ///   - id: unique id to identify patient. This will typically be OCKPatient.id
    ///   - apiLocation: uri format (https://ip:port)
    ///   - apiTimeOut: timeout
    ///   - appleId: Apple ID  used for authentication and authorization
    init(id: String,
         conflictPolicy: OCKMergeConflictResolutionPolicy = OCKMergeConflictResolutionPolicy.keepRemote,
         apiLocation: String = "http://localhost:3000/",
         apiTimeOut: Int = 2,
         appleId: String){
        self.id = id
        self.url = apiLocation
        self.timeout = apiTimeOut
        self.appleId = appleId
        self.conflictPolicy = conflictPolicy
    }
    
    // MARK: OCKRemoteSynchronizable
    
    public weak var delegate: OCKRemoteSynchronizableDelegate?
    
    public var automaticallySynchronizes: Bool = true
    
    public func pullRevisions(
        since knowledgeVector: OCKRevisionRecord.KnowledgeVector,
        mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void,
        completion: @escaping (Error?) -> Void) {

        pullFromBackend(OCKRevisionRecord.self, since : knowledgeVector) { result in
            switch result {
            case let .failure(error):
                completion(error)
            case let .success(record):
                mergeRevision(record, completion)
            }
        }
    }
    
    public func pushRevisions(
        deviceRevision: OCKRevisionRecord,
        overwriteRemote: Bool,
        completion: @escaping (Error?) -> Void) {

        pushToBackend(with: deviceRevision, using: .POST) { result in
            switch result {
            case let .failure(error):
                completion(error)
            case .success(_):
                completion(nil)
            }
        }
    }
    
    public func chooseConflicResolutionPolicy(
        _ conflict: OCKMergeConflictDescription,
        completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
        
        completion(.keepDevice)
    }
    
    // MARK: Internal
    
    /// Makes POST/PUT/PATCH calls to the backend with payload. Note, PUT calls are idempotent, POST/PATCH calls are not
    /// - Parameters:
    ///   - data: body of call (type OCKxxx)
    ///   - method: POST/PUT/PATCH method
    ///   - completion: HTTP Status Code or error
    private func pushToBackend<F: Fetchable>(with data: F, using method: Method, completion: @escaping (Result<HTTPStatusCode, Error>) -> Void) {
        //debugPrint("PUT CALLED")
        //Thread.callStackSymbols.forEach{print($0)}
        assert(method != .GET, "Cannot push using the GET method")
        
        let urlString = url + F.endpoint
        var request = URLRequest(url:  URL(string: urlString)!)
        
        request.httpMethod = method.rawValue
        request.httpBody = try! JSONEncoder().encode(data)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let outputStr = String(data: request.httpBody!, encoding: String.Encoding.utf8) as String?
        debugPrint("Input :" + outputStr!)
        
        let requestTask = URLSession.shared.dataTask(with: request) {
            (data: Data?, response: URLResponse?, error: Error?) in
            
            guard let response = response as? HTTPURLResponse,
                error == nil else {
                    completion(.failure(HTTPStatusCode.noResponse))
                    return
            }
            
            guard (200 ... 299) ~= response.statusCode else { // check for http errors
                debugPrint("statusCode should be 2xx, but is \(response.statusCode)")
                completion(.failure(HTTPStatusCode.init(rawValue: response.statusCode)!))
                return
            }
            
            if(error != nil) {
                debugPrint(error.debugDescription)
                completion(.failure(HTTPStatusCode.notFound))
            } else {
                completion(.success(HTTPStatusCode.ok))
                return
            }
        }
        
        requestTask.resume()
    }
    
    /// Makes GET calls from backend
    /// - Parameters:
    ///   - fetchable: expected type of data from GET request
    ///   - knowledgeVector: logical vector clock
    ///   - completion: object of type OCKxxx or Error
    private func pullFromBackend<F: Fetchable>(_ fetchable: F.Type, since knowledgeVector : OCKRevisionRecord.KnowledgeVector? = nil, completion: @escaping (Result<F, Error>) -> Void) {
        //debugPrint("GET CALLED")
        //Thread.callStackSymbols.forEach{print($0)}
        let urlString = url + F.endpoint
        var requestURL = URL(string: urlString)
        var result: F? = nil

        if let knowledgeVector = knowledgeVector {
            requestURL?.appendQueryItem(name: "clock", value: String(knowledgeVector.clock))
        }

        var request = URLRequest(url: requestURL!)
        request.httpMethod = Method.GET.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let requestTask = URLSession.shared.dataTask(with: request) {
            (data: Data?, response: URLResponse?, error: Error?) in
            
            guard let data = data,
                let response = response as? HTTPURLResponse,
                error == nil else { // check for networking error
                    completion(.failure(HTTPStatusCode.noResponse))
                    return
            }
            
            guard (200 ... 299) ~= response.statusCode else {
                debugPrint("statusCode should be 2xx, but is \(response.statusCode)")
                completion(.failure(HTTPStatusCode.init(rawValue: response.statusCode)!))
                return
            }
            
            if(error != nil) {
                debugPrint(error.debugDescription)
                completion(.failure(HTTPStatusCode.notFound))
                return
            } else {
                let outputStr = String(data: data, encoding: String.Encoding.utf8) as String?
                //debugPrint("JSON returned : \n" + outputStr!)
                
                // If no result found (remote is empty)
                if (outputStr == "[]") {
                    completion(.success(OCKRevisionRecord(entities: [], knowledgeVector: .init()) as! F))
                    return
                }
                
                do {
                    result = try JSONDecoder().decode(F.self, from : data)
                } catch let DecodingError.dataCorrupted(context) {
                    debugPrint(context)
                } catch let DecodingError.keyNotFound(key, context) {
                    debugPrint("Key '\(key)' not found:", context.debugDescription)
                    debugPrint("codingPath:", context.codingPath)
                } catch let DecodingError.valueNotFound(value, context) {
                    debugPrint("Value '\(value)' not found:", context.debugDescription)
                    debugPrint("codingPath:", context.codingPath)
                } catch let DecodingError.typeMismatch(type, context)  {
                    debugPrint("Type '\(type)' mismatch:", context.debugDescription)
                    debugPrint("codingPath:", context.codingPath)
                } catch {
                    debugPrint("error: ", error)
                }
                if let result = result {
                    completion(.success(result))
                } else {
                    completion(.failure(HTTPStatusCode.unprocessableEntity))
                }
            }
        }
        
        requestTask.resume()
    }
}

private protocol Fetchable: Codable {
    static var endpoint: String { get }
}
extension OCKRevisionRecord: Fetchable {
    static var endpoint: String { "revisionRecord" }
}

extension URL {
    mutating func appendQueryItem(name: String, value: String?) {
        guard var urlComponents = URLComponents(string: absoluteString) else { return }
        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []
        
        let queryItem = URLQueryItem(name: name, value: value)
        queryItems.append(queryItem)
        urlComponents.queryItems = queryItems
        
        self = urlComponents.url!
    }
}

// MARK:- Testing only
public extension IBMMongoRemote {
    func clearRemote(completion: @escaping (Error) -> Void){
        debugPrint("DELETE CALLED")
        let urlString = url + "revisionRecord/"
        let requestURL = URL(string: urlString)
        var request = URLRequest(url: requestURL!)
        
        request.httpMethod = Method.DELETE.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let requestTask = URLSession.shared.dataTask(with: request) {
            (data: Data?, response: URLResponse?, error: Error?) in
            
            guard let response = response as? HTTPURLResponse,
                error == nil else { // check for networking error
                    completion(HTTPStatusCode.noResponse)
                    return
            }
            
            guard (200 ... 299) ~= response.statusCode else {
                debugPrint("statusCode should be 2xx, but is \(response.statusCode)")
                completion(HTTPStatusCode.init(rawValue: response.statusCode)!)
                return
            }
            
            if(error != nil) {
                debugPrint(error.debugDescription)
                completion(HTTPStatusCode.noResponse)
                return
            }
            return
        }
        requestTask.resume()
    }
}

