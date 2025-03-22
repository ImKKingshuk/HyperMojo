# Getting Started with HyperMojo

This guide will help you get started with HyperMojo, a lightweight web framework for Mojo.

## Installation

To use HyperMojo, you need to have Mojo installed on your system. Then, you can clone the repository and import the framework in your project.

```bash
git clone https://github.com/ImKKingshuk/HyperMojo.git
cd HyperMojo
```

## Basic Usage

Here's a simple example of a HyperMojo application:

```mojo
from sys import path
from os import getcwd

# Add the parent directory to the path so we can import the framework
path.append(getcwd())

from src.hypermojo import HyperMojo, HTTPRequest, HTTPResponse
from collections import Dict

# Define a handler function
fn hello_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    return HTTPResponse("Hello, World!")

fn main() raises:
    # Create a new HyperMojo application
    var app = HyperMojo(
        host="0.0.0.0",
        port=8080,
        api_title="My First HyperMojo App",
        api_version="1.0.0",
        api_description="A simple example of the HyperMojo framework"
    )

    # Register a route
    app.get("/", hello_handler)

    # Start the server
    app.run()

# Run the application
main()
```

Save this code to a file (e.g., `app.mojo`) and run it with:

```bash
mojo run app.mojo
```

Visit `http://localhost:8080` in your browser to see the "Hello, World!" message.

## Routing

HyperMojo supports various HTTP methods and path parameters:

```mojo
# Basic routes
app.get("/", root_handler)
app.post("/items", create_item_handler)
app.put("/items/{id}", update_item_handler)
app.delete("/items/{id}", delete_item_handler)

# Path parameters
fn item_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    let item_id = req.path_params.get("id", "unknown")
    return HTTPResponse("Item ID: " + item_id)

app.get("/items/{id}", item_handler)
```

## Middleware

Middleware functions can be used to process requests before they reach the handler:

```mojo
fn logging_middleware(req: HTTPRequest, next: HandlerFn, deps: Dict[String, Any]) raises -> HTTPResponse:
    print("Request: " + req.method + " " + req.path)
    return next(req, deps)

var mw = List[MiddlewareFn]()
mw.append(logging_middleware)

app.get("/", root_handler, mw)
```

## Request Validation

HyperMojo provides built-in request validation:

```mojo
var user_schema = Dict[String, Dict[String, Any]]()
user_schema["username"] = Dict[String, Any]()
user_schema["username"]["type"] = "string"
user_schema["username"]["required"] = True

user_schema["email"] = Dict[String, Any]()
user_schema["email"]["type"] = "email"
user_schema["email"]["required"] = True

var validation_mw = List[MiddlewareFn]()
validation_mw.append(validation_middleware(user_schema))

app.post("/users", user_handler, validation_mw)
```

## Static Files

Serve static files from a directory:

```mojo
let static_dir = path.join(getcwd(), "static")
app.serve_static_files(static_dir, "/static")
```

## CORS Support

Enable CORS for your application:

```mojo
# Allow all origins
app.enable_cors_middleware()

# Allow specific origins
var origins = List[String]()
origins.append("https://example.com")
app.enable_cors_middleware(origins)
```

## JSON Responses

Create JSON responses easily:

```mojo
fn json_handler(req: HTTPRequest, deps: Dict[String, Any]) raises -> HTTPResponse:
    var data = Dict[String, Any]()
    data["message"] = "Hello, JSON!"
    data["status"] = "success"
    return HTTPResponse().json(data)
```

## API Documentation

HyperMojo automatically generates OpenAPI documentation for your API. Access it at:

- `/docs` - Swagger UI
- `/openapi.json` - OpenAPI specification

## Next Steps

Check out the [examples](../examples/) directory for more complex examples and the [API Reference](api_reference.md) for detailed documentation.
