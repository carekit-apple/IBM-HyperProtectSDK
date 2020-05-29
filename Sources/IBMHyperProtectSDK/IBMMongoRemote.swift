/*
Copyright (c) 2019, International Business Machines. All rights reserved.

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
    private let url: String
    private let timeout: TimeInterval
    
    private var urlSession: URLSession
    
    private enum Method : String {
        case GET
        case POST
        case DELETE
        case PATCH
    }
    
    ///
    /// - Parameters:
    ///   - apiLocation: uri format (https://ip:port)
    ///   - certificate: name of the authentication challenge certificate saved to the project directory ('der' filetype)
    ///   - apiTimeOut: timeout
    ///   - appleId: Apple ID  used for authentication and authorization
    public init(apiLocation : String = "http://localhost:3000/", certificate : String = "carekit-root", apiTimeOut : TimeInterval = 2){
        self.url = apiLocation
        self.timeout = apiTimeOut
        
        let urlSessionDelegate = IBMMongoRemoteURLSessionDelegate(certificate: certificate)
        urlSession = URLSession(configuration: .default, delegate: urlSessionDelegate, delegateQueue: nil)
    }
    
    // MARK: OCKRemoteSynchronizable
    
    public weak var delegate: OCKRemoteSynchronizationDelegate?
    
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
    
    public func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
         completion(.keepDevice)
    }
    
    // MARK: Internal
    
    /// Makes POST/PUT/PATCH calls to the backend with payload. Note, PUT calls are idempotent, POST/PATCH calls are not
    /// - Parameters:
    ///   - data: body of call (type OCKxxx)
    ///   - method: POST/PUT/PATCH method
    ///   - completion: HTTP Status Code or error
    private func pushToBackend<F: Fetchable>(with data: F,
    using method: Method,
    completion: @escaping (Result<HTTPStatusCode, Error>) -> Void) {
        debugPrint("PUT CALLED")
        assert(method != .GET && method != .DELETE, "Cannot push using the GET/DELETE methods")
        let urlString = url + F.endpoint
        var request = URLRequest(url:  URL(string: urlString)!)
        
        request.httpMethod = method.rawValue
        request.httpBody = try! JSONEncoder().encode(data)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let outputStr = String(data: request.httpBody!, encoding: String.Encoding.utf8) as String?
        debugPrint("Pushing this JSON to backend :" + outputStr!)
        
        let requestTask = urlSession.dataTask(with: request) {
            (data: Data?, response: URLResponse?, error: Error?) in
            
            guard let response = response as? HTTPURLResponse,
                error == nil else {
                    completion(.failure(HTTPStatusCode.noResponse))
                    return
            }
            
            guard (200 ... 299) ~= response.statusCode else { // check for http errors
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
    private func pullFromBackend<F: Fetchable>(
        _ fetchable: F.Type,
        since knowledgeVector: OCKRevisionRecord.KnowledgeVector? = nil,
        completion: @escaping (Result<F, Error>) -> Void) {
        debugPrint("GET CALLED")

        let urlString = url + F.endpoint
        var requestURL = URL(string: urlString)
        //var result: F? = nil
        
        if let knowledgeVector = knowledgeVector {
            requestURL?.appendQueryItem(name: "knowledgeVector", value: try! String(data: JSONEncoder().encode(knowledgeVector), encoding: .utf8))
        }

        var request = URLRequest(url: requestURL!)
        request.httpMethod = Method.GET.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        debugPrint(request)
        
        let requestTask = urlSession.dataTask(with: request) {
            (data: Data?, response: URLResponse?, error: Error?) in
            guard let data = data,
                let response = response as? HTTPURLResponse,
                error == nil else { // check for networking error
                    debugPrint(error.debugDescription)
                    completion(.failure(HTTPStatusCode.noResponse))
                    return
            }
            
            guard (200 ... 299) ~= response.statusCode else {
                completion(.failure(HTTPStatusCode.init(rawValue: response.statusCode)!))
                return
            }
            
            do {
                let outputStr = String(data: data, encoding: String.Encoding.utf8) as String?
                debugPrint("JSON returned : \n" + outputStr!)
                let result = try JSONDecoder().decode(F.self, from: data)
                
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
        
        requestTask.resume()
    }
}

private final class IBMMongoRemoteURLSessionDelegate: NSObject, URLSessionDataDelegate {
    private var certificate: String
    
    init(certificate: String) {
        self.certificate = certificate
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let protectionSpace = challenge.protectionSpace
        
        guard let serverTrust = protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard let certPath = Bundle.main.path(forResource: certificate, ofType: "der") else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let certData = NSData(contentsOfFile: certPath)
        let cert = SecCertificateCreateWithData(kCFAllocatorDefault, certData!)
        SecTrustSetAnchorCertificates(serverTrust, [cert] as CFArray)
        
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
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
        debugPrint("SENDING KV JSON " + value!)
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
        
        let requestTask = urlSession.dataTask(with: request) {
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
