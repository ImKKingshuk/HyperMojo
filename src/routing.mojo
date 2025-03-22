from collections import Dict, List
from .http import HTTPRequest, HTTPResponse

alias HandlerFn = fn(HTTPRequest, Dict[String, Any]) raises -> HTTPResponse
alias MiddlewareFn = fn(HTTPRequest, HandlerFn, Dict[String, Any]) raises -> HTTPResponse
alias DependencyFn = fn(HTTPRequest) raises -> Dict[String, Any]

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


fn match_route(routes: List[Route], req: HTTPRequest) raises -> Optional[Route]:
    for route in routes:
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