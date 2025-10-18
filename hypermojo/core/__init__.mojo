# HyperMojo - Core Abstractions
# The foundation of the HyperMojo web framework

from collections import Dict, List
from json import to_json, parse_json

# Core Types and Interfaces

alias HandlerFn = fn(HTTPRequest, HTTPResponse, Context) raises -> HTTPResponse
alias MiddlewareFn = fn(HTTPRequest, HTTPResponse, Context, HandlerFn) raises -> HTTPResponse
alias ExtensionFn = fn(Application) raises -> None

# Application Configuration
@value
struct AppConfig:
    var host: String
    var port: Int
    var debug: Bool
    var name: String
    var version: String
    var description: String
    var workers: Int
    var max_request_size: Int
    var timeout: Int

    fn __init__(self,
                host: String = "0.0.0.0",
                port: Int = 8080,
                debug: Bool = False,
                name: String = "HyperMojo App",
                version: String = "1.0.0",
                description: String = "A HyperMojo web application",
                workers: Int = 4,
                max_request_size: Int = 1048576,  # 1MB
                timeout: Int = 30) -> None:
        self.host = host
        self.port = port
        self.debug = debug
        self.name = name
        self.version = version
        self.description = description
        self.workers = workers
        self.max_request_size = max_request_size
        self.timeout = timeout

# Request Context - Shared state across middleware and handlers
@value
struct Context:
    var app: Application
    var request: HTTPRequest
    var response: HTTPResponse
    var data: Dict[String, Any]
    var session: Optional[Session]
    var user: Optional[User]

    fn __init__(self, app: Application, request: HTTPRequest, response: HTTPResponse) raises -> None:
        self.app = app
        self.request = request
        self.response = response
        self.data = Dict[String, Any]()
        self.session = None
        self.user = None

    fn set(self, key: String, value: Any) raises -> None:
        self.data[key] = value

    fn get(self, key: String) raises -> Any:
        return self.data[key]

    fn has(self, key: String) raises -> Bool:
        return self.data.contains_key(key)

# Application Interface
trait Application:
    fn config(self) -> AppConfig
    fn router(self) -> Router
    fn middleware(self) -> List[Middleware]
    fn extensions(self) -> List[Extension]

    fn use(self, middleware: Middleware) raises -> Self
    fn register(self, extension: Extension) raises -> Self

    fn get(self, path: String, handler: HandlerFn, name: String = "") raises -> Self
    fn post(self, path: String, handler: HandlerFn, name: String = "") raises -> Self
    fn put(self, path: String, handler: HandlerFn, name: String = "") raises -> Self
    fn delete(self, path: String, handler: HandlerFn, name: String = "") raises -> Self
    fn patch(self, path: String, handler: HandlerFn, name: String = "") raises -> Self
    fn options(self, path: String, handler: HandlerFn, name: String = "") raises -> Self
    fn head(self, path: String, handler: HandlerFn, name: String = "") raises -> Self

    fn group(self, prefix: String) raises -> RouteGroup
    fn static(self, path: String, directory: String) raises -> Self

    fn run(self) raises -> None
    fn shutdown(self) raises -> None

# Middleware Interface
trait Middleware:
    fn name(self) -> String
    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse

# Extension Interface for Plugins
trait Extension:
    fn name(self) -> String
    fn version(self) -> String
    fn initialize(self, app: Application) raises -> None
    fn shutdown(self) raises -> None

# Lifecycle Events
trait LifecycleHook:
    fn on_startup(self, app: Application) raises -> None
    fn on_shutdown(self, app: Application) raises -> None
    fn on_request(self, request: HTTPRequest, context: Context) raises -> None
    fn on_response(self, response: HTTPResponse, context: Context) raises -> None
    fn on_error(self, error: Error, context: Context) raises -> None

# Error Handling
@value
struct Error:
    var code: String
    var message: String
    var status_code: Int
    var details: Dict[String, Any]

    fn __init__(self, code: String, message: String, status_code: Int = 500) raises -> None:
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = Dict[String, Any]()

# Forward declarations for circular dependencies
struct HTTPRequest: pass
struct HTTPResponse: pass
struct Router: pass
struct RouteGroup: pass
struct Session: pass
struct User: pass
