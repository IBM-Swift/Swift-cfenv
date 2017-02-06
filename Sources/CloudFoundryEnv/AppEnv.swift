/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
import LoggerAPI

#if os(Linux)
    #if swift(>=3.1)
        typealias RegularExpressionType = NSRegularExpression
    #else
        typealias RegularExpressionType = RegularExpression
    #endif
#else
    typealias RegularExpressionType = NSRegularExpression
#endif

public struct AppEnv {
    public let isLocal: Bool
    public let port: Int
    public let name: String?
    public let bind: String
    public let urls: [String]
    public let url: String
    public let app: [String : Any]
    public let services: [String : Any]

    /**
     * The vcap option property is ignored if not running locally.
     */
    public init(options: [String : Any]) throws {
        // NSProcessInfo.processInfo().environment returns [String : String]
        let environmentVars = ProcessInfo.processInfo.environment
        let vcapApplication = environmentVars["VCAP_APPLICATION"]
        isLocal = (vcapApplication == nil)

        // Get app
        app = try AppEnv.parseEnvVariable(isLocal: isLocal, environmentVars: environmentVars,
                                          variableName: "VCAP_APPLICATION", variableType: "application", options: options)

        // Get services
        services = try AppEnv.parseEnvVariable(isLocal: isLocal, environmentVars: environmentVars,
                                               variableName: "VCAP_SERVICES", variableType: "services", options: options)

        // Get port
        port = try AppEnv.parsePort(environmentVars: environmentVars, app: app)

        // Get name
        name = AppEnv.parseName(app: app, options: options)

        // Get bind (IP address of the application instance)
        bind = app["host"] as? String ?? "0.0.0.0"

        // Get urls
        urls = AppEnv.parseURLs(isLocal: isLocal, app: app, port: port, options: options)
        url = urls[0]
    }

    /**
     * Returns an App object.
     */
    public func getApp() -> App? {
        // Get limits
        let limits: App.Limits
        if let limitsMap = app["limits"] as? [String : Int],
            let memory = limitsMap["mem"],
            let disk = limitsMap["disk"],
            let fds = limitsMap["fds"] {
            limits = App.Limits(memory: memory, disk: disk, fds: fds)
        } else {
            return nil
        }

        // Get uris
        let uris = JSONUtils.convertJSONArrayToStringArray(json: app, fieldName: "uris")
        // Create DateUtils instance
        let dateUtils = DateUtils()

        // App instance should only be created if all required variables exist
        let appObj = App.Builder()
            .setId(id: app["application_id"] as? String)
            .setName(name: app["application_name"] as? String)
            .setUris(uris: uris)
            .setVersion(version: app["version"] as? String)
            .setInstanceId(instanceId: app["instance_id"] as? String)
            .setInstanceIndex(instanceIndex:  app["instance_index"] as? Int)
            .setLimits(limits: limits)
            .setPort(port: app["port"] as? Int)
            .setSpaceId(spaceId: app["space_id"] as? String)
            .setStartedAt(startedAt: dateUtils.convertStringToNSDate(dateString: app["started_at"] as? String))
            .build()
        return appObj
    }

    /**
     * Returns all services bound to the application in a dictionary. The key in
     * the dictionary is the name of the service, while the value is a Service
     * object that contains all the properties for the service.
     */
    public func getServices() -> [String:Service] {
        var results: [String:Service] = [:]
        for (_, servs) in services {
            if let servsArray = servs as? [[String:Any]] {
                for serv in servsArray {
                    // A service must have a name and a label
                    let tags = JSONUtils.convertJSONArrayToStringArray(json: serv, fieldName: "tags")
                    let credentials: [String:Any]? = serv["credentials"] as? [String:Any]
                    if let name: String = serv["name"] as? String,
                        let service = Service.Builder()
                            .setName(name: serv["name"] as? String)
                            .setLabel(label: serv["label"] as? String)
                            .setTags(tags: tags)
                            .setPlan(plan: serv["plan"] as? String)
                            .setCredentials(credentials: credentials)
                            .build() {
                        results[name] = service
                    }
                }
            }
        }
        return results
    }

    /**
     * Returns an array of Service objects that match the specified type. If there are
     * no services that match the type parameter, this method returns an empty array.
     */
    public func getServices(type: String) -> [Service] {
        let servs = services[type] as? [[String:Any]] ?? [[:]]
        let results = servs.map { (serv) -> Service? in
            let tags = JSONUtils.convertJSONArrayToStringArray(json: serv, fieldName: "tags")
            let credentials: [String:Any]? = serv["credentials"] as? [String:Any]
            let service = Service.Builder()
                .setName(name: serv["name"] as? String)
                .setLabel(label: serv["label"] as? String)
                .setTags(tags: tags)
                .setPlan(plan: serv["plan"] as? String)
                .setCredentials(credentials: credentials)
                .build()
            return service
        }
        return results.flatMap { $0 }
    }

    /**
     * Returns a Service object with the properties for the specified Cloud Foundry
     * service. The spec parameter should be the name of the service
     * or a regex to look up the service. If there is no service that matches the
     * spec parameter, this method returns nil.
     */
    public func getService(spec: String) -> Service? {
        let services = getServices()
        if let service = services[spec] {
            return service
        }

        do {
            let regex = try RegularExpressionType(pattern: spec, options: RegularExpressionType.Options.caseInsensitive)

            for (name, serv) in services {
                let numberOfMatches = regex.numberOfMatches(in: name, options: [], range: NSMakeRange(0, name.characters.count))
                if numberOfMatches > 0 {
                    return serv
                }
            }
        } catch let error as NSError {
            Log.error("Error code: \(error.code)")
        }
        catch {
            Log.error("Error description: \(error.localizedDescription)")
        }

        return nil
    }

    /**
     * Returns a URL generated from VCAP_SERVICES for the specified service or nil
     * if service is not found. The spec parameter should be the name of the
     * service or a regex to look up the service.
     *
     * The replacements parameter is a JSON object with the properties found in
     * Foundation's URLComponents class.
     */
    public func getServiceURL(spec: String, replacements: [String:Any]?) -> String? {
        var substitutions: [String:Any] = replacements ?? [:]
        let service = getService(spec: spec)
        guard let credentials = service?.credentials else {
            return nil
        }

        guard let url: String =
            credentials[substitutions["url"] as? String ?? "url"] as? String ?? credentials["uri"] as? String
            else {
                return nil
        }

        substitutions["url"] = nil
        guard var parsedURL = URLComponents(string: url) else {
            return nil
        }

        // Set replacements in a predefined order
        // Before, we were just iterating over the keys in the JSON object,
        // but unfortunately the order of the keys returned were different on
        // OS X and Linux, which resulted in different outcomes.
        if let user = substitutions["user"] as? String {
            parsedURL.user = user
        }
        if let password = substitutions["password"] as? String {
            parsedURL.password = password
        }
        if let port = substitutions["port"] as? Int {
            parsedURL.port = port
        }
        if let host = substitutions["host"] as? String {
            parsedURL.host = host
        }
        if let scheme = substitutions["scheme"] as? String {
            parsedURL.scheme = scheme
        }
        if let query = substitutions["query"] as? String {
            parsedURL.query = query
        }
        if let queryItems = substitutions["queryItems"] as? [[String:Any]] {
            var urlQueryItems: [URLQueryItem] = []
            for queryItem in queryItems {
                if let name = queryItem["name"] as? String {
                    let urlQueryItem = URLQueryItem(name: name, value: queryItem["value"] as? String)
                    urlQueryItems.append(urlQueryItem)
                }
            }
            if urlQueryItems.count > 0 {
                parsedURL.queryItems = urlQueryItems
            }
        }
        // These are being ignored at the moment
        // if let fragment = substitutions["fragment"].string {
        //   parsedURL.fragment = fragment
        // }
        // if let path = substitutions["path"].string {
        //   parsedURL.path = path
        // }
        return parsedURL.string
    }

    /**
     * Returns a JSON object that contains the credentials for the specified
     * Cloud Foundry service. The spec parameter should be the name of the service
     * or a regex to look up the service. If there is no service that matches the
     * spec parameter, this method returns nil. In the case there is no credentials
     * property for the specified service, an empty JSON is returned.
     */
    public func getServiceCreds(spec: String) -> [String:Any]? {
        guard let service = getService(spec: spec) else {
            return nil
        }
        if let credentials = service.credentials {
            return credentials
        } else {
            return [:]
        }
    }

    /**
     * Static method for parsing VCAP_APPLICATION and VCAP_SERVICES.
     */
    private static func parseEnvVariable(isLocal: Bool, environmentVars: [String:String],
                                         variableName: String, variableType: String, options: [String:Any]) throws
        -> [String:Any] {

            // If environment variable is found, then let's use it
            if let _ = environmentVars[variableName] {
                if let json = JSONUtils.convertStringToJSON(text: environmentVars[variableName]) {
                    return json
                }
                throw CloudFoundryEnvError.InvalidValue("Environment variable \(variableName) is not a valid JSON string!")
            }
            // If environment variable was not found, let's query options
            if let vcap = options["vcap"] as? [String:Any],
                let envVariable = vcap[variableType] as? [String:Any] {
                return envVariable
            }
            return [:]
    }

    /**
     * Static method for parsing the port number.
     */
    private static func parsePort(environmentVars: [String:String], app: [String : Any]) throws -> Int {
        let portString: String = environmentVars["PORT"] ?? environmentVars["CF_INSTANCE_PORT"] ??
            environmentVars["VCAP_APP_PORT"] ?? "8080"

        // TODO: Are there any benefits in implementing logic similar to ports.getPort() (npm module)...?
        // if portString == nil {
        //   if app["name"].string == nil {
        //     portString = "8080"
        //   }
        //   //portString = "" + (ports.getPort(appEnv.name));
        //   portString = "8080"
        // }
        //let number: Int? = (portString != nil) ? Int(portString!) : nil

        if let number = Int(portString) {
            return number
        } else {
            throw CloudFoundryEnvError.InvalidValue("Invalid PORT value: \(portString)")
        }
    }

    /**
     * Static method for parsing the name for the application.
     */
    private static func parseName(app: [String:Any], options: [String:Any]) -> String? {
        let name: String? = options["name"] as? String ?? app["name"] as? String
        // TODO: Add logic for parsing manifest.yml to get name
        // https://github.com/behrang/YamlSwift
        // http://stackoverflow.com/questions/24097826/read-and-write-data-from-text-file
        return name
    }

    /**
     * Static method for parsing the URLs for the application.
     */
    private static func parseURLs(isLocal: Bool, app: [String : Any], port: Int,
                                  options: [String:Any]) -> [String] {
        var uris: [String] = JSONUtils.convertJSONArrayToStringArray(json: app, fieldName: "uris")
        if isLocal {
            uris = ["localhost:\(port)"]
        } else {
            if uris.count == 0 {
                uris = ["localhost"]
            }
        }

        let scheme: String = options["protocol"] as? String ?? (isLocal ? "http" : "https")
        var urls: [String] = []
        for uri in uris {
            urls.append("\(scheme)://\(uri)")
        }
        return urls
    }
}
