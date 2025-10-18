# HyperMojo Application - The Main Framework Class

from sys import socket, AF_INET, SOCK_STREAM, SOL_SOCKET, SO_REUSEADDR
from collections import Dict, List
from threading import Thread
from time import time

# Main Application class implementing the Application trait
@value
struct HyperMojoApp:
    var config: AppConfig
    var router: Router
    var middleware: List[Middleware]
    var extensions: List[Extension]
    var lifecycle_hooks: List[LifecycleHook]
    var socket: socket
    var running: Bool

    fn __init__(self, config: AppConfig = AppConfig()) raises -> None:
        self.config = config
        self.router = Router()
        self.middleware = List[Middleware]()
        self.extensions = List[Extension]()
        self.lifecycle_hooks = List[LifecycleHook]()
        self.socket = socket(AF_INET, SOCK_STREAM)
        self.running = False

        # Initialize socket
        self.socket.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)

    # Application trait implementation
    fn config(self) -> AppConfig:
        return self.config

    fn router(self) -> Router:
        return self.router

    fn middleware(self) -> List[Middleware]:
        return self.middleware

    fn extensions(self) -> List[Extension]:
        return self.extensions

    fn use(self, middleware: Middleware) raises -> Self:
        self.middleware.append(middleware)
        return self

    fn register(self, extension: Extension) raises -> Self:
        self.extensions.append(extension)
        return self

    # Routing methods
    fn get(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        _ = self.router.get(path, handler, name)
        return self

    fn post(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        _ = self.router.post(path, handler, name)
        return self

    fn put(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        _ = self.router.put(path, handler, name)
        return self

    fn delete(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        _ = self.router.delete(path, handler, name)
        return self

    fn patch(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        _ = self.router.patch(path, handler, name)
        return self

    fn options(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        _ = self.router.options(path, handler, name)
        return self

    fn head(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        _ = self.router.head(path, handler, name)
        return self

    fn group(self, prefix: String) raises -> RouteGroup:
        return self.router.group(prefix)

    fn static(self, path: String, directory: String) raises -> Self:
        _ = self.router.static(path, directory)
        return self

    # Lifecycle management
    fn add_lifecycle_hook(self, hook: LifecycleHook) raises -> Self:
        self.lifecycle_hooks.append(hook)
        return self

    # Server control
    fn run(self) raises -> None:
        # Call startup hooks
        for hook in self.lifecycle_hooks:
            hook.on_startup(self)

        # Initialize extensions
        for ext in self.extensions:
            ext.initialize(self)

        # Bind and start server
        self.socket.bind((self.config.host, self.config.port))
        self.socket.listen(128)  # Increased backlog
        self.running = True

        self._log_startup()

        # Start worker threads
        var threads = List[Thread]()
        for i in range(self.config.workers):
            let thread = Thread(fn() raises { self._worker_loop() })
            threads.append(thread)
            thread.start()

        # Wait for threads (in a real implementation, you'd handle shutdown signals)
        for thread in threads:
            thread.join()

    fn shutdown(self) raises -> None:
        if not self.running:
            return

        self.running = False

        # Call shutdown hooks
        for hook in self.lifecycle_hooks:
            hook.on_shutdown(self)

        # Shutdown extensions
        for ext in self.extensions:
            ext.shutdown()

        # Close socket
        try:
            self.socket.close()
        except:
            pass

        print("HyperMojo server shut down gracefully")

    fn _worker_loop(self) raises -> None:
        while self.running:
            try:
                let client_conn = self.socket.accept()
                if client_conn:
                    let client_sock = client_conn[0]
                    let remote_addr = str(client_conn[1][0]) + ":" + str(client_conn[1][1])

                    # Handle request in separate thread
                    let thread = Thread(fn() raises { self._handle_request(client_sock, remote_addr) })
                    thread.start()
            except:
                if not self.running:
                    break
                # Log error in production

    fn _handle_request(self, client_sock: socket, remote_addr: String) raises -> None:
        try:
            let data = client_sock.recv(self.config.max_request_size).decode()
            if not data:
                client_sock.close()
                return

            let request = HTTPRequest(data, remote_addr)
            var response = HTTPResponse()
            let context = Context(self, request, response)

            # Call request hooks
            for hook in self.lifecycle_hooks:
                hook.on_request(request, context)

            # Process request
            let final_response = self._process_request(request, response, context)

            # Call response hooks
            for hook in self.lifecycle_hooks:
                hook.on_response(final_response, context)

            # Send response
            client_sock.send(final_response.to_bytes().encode())

        except error as e:
            # Call error hooks
            for hook in self.lifecycle_hooks:
                let error_obj = Error("internal_error", str(e))
                hook.on_error(error_obj, Context(self, HTTPRequest("", remote_addr), HTTPResponse()))

            # Send error response
            try:
                var error_response = HTTPResponse("Internal Server Error", 500)
                client_sock.send(error_response.to_bytes().encode())
            except:
                pass
        finally:
            try:
                client_sock.close()
            except:
                pass

    fn _process_request(self, request: HTTPRequest, response: HTTPResponse, context: Context) raises -> HTTPResponse:
        # Find matching route
        let route_match = self.router.find_route(request.method, request.path)

        if not route_match.matched:
            return response.text("Not Found", 404)

        # Set path parameters in request
        request.path_params = route_match.params

        # Build middleware chain
        var middleware_chain = List[Middleware]()

        # Add global middleware
        for mw in self.middleware:
            middleware_chain.append(mw)

        # Add route-specific middleware
        for mw in route_match.route.middleware:
            middleware_chain.append(mw)

        # Create handler chain
        var current_handler = route_match.route.handler

        # Apply middleware in reverse order (onion pattern)
        for i in range(len(middleware_chain) - 1, -1, -1):
            let mw = middleware_chain[i]
            current_handler = fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
                return mw.process(req, res, ctx, current_handler)
            }

        # Execute the handler chain
        return current_handler(request, response, context)

    fn _log_startup(self) raises -> None:
        print("🚀 HyperMojo " + self.config.version + " starting up...")
        print("📍 Server: http://" + self.config.host + ":" + str(self.config.port))
        print("⚙️  Workers: " + str(self.config.workers))
        print("🔧 Debug mode: " + ("enabled" if self.config.debug else "disabled"))
        print("📊 Routes loaded: " + str(len(self.router.get_all_routes())))

        if len(self.router.static_routes) > 0:
            print("📁 Static files configured:")
            for path in self.router.static_routes:
                print("   " + path + " -> " + self.router.static_routes[path])

        print("✅ Server ready to accept connections")
        print("Press Ctrl+C to stop")

# Factory function for creating new applications
fn create_app(name: String = "HyperMojo App", version: String = "1.0.0",
              host: String = "0.0.0.0", port: Int = 8080, debug: Bool = False) raises -> HyperMojoApp:
    var config = AppConfig(host, port, debug, name, version, "", 4, 1048576, 30)
    return HyperMojoApp(config)

# Convenience middleware factory functions
fn cors(origins: List[String] = List[String]()) raises -> CORSMiddleware:
    return CORSMiddleware(origins)

fn logging(level: String = "info") raises -> LoggingMiddleware:
    return LoggingMiddleware(level)

fn rate_limit(requests_per_minute: Int = 60, requests_per_hour: Int = 1000) raises -> RateLimitMiddleware:
    return RateLimitMiddleware(requests_per_minute, requests_per_hour)

fn compression(min_size: Int = 1024) raises -> CompressionMiddleware:
    return CompressionMiddleware(min_size)

fn auth_basic(user_store: Dict[String, String], realm: String = "Restricted Area") raises -> AuthMiddleware:
    return AuthMiddleware("basic", realm, user_store)

fn csrf() raises -> CSRFMiddleware:
    return CSRFMiddleware()

fn security() raises -> SecurityMiddleware:
    return SecurityMiddleware()

# Forward declarations
struct AppConfig: pass
struct Router: pass
struct RouteGroup: pass
struct Middleware: pass
struct Extension: pass
struct LifecycleHook: pass
struct HTTPRequest: pass
struct HTTPResponse: pass
struct Context: pass
struct HandlerFn: pass
struct CORSMiddleware: pass
struct LoggingMiddleware: pass
struct RateLimitMiddleware: pass
struct CompressionMiddleware: pass
struct AuthMiddleware: pass
struct CSRFMiddleware: pass
struct SecurityMiddleware: pass
struct Error: pass
