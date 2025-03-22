from sys import socket, AF_INET, SOCK_STREAM, SOL_SOCKET, SO_REUSEADDR
from collections import Dict, List, KeyError
from threading import Thread
from json import to_json, parse_json
from os import path, getcwd
from io import open
from time import time
from pathlib import Path
from base64 import encode as base64_encode  


@value
struct ValidationError:
    var field: String
    var message: String
    
    fn __init__(self, field: String, message: String) -> None:
        self.field = field
        self.message = message

@value
struct HTTPRequest:
    var method: String
    var path: String
    var query_params: Dict[String, String]
    var headers: Dict[String, String]
    var body: String
    var path_params: Dict[String, String]
    var json_body: Dict[String, Any]
    var form_data: Dict[String, String]
    var cookies: Dict[String, String]  

    fn __init__(self, raw_data: String) raises -> None:
        self.query_params = Dict[String, String]()
        self.headers = Dict[String, String]()
        self.path_params = Dict[String, String]()
        self.json_body = Dict[String, Any]()
        self.form_data = Dict[String, String]()
        self.cookies = Dict[String, String]()
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
                # Parse cookies
                if header[0] == "Cookie":
                    let cookie_parts = header[1].split("; ")
                    for cookie in cookie_parts:
                        let cookie_kv = cookie.split("=")
                        if len(cookie_kv) == 2:
                            self.cookies[cookie_kv[0]] = cookie_kv[1]
        
        if body_start != -1 and body_start < len(lines):
            self.body = "\r\n".join(lines[body_start:])
            
            # Try to parse JSON body
            if self.headers.get("Content-Type", "").startswith("application/json"):
                try:
                    self.json_body = parse_json(self.body)
                except:
                    pass  # Invalid JSON, keep json_body empty
                    
            # Parse form data
            elif self.headers.get("Content-Type", "").startswith("application/x-www-form-urlencoded"):
                let form_items = self.body.split("&")
                for item in form_items:
                    let kv = item.split("=")
                    if len(kv) == 2:
                        self.form_data[kv[0]] = kv[1]


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
        
    fn html(self, content: String, status_code: Int = 200) raises -> Self:
        var resp = HTTPResponse(content, status_code)
        resp.headers["Content-Type"] = "text/html"
        return resp
        
    fn redirect(self, url: String, status_code: Int = 302) raises -> Self:
        var resp = HTTPResponse("", status_code)
        resp.headers["Location"] = url
        return resp
        
    fn set_cookie(self, name: String, value: String, max_age: Int = 3600, 
http_only: Bool = True) raises -> Self:
        var cookie = name + "=" + value + "; Max-Age=" + str(max_age)
        if http_only:
            cookie += "; HttpOnly"
        self.headers["Set-Cookie"] = cookie
        return self

    fn to_bytes(self) raises -> String:
        var status = ""
        if self.status_code == 200:
            status = "200 OK"
        elif self.status_code == 201:
            status = "201 Created"
        elif self.status_code == 204:
            status = "204 No Content"
        elif self.status_code == 302:
            status = "302 Found"
        elif self.status_code == 400:
            status = "400 Bad Request"
        elif self.status_code == 401:
            status = "401 Unauthorized"
        elif self.status_code == 403:
            status = "403 Forbidden"
        elif self.status_code == 404:
            status = "404 Not Found"
        elif self.status_code == 500:
            status = "500 Internal Server Error"
        else:
            status = str(self.status_code) + " Status"
            
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
struct StaticFileConfig:
    var directory: String
    var url_prefix: String
    
    fn __init__(self, directory: String, url_prefix: String = "/static") -> None:
        self.directory = directory
        self.url_prefix = url_prefix

@value
struct HyperMojo:
    var routes: List[Route]
    var socket: socket
    var host: String
    var port: Int
    var static_files: Optional[StaticFileConfig]
    var enable_cors: Bool
    var cors_origins: List[String]
    var api_title: String
    var api_version: String
    var api_description: String

    fn __init__(self, host: String = "0.0.0.0", port: Int = 8080, 
                 api_title: String = "HyperMojo API", 
                 api_version: String = "1.0.0",
                 api_description: String = "A HyperMojo API") raises -> None:
        self.routes = List[Route]()
        self.socket = socket(AF_INET, SOCK_STREAM)
        self.socket.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
        self.host = host
        self.port = port
        self.socket.bind((host, port))
        self.socket.listen(5)
        self.static_files = None
        self.enable_cors = False
        self.cors_origins = List[String]()
        self.api_title = api_title
        self.api_version = api_version
        self.api_description = api_description


    fn get(self, path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[DependencyFn]()) raises -> None:
        self.routes.append(Route("GET", path, handler, middleware, dependencies))

    fn post(self, path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[DependencyFn]()) raises -> None:
        self.routes.append(Route("POST", path, handler, middleware, dependencies))
        
    fn put(self, path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[DependencyFn]()) raises -> None:
        self.routes.append(Route("PUT", path, handler, middleware, dependencies))
        
    fn delete(self, path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[DependencyFn]()) raises -> None:
        self.routes.append(Route("DELETE", path, handler, middleware, dependencies))
        
    fn patch(self, path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[DependencyFn]()) raises -> None:
        self.routes.append(Route("PATCH", path, handler, middleware, dependencies))
        
    fn options(self, path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[DependencyFn]()) raises -> None:
        self.routes.append(Route("OPTIONS", path, handler, middleware, dependencies))
        
    fn serve_static_files(self, directory: String, url_prefix: String = "/static") raises -> None:
        self.static_files = StaticFileConfig(directory, url_prefix)
        
    fn enable_cors_middleware(self, origins: List[String] = List[String]()) raises -> None:
        self.enable_cors = True
        self.cors_origins = origins


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
        spec["info"]["title"] = self.api_title
        spec["info"]["version"] = self.api_version
        spec["info"]["description"] = self.api_description
        spec["servers"] = List[Dict[String, Any]]()
        
        var server = Dict[String, Any]()
        server["url"] = "http://" + self.host + ":" + str(self.port)
        server["description"] = "HyperMojo Server"
        spec["servers"].append(server)
        
        spec["paths"] = Dict[String, Any]()
        for route in self.routes:
            var path_dict = Dict[String, Any]()
            if spec["paths"].contains_key(route.path):
                path_dict = spec["paths"][route.path]
            
            var method_dict = Dict[String, Any]()
            method_dict["summary"] = "Endpoint for " + route.path
            method_dict["operationId"] = route.method.lower() + "_" + route.path.replace("/", "_").replace("{", "").replace("}", "")
            
            # Add parameters for path params
            var parameters = List[Dict[String, Any]]()
            let path_parts = route.path.split("/")
            for part in path_parts:
                if part.startswith("{") and part.endswith("}"):
                    var param = Dict[String, Any]()
                    param["name"] = part[1:-1]
                    param["in"] = "path"
                    param["required"] = True
                    param["schema"] = Dict[String, Any]()
                    param["schema"]["type"] = "string"
                    parameters.append(param)
            
            if len(parameters) > 0:
                method_dict["parameters"] = parameters
            
            # Add responses
            method_dict["responses"] = Dict[String, Any]()
            method_dict["responses"]["200"] = Dict[String, Any]()
            method_dict["responses"]["200"]["description"] = "Successful response"
            method_dict["responses"]["400"] = Dict[String, Any]()
            method_dict["responses"]["400"]["description"] = "Bad request"
            method_dict["responses"]["404"] = Dict[String, Any]()
            method_dict["responses"]["404"]["description"] = "Not found"
            
            path_dict[route.method.lower()] = method_dict
            spec["paths"][route.path] = path_dict
        
        return spec


    fn serve_static_file(self, req: HTTPRequest) raises -> Optional[HTTPResponse]:
        if not self.static_files:
            return None
            
        if not req.path.startswith(self.static_files.value().url_prefix):
            return None
            
        # Extract the file path from the URL
        let rel_path = req.path[len(self.static_files.value().url_prefix):]
        let file_path = path.join(self.static_files.value().directory, rel_path)
        
        # Check if file exists
        if not path.exists(file_path):
            return None
            
        # Read the file content
        try:
            let file = open(file_path, "r")
            let content = file.read()
            file.close()
            
            # Determine content type based on file extension
            var content_type = "application/octet-stream"
            if file_path.endswith(".html"):
                content_type = "text/html"
            elif file_path.endswith(".css"):
                content_type = "text/css"
            elif file_path.endswith(".js"):
                content_type = "application/javascript"
            elif file_path.endswith(".json"):
                content_type = "application/json"
            elif file_path.endswith(".png"):
                content_type = "image/png"
            elif file_path.endswith(".jpg") or file_path.endswith(".jpeg"):
                content_type = "image/jpeg"
            elif file_path.endswith(".gif"):
                content_type = "image/gif"
            elif file_path.endswith(".svg"):
                content_type = "image/svg+xml"
            
            var response = HTTPResponse(content)
            response.headers["Content-Type"] = content_type
            return response
        except:
            return None
    
    fn apply_cors_headers(self, response: HTTPResponse) raises -> None:
        if not self.enable_cors:
            return
            
        # Set CORS headers
        if len(self.cors_origins) > 0:
            response.headers["Access-Control-Allow-Origin"] = self.cors_origins[0]  # For simplicity, use first origin
        else:
            response.headers["Access-Control-Allow-Origin"] = "*"
            
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS, PATCH"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        response.headers["Access-Control-Max-Age"] = "86400"  # 24 hours
    
    fn handle_client(self, client_sock: socket) raises -> None:
        let data = client_sock.recv(4096).decode()  # Increased buffer size
        let req = HTTPRequest(data)
        var response: HTTPResponse
        
        # Handle preflight CORS requests
        if self.enable_cors and req.method == "OPTIONS":
            response = HTTPResponse("", 204)  # No content
            self.apply_cors_headers(response)
            client_sock.send(response.to_bytes().encode())
            client_sock.close()
            return
        
        # Try to serve static files first
        let static_response = self.serve_static_file(req)
        if static_response:
            self.apply_cors_headers(static_response.value())
            client_sock.send(static_response.value().to_bytes().encode())
            client_sock.close()
            return
        
        # Handle API documentation
        if req.path == "/openapi.json":
            response = HTTPResponse().json(self.openapi())
        elif req.path == "/docs":
            # Serve Swagger UI
            let html = """
<!DOCTYPE html>
<html>
<head>
    <title>HyperMojo API Documentation</title>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" type="text/css" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css" />
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js" charset="UTF-8"> </script>
    <script>
        window.onload = function() {
            window.ui = SwaggerUIBundle({
                url: "/openapi.json",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIBundle.SwaggerUIStandalonePreset
                ],
                layout: "BaseLayout"
            });
        }
    </script>
</body>
</html>
            """
            response = HTTPResponse(html)
            response.headers["Content-Type"] = "text/html"
        else:
            # Try to match a route
            let route = self.match_route(req)
            if route:
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
        
        # Apply CORS headers to all responses
        self.apply_cors_headers(response)
        client_sock.send(response.to_bytes().encode())
        client_sock.close()

    fn run(self) raises -> None:
        print("HyperMojo server running at http://" + self.host + ":" + str(self.port))
        print("API Documentation available at http://" + self.host + ":" + str(self.port) + "/docs")
        print("OpenAPI spec at http://" + self.host + ":" + str(self.port) + "/openapi.json")
        
        if self.static_files:
            print("Serving static files from '" + self.static_files.value().directory + "' at '" + self.static_files.value().url_prefix + "'")
        
        if self.enable_cors:
            print("CORS middleware enabled")
            
        print("Press Ctrl+C to stop the server")
        
        while True:
            let client = self.socket.accept()
            let thread = Thread(fn() raises { self.handle_client(client[0]) })
            thread.start()


fn validate_field(value: String, field_type: String, required: Bool = True) raises -> Tuple[Bool, String, Any]:
    # Check if required field is missing
    if required and value == "":
        return (False, "Field is required", None)
    
    # If not required and empty, return success with None
    if not required and value == "":
        return (True, "", None)
    
    # Validate based on type
    if field_type == "string":
        return (True, "", value)
    elif field_type == "integer":
        if value.isdigit():
            return (True, "", atol(value))
        else:
            return (False, "Must be an integer", None)
    elif field_type == "number" or field_type == "float":
        try:
            let num = atof(value)
            return (True, "", num)
        except:
            return (False, "Must be a number", None)
    elif field_type == "boolean":
        if value.lower() == "true":
            return (True, "", True)
        elif value.lower() == "false":
            return (True, "", False)
        else:
            return (False, "Must be true or false", None)
    elif field_type == "email":
        # Simple email validation
        if "@" in value and "." in value:
            return (True, "", value)
        else:
            return (False, "Invalid email format", None)
    else:
        # Default to string for unknown types
        return (True, "", value)

fn validate_request_data(req: HTTPRequest, schema: Dict[String, Dict[String, Any]]) raises -> Tuple[Bool, List[ValidationError], Dict[String, Any]]:
    var errors = List[ValidationError]()
    var validated_data = Dict[String, Any]()
    
    # Determine the source of data based on content type
    var data_source: Dict[String, String]
    if req.method == "GET":
        data_source = req.query_params
    elif req.headers.get("Content-Type", "").startswith("application/json"):
        # For JSON data, we need to extract string values from the parsed JSON
        data_source = Dict[String, String]()
        for key in req.json_body:
            data_source[key] = str(req.json_body[key])
    elif req.headers.get("Content-Type", "").startswith("application/x-www-form-urlencoded"):
        data_source = req.form_data
    else:
        # Default to query params if content type is not recognized
        data_source = req.query_params
    
    # Validate each field in the schema
    for field_name in schema:
        let field_schema = schema[field_name]
        let required = field_schema.get("required", True)
        let field_type = field_schema.get("type", "string")
        
        let value = data_source.get(field_name, "")
        let validation_result = validate_field(value, field_type, required)
        
        if validation_result[0]:  # If validation passed
            if validation_result[2] != None:  # If value is not None
                validated_data[field_name] = validation_result[2]
        else:  # If validation failed
            errors.append(ValidationError(field_name, validation_result[1]))
    
    return (len(errors) == 0, errors, validated_data)

fn validation_middleware(schema: Dict[String, Dict[String, Any]]) raises -> MiddlewareFn:
    return fn(req: HTTPRequest, next: HandlerFn, deps: Dict[String, Any]) raises -> HTTPResponse:
        let validation_result = validate_request_data(req, schema)
        if not validation_result[0]:  # If validation failed
            var error_data = Dict[String, Any]()
            error_data["detail"] = "Validation Error"
            var error_list = List[Dict[String, String]]()
            
            for error in validation_result[1]:
                var error_dict = Dict[String, String]()
                error_dict["field"] = error.field
                error_dict["message"] = error.message
                error_list.append(error_dict)
            
            error_data["errors"] = error_list
            return HTTPResponse().json(error_data, 422)  # Unprocessable Entity
        
        # Add validated data to deps
        deps["validated_data"] = validation_result[2]
        return next(req, deps)

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

fn user_validation_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    # Access validated data from the validation middleware
    let validated_data = deps.get("validated_data", Dict[String, Any]())
    
    var response_data = Dict[String, Any]()
    response_data["message"] = "User created successfully"
    response_data["user"] = validated_data
    
    return HTTPResponse().json(response_data, 201)

fn static_file_demo_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    return HTTPResponse().html("""
    <!DOCTYPE html>
    <html>
    <head>
        <title>HyperMojo Static File Demo</title>
        <link rel="stylesheet" href="/static/styles.css">
    </head>
    <body>
        <h1>HyperMojo Static File Demo</h1>
        <p>This page demonstrates static file serving in HyperMojo.</p>
        <img src="/static/logo.svg" alt="Logo" width="200">
        <script src="/static/script.js"></script>
    </body>
    </html>
    """)

fn main() raises:
    # Create app with custom settings
    var app = HyperMojo(
        host="0.0.0.0", 
        port=8080, 
        api_title="HyperMojo Demo API", 
        api_version="1.0.0",
        api_description="A demonstration of HyperMojo features"
    )
    
    # Setup middleware
    var mw = List[MiddlewareFn]()
    mw.append(logging_middleware)
    
    # Setup dependencies
    var deps = List[DependencyFn]()
    deps.append(auth_dep)
    
    # Enable CORS
    app.enable_cors_middleware()
    
    # Setup static file serving
    let static_dir = path.join(getcwd(), "static")
    app.serve_static_files(static_dir)
    
    # Create static directory and demo files if they don't exist
    if not path.exists(static_dir):
        Path(static_dir).mkdir()
        
        # Create a simple CSS file
        let css_file = open(path.join(static_dir, "styles.css"), "w")
        css_file.write("""
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        p {
            color: #34495e;
        }
        """)
        css_file.close()
        
        # Create a simple JavaScript file
        let js_file = open(path.join(static_dir, "script.js"), "w")
        js_file.write("""
        document.addEventListener('DOMContentLoaded', function() {
            console.log('HyperMojo static file demo loaded!');
            const p = document.createElement('p');
            p.textContent = 'This text was added by JavaScript!';
            document.body.appendChild(p);
        });
        """)
        js_file.close()
        
        # Create a simple SVG logo
        let svg_file = open(path.join(static_dir, "logo.svg"), "w")
        svg_file.write("""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
            <rect x="10" y="10" width="80" height="80" fill="#3498db" rx="10" ry="10" />
            <text x="50" y="55" font-family="Arial" font-size="16" fill="white" text-anchor="middle">HyperMojo</text>
            <path d="M30,70 L70,70" stroke="white" stroke-width="3" />
        </svg>
        """)
        svg_file.close()
    
    # Basic routes
    app.get("/", root_handler, mw, deps)
    app.get("/items/{id}", item_handler, mw, deps)
    app.post("/items", create_item_handler, mw, deps)
    
    # Static file demo route
    app.get("/static-demo", static_file_demo_handler)
    
    # Validation demo route
    var user_schema = Dict[String, Dict[String, Any]]()
    user_schema["username"] = Dict[String, Any]()
    user_schema["username"]["type"] = "string"
    user_schema["username"]["required"] = True
    
    user_schema["email"] = Dict[String, Any]()
    user_schema["email"]["type"] = "email"
    user_schema["email"]["required"] = True
    
    user_schema["age"] = Dict[String, Any]()
    user_schema["age"]["type"] = "integer"
    user_schema["age"]["required"] = False
    
    var validation_mw = List[MiddlewareFn]()
    validation_mw.append(validation_middleware(user_schema))
    validation_mw.append(logging_middleware)
    
    app.post("/users", user_validation_handler, validation_mw, deps)
    
    # Start the server
    app.run()