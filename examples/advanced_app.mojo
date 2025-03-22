from sys import path
from os import getcwd, path
from pathlib import Path

# Add the parent directory to the path so we can import the framework
path.append(getcwd())

from src.hypermojo import HyperMojo, HTTPRequest, HTTPResponse, logging_middleware, validation_middleware, ValidationError
from collections import Dict, List

# Define some handler functions
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

fn auth_dep(req: HTTPRequest) raises -> Dict[String, Any]:
    var result = Dict[String, Any]()
    let token = req.headers.get("Authorization", "none")
    result["user"] = "authenticated" if token != "none" else "guest"
    return result

fn main() raises:
    # Create app with custom settings
    var app = HyperMojo(
        host="0.0.0.0", 
        port=8080, 
        api_title="HyperMojo Advanced Demo", 
        api_version="1.0.0",
        api_description="A demonstration of advanced HyperMojo features"
    )
    
    # Setup middleware
    var mw = List[fn(HTTPRequest, fn(HTTPRequest, Dict[String, Any]) raises -> HTTPResponse, Dict[String, Any]) raises -> HTTPResponse]()
    mw.append(logging_middleware)
    
    # Setup dependencies
    var deps = List[fn(HTTPRequest) raises -> Dict[String, Any]]()
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
    
    var validation_mw = List[fn(HTTPRequest, fn(HTTPRequest, Dict[String, Any]) raises -> HTTPResponse, Dict[String, Any]) raises -> HTTPResponse]()
    validation_mw.append(validation_middleware(user_schema))
    validation_mw.append(logging_middleware)
    
    app.post("/users", user_validation_handler, validation_mw, deps)
    
    # Start the server
    print("Starting HyperMojo advanced example application...")
    app.run()

# Run the application
main()