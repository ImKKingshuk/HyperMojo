from sys import socket, AF_INET, SOCK_STREAM, SOL_SOCKET, SO_REUSEADDR
from collections import Dict, List
from threading import Thread
from json import to_json  


@value
struct HTTPRequest:
    var method: String
    var path: String
    var query_params: Dict[String, String]
    var headers: Dict[String, String]
    var body: String
    var path_params: Dict[String, String]  

    fn __init__(self, raw_data: String) raises -> None:
        self.query_params = Dict[String, String]()
        self.headers = Dict[String, String]()
        self.path_params = Dict[String, String]()
        self.body = ""
        
        let lines = raw_data.split("\r\n")
        if len(lines) < 1:
            self.method = ""
            self.path = "/"
            return
        
        let request_line = lines[0].split(" ")
        self.method = request_line[0]
        let full_path = request_line[1]
        
        let path_parts = full_path.split("?")
        self.path = path_parts[0]
        if len(path_parts) > 1:
            let query = path_parts[1].split("&")
            for param in query:
                let kv = param.split("=")
                if len(kv) == 2:
                    self.query_params[kv[0]] = kv[1]
        
        var body_start = -1
        for i in range(1, len(lines)):
            if lines[i] == "":
                body_start = i + 1
                break
            let header = lines[i].split(": ")
            if len(header) == 2:
                self.headers[header[0]] = header[1]
        
        if body_start != -1 and body_start < len(lines):
            self.body = "\r\n".join(lines[body_start:])


@value
struct HTTPResponse:
    var body: String
    var status_code: Int
    var headers: Dict[String, String]

    fn __init__(self, body: String, status_code: Int = 200) raises -> None:
        self.body = body
        self.status_code = status_code
        self.headers = Dict[String, String]()
        self.headers["Content-Length"] = str(len(body))
        self.headers["Content-Type"] = "text/plain"

    fn json(self, data: Dict[String, Any], status_code: Int = 200) raises -> Self:
        let json_body = to_json(data)
        var resp = HTTPResponse(json_body, status_code)
        resp.headers["Content-Type"] = "application/json"
        return resp

    fn to_bytes(self) raises -> String:
        let status = "200 OK" if self.status_code == 200 else "404 Not Found"
        var headers_str = ""
        for key in self.headers:
            headers_str += key + ": " + self.headers[key] + "\r\n"
        return "HTTP/1.1 " + status + "\r\n" + headers_str + "\r\n" + self.body


alias DependencyFn = fn(HTTPRequest) raises -> Dict[String, Any]


alias HandlerFn = fn(HTTPRequest, Dict[String, Any]) raises -> HTTPResponse


alias MiddlewareFn = fn(HTTPRequest, HandlerFn, Dict[String, Any]) raises -> HTTPResponse


@value
struct Route:
    var method: String
    var path: String
    var handler: HandlerFn
    var middleware: List[MiddlewareFn]
    var dependencies: List[DependencyFn]


@value
struct HyperMojo:
    var routes: List[Route]
    var socket: socket

    fn __init__(self, host: String = "0.0.0.0", port: Int = 8080) raises -> None:
        self.routes = List[Route]()
        self.socket = socket(AF_INET, SOCK_STREAM)
        self.socket.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
        self.socket.bind((host, port))
        self.socket.listen(5)


    fn get(self, path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[DependencyFn]()) raises -> None:
        self.routes.append(Route("GET", path, handler, middleware, dependencies))

    fn post(self, path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[DependencyFn]()) raises -> None:
        self.routes.append(Route("POST", path, handler, middleware, dependencies))


    fn match_route(self, req: HTTPRequest) raises -> Optional[Route]:
        for route in self.routes:
            let route_parts = route.path.split("/")
            let req_parts = req.path.split("/")
            if route.method == req.method and len(route_parts) == len(req_parts):
                var matches = True
                var params = Dict[String, String]()
                for i in range(len(route_parts)):
                    if route_parts[i].startswith("{") and route_parts[i].endswith("}"):
                        let param_name = route_parts[i][1:-1]
                        params[param_name] = req_parts[i]
                    elif route_parts[i] != req_parts[i]:
                        matches = False
                        break
                if matches:
                    req.path_params = params  # Store params in request
                    return route
        return None


    fn openapi(self) raises -> Dict[String, Any]:
        var spec = Dict[String, Any]()
        spec["openapi"] = "3.0.0"
        spec["info"] = Dict[String, Any]()
        spec["info"]["title"] = "HyperMojo API"
        spec["info"]["version"] = "1.0.0"
        spec["paths"] = Dict[String, Any]()
        for route in self.routes:
            var path_dict = Dict[String, Any]()
            var method_dict = Dict[String, Any]()
            method_dict["responses"] = Dict[String, Any]()
            method_dict["responses"]["200"] = Dict[String, Any]()
            method_dict["responses"]["200"]["description"] = "Successful response"
            path_dict[route.method.lower()] = method_dict
            spec["paths"][route.path] = path_dict
        return spec


    fn handle_client(self, client_sock: socket) raises -> None:
        let data = client_sock.recv(1024).decode()
        let req = HTTPRequest(data)
        let route = self.match_route(req)
        var response: HTTPResponse
        if req.path == "/openapi.json":
            response = HTTPResponse().json(self.openapi())
        elif route:
            var deps = Dict[String, Any]()
            for dep in route.value().dependencies:
                let dep_result = dep(req)
                for key in dep_result:
                    deps[key] = dep_result[key]
            var handler = route.value().handler
            for mw in route.value().middleware:
                handler = lambda r, d: mw(r, handler, d)
            response = handler(req, deps)
        else:
            response = HTTPResponse("Not Found", 404)
        client_sock.send(response.to_bytes().encode())
        client_sock.close()

    fn run(self) raises -> None:
        print("Server running at http://0.0.0.0:8080")
        print("OpenAPI spec at http://0.0.0.0:8080/openapi.json")
        while True:
            let client = self.socket.accept()
            let thread = Thread(fn() raises { self.handle_client(client[0]) })
            thread.start()


fn auth_dep(req: HTTPRequest) raises -> Dict[String, Any]:
    var result = Dict[String, Any]()
    let token = req.headers.get("Authorization", "none")
    result["user"] = "authenticated" if token != "none" else "guest"
    return result


fn logging_middleware(req: HTTPRequest, next: HandlerFn, deps: Dict[String, Any]) raises -> HTTPResponse:
    print("Request: " + req.method + " " + req.path)
    return next(req, deps)


fn root_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    let user = deps.get("user", "unknown")
    return HTTPResponse("Hello, " + user + "!", 200)

fn item_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    let item_id = req.path_params.get("id", "unknown")

    if not item_id.isdigit():
        return HTTPResponse("Invalid ID: must be numeric", 400)
    var data = Dict[String, Any]()
    data["id"] = item_id
    data["message"] = "Item fetched"
    return HTTPResponse().json(data)

fn create_item_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
  
    if not req.body:
        return HTTPResponse("Body required", 400)

    var data = Dict[String, Any]()
    data["received"] = req.body  
    return HTTPResponse().json(data, 201)

fn main() raises:
    var app = HyperMojo()
    var mw = List[MiddlewareFn]()
    mw.append(logging_middleware)
    var deps = List[DependencyFn]()
    deps.append(auth_dep)
    
    app.get("/", root_handler, mw, deps)
    app.get("/items/{id}", item_handler, mw, deps)
    app.post("/items", create_item_handler, mw, deps)
    app.run()