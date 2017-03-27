[![Build Status - Develop](https://travis-ci.org/IBM-Swift/Swift-cfenv.svg?branch=develop)](https://travis-ci.org/IBM-Swift/Swift-cfenv)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)

# Swift-cfenv

The Swift-cfenv package provides structures and methods to parse Cloud Foundry-provided configuration variables, such as the port number, IP address, and URL of the application. It also provides default values when running the application locally.

This library determines if you are running your application "locally" or on the cloud (i.e. as a Cloud Foundry application), based on whether the `VCAP_APPLICATION` configuration variable is set. If not set, it is assumed you are running in "local" mode instead of "cloud mode".

For the implementation of this Swift package, we used as inspiration a similar module that had been developed for Node.js applications, [node-cfenv](https://github.com/cloudfoundry-community/node-cfenv).

## Swift version
The latest version of Swift-cfenv works with the `3.0.2` version of the Swift binaries. You can download this version of the Swift binaries by following this [link](https://swift.org/download/#snapshots).

## Configuration
The latest version of Swift-cfenv relies on the [Configuration](https://github.com/IBM-Swift/Configuration) package to load and merge configuration data from multiple sources, such as environment variables or JSON files. In previous versions of Swift-cfenv, the library was responsible for accessing the environment variables directly. Moving forward, newer versions of Swift-cfenv will continue to depend on the configuration data loaded into a `ConfigurationManager` instance. For further details on the Configuration package, see its [README](https://github.com/IBM-Swift/Configuration) file.

## Usage
To leverage the Swift-cfenv package in your Swift application, you should specify a dependency for it in your `Package.swift` file:

```swift
 import PackageDescription

 let package = Package(
     name: "MyAwesomeSwiftProject",

     ...

     dependencies: [
         .Package(url: "https://github.com/IBM-Swift/Swift-cfenv.git", majorVersion: 3),

         ...

     ])
 ```

 Once the Package.swift file of your application has been updated accordingly, you can import the `CloudFoundryEnv` and `Configuration` modules in your code:

```swift
import Configuration
import CloudFoundryEnv

...

let configFileURL: URL = ...

...

let configManager = ConfigurationManager()
// To load configuration data from a file or environment variables:
//configManager.load(url: configFileURL)
//             .load(.environmentVariables)

// Use the given port and binding host values to create a socket for our server...
let ip: String = configManager.bind
let port: Int = configManager.port

...

// Once the server starts, print the url value
print("Server is starting on \(configManager.url).")
```

The code snippet above gets the binding host and port values through the [`ConfigurationManager`](#configurationmanager) object, which your Swift application creates and populates according to its needs (e.g. a JSON file, environment variables, etc.). Swift-cfenv queries the `ConfigurationManager` instance to obtain those configuration properties that pertain to Cloud Foundry. These values are then used for binding the server. Also, the URL value for the application (also obtained from configuration properties) can be used for logging purposes as shown above.

The main purpose of this library is to simplify accessing the configuration values provided by Cloud Foundry.

## Running your application in Cloud Foundry vs. locally
The following configuration properties are set when your application is running in Cloud Foundry as environment variables:

- `VCAP_APPLICATION`
- `VCAP_SERVICES`
- `PORT`

When running in Cloud Foundry, Swift-cfenv expects these properties to be loaded in the `ConfigurationManager` instance your application instantiates.

If the `VCAP_APPLICATION` isn't found when querying `ConfigurationManager`, it is then assumed that your application is running locally. For such cases, the [`ConfigurationManager`](#configurationmanager) instance returns values that are still useful for starting your application. Therefore, this Swift package can be used when running in Cloud Foundry and when running locally.

## API
### `ConfigurationManager`
`ConfigurationManager` is a class provided by the [Configuration](https://github.com/IBM-Swift/Configuration) Swift package. Swift-cfenv simply adds extension points to this class, which gives you direct access to the Cloud Foundry configuration data. In your Swift application, you probably will first load configuration data from a local JSON file (this allows you to run locally) and then from environment variables.

If you would like to create a JSON file that your application can leverage for local development, we recommend creating one that follows the following format:

  - `name` - A string value for the name of the application. If this property is not specified in the JSON file, the `name` property of the `VCAP_APPLICATION` environment variable is used.
  - `protocol` - The protocol used in the generated URLs. It overrides the default protocol used when generating the URLs for the `ConfigurationManager` object.
  - `vcap` - JSON object that provides values when running locally for the `VCAP_APPLICATION` and `VCAP_SERVICES` environment variables. This JSON object can have an `application` field and/or a `services` field, whose values are the same as the values serialized in the `VCAP_APPLICATION` and `VCAP_SERVICES` variables. Please, note that, when running locally, the `url` and `urls` extended properties of the `ConfigurationManager` instance are not based on the `vcap` application object (it defaults to `localhost` in those cases). Also, note that the `vcap` property is ignored if not running locally.

### Extensions for `ConfigurationManager`
An instance of the `ConfigurationManager` class has the following extended properties:

- `isLocal`: Bool property is set to true if the VCAP_APPLICATION environment variable was set.
- `app`: A JSON object version of the VCAP_APPLICATION environment variable.
- `services`: A JSON object version of the VCAP_SERVICES environment variable.
- `name`: A string that contains the name of the application.
- `port`: An integer that contains the HTTP port number.
- `bind`: A string with the ip address for binding the server.
- `urls`: A string array that contains the URLs for accessing the servers.
- `url`: The first string in the urls array.

If no value can be determined for the `port` property, a default port of 8080 is assigned to it. Note that 8080 is the default port value used by applications running on [Diego](https://docs.cloudfoundry.org/running/apps-enable-diego.html).

If running locally, the protocol used for the URLs will be `http`, otherwise it will be `https`. You can override this logic by specifying a particular protocol using the `protocol` property on the `options` parameter.

If the actual hostnames cannot be determined when running on the cloud (i.e. in Cloud Foundry), the url and urls values will have `localhost` as their hostname value.

The following are the instance method extensions for a `ConfigurationManager` object:

- `getApp()`: Returns an [App](#app) object that encapsulates the properties for the [VCAP_APPLICATION](https://docs.run.pivotal.io/devguide/deploy-apps/environment-variable.html#VCAP-APPLICATION) environment variable.

- `getServices()`: Returns all services bound to the application in a dictionary. The key in the dictionary is the name of the service, while the value is a Service object. Please note that this returned value is different than the `services` property returned from the `ConfigurationManager` instance.

- `getServices(type: String)`: Returns an array of Service objects that match the value of the service `type` parameter. The `type` parameter should be the label of the service (or a regular expression to look up the service by its label).

- `getService(spec: String)`: Returns a [Service](#service) object for the specified Cloud Foundry service. The `spec` parameter should be the name of the service or a regular expression to look up the service. If there is no service that matches the `spec` parameter, this method returns nil.

- `getServiceURL(spec: String, replacements: [String:Any]?)`: Returns a service URL generated from the `VCAP_SERVICES` environment variable for the specified service or nil if service cannot be found. The `spec` parameter should be the name of the service or a regular expression to look up the service. The `replacements` parameter is a dictionary with the properties (e.g. `user`, `password`, `port`, etc.) found in Foundation's [URLComponents](https://developer.apple.com/reference/foundation/urlcomponents) class. To generate the service URL, the `url` property in the service credentials is first used to create an instance of the URLComponents object. The initial set of properties in the URLComponents instance can then be overridden by properties specified in the optional `replacements` dictionary parameter. If there is not a `url` property in the service credentials, this method returns nil. Having said this, note that you have the capability to override the `url` property in the service credentials, with a `replacements` property of `url` and a value that specifies the name of the property in the service credentials that contains the base URL. For instance, you may find this useful in the case there is no `url` property in the service credentials.

- `getServiceCreds(spec: String)`: Returns a dictionary that contains the credentials for the specified service. The `spec` parameter should be the name of the service or a regular expression to look up the service. If there is no service that matches the `spec` parameter, this method returns nil. In the case there is no credentials property for the specified service, an empty dictionary is returned.

### App
App is a structure that contains the following [`VCAP_APPLICATION`](https://docs.run.pivotal.io/devguide/deploy-apps/environment-variable.html#VCAP-APPLICATION) environment variable properties:

- `id`: A GUID string identifying the application.
- `name`: A string that contains the name assigned to the application.
- `uris`: A string array that contains the URIs assigned to the application.
- `version`: A GUID string identifying a version of the application.
- `instanceId`: A GUID string that identifies the application instance.
- `instanceIndex`: An integer that represents the index number of the instance.
- `limits`: An [App.Limits](#applimits) object that contains memory, disk, and number of files for the application instance (see below).
- `port`: An integer that contains the port number of the application instance.
- `spaceId`: A GUID string identifying the application’s space.
- `startedAtTs`: An NSTimeInterval instance that contains the Unix epoch timestamp for the time the application instance was started.
- `startedAt`: An NSDate object that contains the time when the application instance was started.

### App.Limits
The App.Limits structure contains the memory, disk, and number of files for an application instance:

- `memory`: An integer that represents memory for the application (this value is commonly specified in the manifest file).
- `disk`: An integer that represents the disk space for the application (this value is commonly specified in the manifest file).
- `fds`: An integer that represents the number of files.

### Service
Service is a class that contains the following properties for a Cloud Foundry [service](https://docs.run.pivotal.io/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES):

- `name`: A string that contains the name assigned to the service instance.
- `label`: A string that contains the name of the service offering.
- `plan` : A string that states the service plan selected when the service instance was created. If the service has no plan, the string 'N/A' is assigned to this field.
- `tags`: An array of strings that contains values to identify a service instance.
- `credentials`: An optional dictionary that contains the service credentials required to access the service instance. Note that the credential properties for accessing a service could be completely different from one to another. For instance, the credentials dictionary for a service may simply contain a `uri` property while the credentials dictionary for another service may contain a `hostname`, `username`, and `password` properties.

## Testing with Bluemix (or other Cloud Foundry PaaS)
To test this Swift library on Bluemix, you can follow the steps described in this section.

Create a dummy service named `cf-dummy-service`:

`cf cups cf-dummy-service -p "url, username, password, database"`

The Cloud Foundry command line will then prompt you for the following (please enter some reasonable values):

    url> http://swift-cfenv-service.test.com
    username> username00
    password> password00
    database> CloudantDB

Once the dummy service is created, you can clone Bluemix's [swift-helloworld](https://github.com/IBM-Bluemix/swift-helloworld) application using the following command:

`git clone https://github.com/IBM-Bluemix/swift-helloworld.git`

Then push the swift-helloworld application using the following command:

`cf push`

Once the application is successfully pushed, you need to bind the service you created previously to the new application and then restage the application:

`cf bind-service swift-helloworld cf-dummy-service`

`cf restage swift-helloworld`

After the application is restaged, you can visit the route (i.e. URL) assigned to the app and you should see the output of various Swift-cfenv invocations.

## License
This Swift package is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE).
