from sys import socket, AF_INET, SOCK_STREAM, SOL_SOCKET, SO_REUSEADDR
from collections import Dict, List, KeyError
from threading import Thread
from json import to_json, parse_json
from os import path, getcwd
from io import open
from time import time
from pathlib import Path

from .http import HTTPRequest, HTTPResponse
from .routing import Route, StaticFileConfig, match_route, HandlerFn, MiddlewareFn, DependencyFn

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
            let route = match_route(self.routes, req