/**
* Copyright IBM Corporation 2016,2017
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

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import XCTest
import Foundation
import LoggerAPI
import Configuration

@testable import CloudFoundryEnv

/**
* Useful online resources/tools:
* - Escape JSON: http://www.freeformatter.com/javascript-escape.html
* - Remove new lines: http://www.textfixer.com/tools/remove-line-breaks.php
* - JSON editor: http://jsonviewer.stack.hu/
*/
class MainTests: XCTestCase {

  static var allTests: [(String, (MainTests) -> () throws -> Void)] {
    return [
      ("testGetApp", testGetApp),
      ("testGetServices", testGetServices),
      ("testGetService", testGetService),
      ("testGetAppEnv", testGetAppEnv),
      ("testGetServiceURL", testGetServiceURL),
      ("testGetServiceCreds", testGetServiceCreds),
      ("testGetServicesByType", testGetServicesByType)
    ]
  }

  //var jsonOptions: [String:Any] = [:]
  let configFileURL: URL = URL(fileURLWithPath: #file).appendingPathComponent("../resources/config.json").standardized
  let configFilePath = "../resources/config.json"
  let currentPath = #file

  override func setUp() {
    super.setUp()
    //Load default config JSON
    //let filePath = URL(fileURLWithPath: #file).appendingPathComponent("../resources/config.json").standardized
    //let configData = try! Data(contentsOf: filePath)
    //jsonOptions = try! JSONSerialization.jsonObject(with: configData, options: []) as! [String:Any]
  }

  override func tearDown() {
    super.tearDown()
    //jsonOptions = [:]
  }

  func testGetApp() {
    let configManager = ConfigurationManager()
    configManager.load(url: configFileURL)
    //configManager.load(jsonOptions)
    if let app = configManager.getApp() {
      XCTAssertNotNil(app, "Configuration was not loaded from file!")
      XCTAssertEqual(app.port, 61263, "Application port number should match.")
      XCTAssertEqual(app.id, "e582416a-9771-453f-8df1-7b467f6d78e4", "Application ID value should match.")
      XCTAssertEqual(app.version, "e5e029d1-4a1a-4004-9f79-655d550183fb", "Application version number should match.")
      XCTAssertEqual(app.name, "swift-test", "App name should match.")
      XCTAssertEqual(app.instanceId, "7d4f24cfba06462ba23d68aaf1d7354a", "Application instance ID value should match.")
      XCTAssertEqual(app.instanceIndex, 0, "Application instance index value should match.")
      XCTAssertEqual(app.spaceId, "b15eb0bb-cbf3-43b6-bfbc-f76d495981e5", "Application space ID value should match.")
      let limits = app.limits
      //print("limits: \(limits)")
      //XCTAssertNotNil(limits)
      XCTAssertEqual(limits.memory, 128, "Memory value should match.")
      XCTAssertEqual(limits.disk, 1024, "Disk value should match.")
      XCTAssertEqual(limits.fds, 16384, "FDS value should match.")
      let uris = app.uris
      //XCTAssertNotNil(uris)
      XCTAssertEqual(uris.count, 1, "There should be only 1 uri in the uris array.")
      XCTAssertEqual(uris[0], "swift-test.mybluemix.net", "URI value should match.")
      XCTAssertEqual(app.name, "swift-test", "Application name should match.")
      let startedAt: Date? = app.startedAt
      XCTAssertNotNil(startedAt)
      let dateUtils = DateUtils()
      let startedAtStr = dateUtils.convertNSDateToString(nsDate: startedAt)
      XCTAssertEqual(startedAtStr, "2016-03-04 02:43:07 +0000", "Application startedAt date should match.")
      XCTAssertNotNil(app.startedAtTs, "Application startedAt ts should not be nil.")
      XCTAssertEqual(app.startedAtTs, 1457059387, "Application startedAt ts should match.")
    } else {
      XCTFail("Could not get App object!")
    }
  }

  func testGetServices() {
    let configManager = ConfigurationManager()
    configManager.load(file: configFilePath, relativeFrom: .customPath(currentPath))
    let services = configManager.getServices()
    XCTAssertEqual(services.count, 4, "There should be only 4 services in the services dictionary.")
    let name = "Cloudant NoSQL DB-kd"
    if let service = services[name] {
      XCTAssertEqual(service.name, name, "Key in dictionary and service name should match.")
      verifyService(service: service)
    } else {
      XCTFail("A service object should have been found for '\(name)'.")
    }
  }

  func testGetServicesByType() {
    let configManager = ConfigurationManager()
    configManager.load(file: configFilePath, relativeFrom: .customPath(currentPath))
    // Use exact type/label used in Bluemix
    var services: [Service] = configManager.getServices(type: "cloudantNoSQLDB")
    XCTAssertEqual(services.count, 1, "There should be only 1 service in the services array.")
    verifyService(service: services[0])
    services = configManager.getServices(type: "invalidType")
    XCTAssertEqual(services.count, 0, "There should be 0 items in the services array.")
    // Use part of type/label used in Bluemix (prefix)
    services = configManager.getServices(type: "cloudantNo")
    XCTAssertEqual(services.count, 2, "There should be only 2 services in the services array.")
    verifyService(service: services[0])
    services = configManager.getServices(type: "alertnotification")
    XCTAssertEqual(services.count, 1, "There should be only 1 service in the services array.")
  }

  func testGetService() {
    let configManager = ConfigurationManager()
    configManager.load(file: configFilePath, relativeFrom: .customPath(currentPath))
    let checkService = { (name: String) in
      if let service = configManager.getService(spec: name) {
        self.verifyService(service: service)
      } else {
        XCTFail("A service object should have been found for '\(name)'.")
      }
    }

    // Case #1
    let name = "Cloudant NoSQL DB-kd"
    checkService(name)

    // Case #2
    let regex = "Cloudant NoSQL*"
    checkService(regex)
  }

  func testGetAppEnv() {
    // Case #1 - Running locally, no options
    let configManager = ConfigurationManager()
    XCTAssertEqual(configManager.isLocal, true, "AppEnv's isLocal should be true.")
    XCTAssertEqual(configManager.port, 8080, "AppEnv's port should be 8080.")
    XCTAssertNil(configManager.name, "AppEnv's name should be nil.")
    XCTAssertEqual(configManager.bind, "0.0.0.0", "AppEnv's bind should be '0.0.0.0'.")
    var urls: [String] = configManager.urls
    XCTAssertEqual(urls.count, 1, "AppEnv's urls array should contain only 1 element.")
    XCTAssertEqual(urls[0], "http://localhost:8080", "AppEnv's urls[0] should be 'http://localhost:8080'.")
    XCTAssertEqual(configManager.services.count, 0, "AppEnv's services array should contain 0 elements.")

    // Case #2 - Running locally with options
    configManager.load(file: configFilePath, relativeFrom: .customPath(currentPath))
    XCTAssertEqual(configManager.isLocal, true, "AppEnv's isLocal should be true.")
    XCTAssertEqual(configManager.port, 8080, "AppEnv's port should be 8080.")
    XCTAssertEqual(configManager.name, "swift-test")
    XCTAssertEqual(configManager.bind, "0.0.0.0", "AppEnv's bind should be 0.0.0.0.")
    urls = configManager.urls
    XCTAssertEqual(urls.count, 1, "AppEnv's urls array should contain only 1 element.")
    XCTAssertEqual(urls[0], "http://localhost:8080", "AppEnv's urls[0] should be 'http://localhost:8080'.")
    XCTAssertEqual(configManager.services.count, 4, "AppEnv's services array should contain 4 element.")
  }

  func testGetServiceURL() {
    do {
      // Service name
      let name = "Cloudant NoSQL DB-kd"
      // Case #1 - Running locally, no options
      let configManager = ConfigurationManager()
      let serviceURL = configManager.getServiceURL(spec: name, replacements: nil)
      XCTAssertNil(serviceURL, "The serviceURL should be nil.")

      // Case #2 - Running locally with options and no replacements
      try verifyServiceURLWithOptions(name: name, replacements: nil, expectedServiceURL: "https://09ed7c8a-fae8-48ea-affa-0b44b2224ec0-bluemix:06c19ae06b1915d8a6649df5901eca85e885182421ffa9ef89e14bbc1b76efd4@09ed7c8a-fae8-48ea-affa-0b44b2224ec0-bluemix.cloudant.com")

      // Case #3 - Running locally with options and replacements
      var replacements = "{ \"user\": \"username01\", \"password\": \"passw0rd\", \"port\": 9080, \"host\": \"bluemix.ibm.com\", \"scheme\": \"https\", \"queryItems\": [ { \"name\": \"name2\", \"value\": \"value2\" }, { \"name\": \"name3\", \"value\": \"value3\" } ] }"
      try verifyServiceURLWithOptions(name: name, replacements: replacements, expectedServiceURL: "https://username01:passw0rd@bluemix.ibm.com:9080?name2=value2&name3=value3")

      // Case #4
      replacements = "{ \"user\": \"username01\", \"password\": \"passw0rd\", \"port\": 9080, \"host\": \"bluemix.ibm.com\", \"scheme\": \"https\", \"query\": \"name0=value0&name1=value1\" }"
      try verifyServiceURLWithOptions(name: name, replacements: replacements, expectedServiceURL: "https://username01:passw0rd@bluemix.ibm.com:9080?name0=value0&name1=value1")

      // Case #5
      replacements = "{ \"user\": \"username01\", \"password\": \"passw0rd\", \"port\": 9080, \"host\": \"bluemix.ibm.com\", \"scheme\": \"https\", \"query\": \"name0=value0&name1=value1\", \"queryItems\": [ { \"name\": \"name2\", \"value\": \"value2\" }, { \"name\": \"name3\", \"value\": \"value3\" } ] }"
      try verifyServiceURLWithOptions(name: name, replacements: replacements, expectedServiceURL: "https://username01:passw0rd@bluemix.ibm.com:9080?name2=value2&name3=value3")
    } catch let error as NSError {
      Log.error("Error domain: \(error.domain)")
      Log.error("Error code: \(error.code)")
      XCTFail("Could not get AppEnv object!")
    }
  }

  func testGetServiceCreds() {
      let configManager = ConfigurationManager()
      configManager.load(file: configFilePath, relativeFrom: .customPath(currentPath))
      let checkServiceCreds = { (name: String) in
        if let serviceCreds = configManager.getServiceCreds(spec: name) {
          self.verifyServiceCreds(serviceCreds: serviceCreds)
        } else {
          XCTFail("Service credentials should have been found for '\(name)'.")
        }
      }

      // Case #1
      let name = "Cloudant NoSQL DB-kd"
      checkServiceCreds(name)

      // Case #2
      let regex = "Cloudant NoSQL*"
      checkServiceCreds(regex)

      // Case #3
      let badName = "Unknown Service"
      if configManager.getServiceCreds(spec: badName) != nil {
        XCTFail("Service credentials should not have been found for '\(badName)'.")
      }

  }

  private func verifyServiceURLWithOptions(name: String, replacements: String?, expectedServiceURL: String) throws {
    let configManager = ConfigurationManager()
    configManager.load(file: configFilePath, relativeFrom: .customPath(currentPath))
    let substitutions = JSONUtils.convertStringToJSON(text: replacements)
    if let serviceURL = configManager.getServiceURL(spec: name, replacements: substitutions) {
        XCTAssertEqual(serviceURL, expectedServiceURL, "ServiceURL should match '\(expectedServiceURL)'.")
    } else {
      XCTFail("A serviceURL should have been returned!")
    }
  }

  private func verifyService(service: Service) {
    XCTAssertEqual(service.name, "Cloudant NoSQL DB-kd", "Service name should match.")
    XCTAssertEqual(service.label, "cloudantNoSQLDB", "Service label should match.")
    XCTAssertEqual(service.plan, "Shared", "Service plan should match.")
    XCTAssertEqual(service.tags.count, 3, "There should be 3 tags in the tags array.")
    XCTAssertEqual(service.tags[0], "data_management", "Service tag #0 should match.")
    XCTAssertEqual(service.tags[1], "ibm_created", "Serivce tag #1 should match.")
    XCTAssertEqual(service.tags[2], "ibm_dedicated_public", "Serivce tag #2 should match.")
    let credentials: [String:Any]? = service.credentials
    XCTAssertNotNil(credentials)
    verifyServiceCreds(serviceCreds: credentials!)
  }

  private func verifyServiceCreds(serviceCreds: [String:Any]) {
    XCTAssertEqual(serviceCreds.count, 5, "There should be 5 elements in the credentials object.")
    for (key, value) in serviceCreds {
      switch key {
        case "password":
          XCTAssertEqual((value as! String), "06c19ae06b1915d8a6649df5901eca85e885182421ffa9ef89e14bbc1b76efd4", "Password in credentials object should match.")
        case "url":
          XCTAssertEqual((value as! String), "https://09ed7c8a-fae8-48ea-affa-0b44b2224ec0-bluemix:06c19ae06b1915d8a6649df5901eca85e885182421ffa9ef89e14bbc1b76efd4@09ed7c8a-fae8-48ea-affa-0b44b2224ec0-bluemix.cloudant.com", "URL in credentials object should match.")
        case "port" :
          XCTAssertEqual((value as! Int), 443, "Port in credentials object should match.")
        case "host":
          XCTAssertEqual((value as! String), "09ed7c8a-fae8-48ea-affa-0b44b2224ec0-bluemix.cloudant.com", "Host in credentials object should match.")
        case "username":
          XCTAssertEqual((value as! String), "09ed7c8a-fae8-48ea-affa-0b44b2224ec0-bluemix", "Username in credentials object should match.")
        default:
          XCTFail("Unexpected key in credentials: \(key)")
      }
    }
  }
}
