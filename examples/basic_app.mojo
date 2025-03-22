from sys import path
from os import getcwd

# Add the parent directory to the path so we can import the framework
path.append(getcwd())

from src.hypermojo import HyperMojo, HTTPRequest, HTTPResponse, logging_middleware, validation_middleware
from collections import Dict, List

# Define some handler functions
fn hello_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    return HTTPResponse("Hello, World!")

fn json_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    var data = Dict[String, Any]()
    data["message"] = "Hello, JSON!"
    data["framework"] = "HyperMojo"
    return HTTPResponse().json(data)

fn item_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    let item_id = req.path_params.get("id", "unknown")
    var data = Dict[String, Any]()
    data["id"] = item_id
    data["name"] = "Item " + item_id
    return HTTPResponse().json(data)

fn main() raises:
    # Create a new HyperMojo application
    var app = HyperMojo(
        host="0.0.0.0", 
        port=8080, 
        api_title="Basic HyperMojo Example", 
        api_version="1.0.0",
        api_description="A simple example of the HyperMojo framework"
    )
    
    # Setup middleware
    var mw = List[fn(HTTPRequest, fn(HTTPRequest, Dict[String, Any]) raises -> HTTPResponse, Dict[String, Any]) raises -> HTTPResponse]()
    mw.append(logging_middleware)
    
    # Register routes
    app.get("/", hello_handler, mw)
    app.get("/json", json_handler, mw)
    app.get("/items/{id}", item_handler, mw)
    
    # Enable CORS
    app.enable_cors_middleware()
    
    # Start the server
    print("Starting HyperMojo example application...")
    app.run()

# Run the application
main()