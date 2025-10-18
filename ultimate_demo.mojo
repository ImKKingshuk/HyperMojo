# HyperMojo Ultimate Demo - Showcasing All Features

from sys import path
from os import getcwd

# Add the hypermojo package to path
path.append(getcwd())

from hypermojo import (
    web_app, api_app, demo_app,
    HTTPRequest, HTTPResponse, Context,
    cors, logging, rate_limit, compression, auth_basic, csrf, security,
    SessionMiddleware, TemplateEngine, TemplateMiddleware,
    handle_file_upload, download_file, UploadConfig,
    validate_config, Config
)
from collections import Dict, List
from time import time

fn create_ultimate_demo() raises -> HyperMojoApp:
    """Create the ultimate demo showcasing all HyperMojo features"""

    # Load configuration
    var config = Config("demo_config.json")

    # Validate configuration
    let validation_errors = validate_config(config)
    if len(validation_errors) > 0:
        print("Configuration errors:")
        for error in validation_errors:
            print("  - " + error)
        print("Using default configuration...")

    # Create web application
    var app = web_app("HyperMojo Ultimate Demo", "2.0.0", 8080, "demo_templates")

    # Enhanced middleware stack
    app.use(logging("debug"))  # Debug level logging
    app.use(rate_limit(100, 1000))  # Rate limiting
    app.use(compression())  # Response compression
    app.use(cors(List[String]("http://localhost:3000", "http://localhost:8080")))  # CORS
    app.use(security())  # Security headers
    app.use(csrf())  # CSRF protection

    # Session management
    let session_store = MemorySessionStore(300)  # 5 minute cleanup
    app.use(SessionMiddleware(session_store, "hypermojo_session", 3600))

    # Template engine
    let template_engine = TemplateEngine("demo_templates", True)
    app.use(TemplateMiddleware(template_engine))

    # Static file serving
    app.static("/assets", "demo_static")

    # API Routes Group
    let api = app.group("/api/v1")

    # Health check
    api.get("/health", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        var data = Dict[String, Any]()
        data["status"] = "healthy"
        data["version"] = "2.0.0"
        data["timestamp"] = str(int(time()))
        data["uptime"] = "demo"
        return res.json(data)
    })

    # User management with validation
    var user_schema = Dict[String, Dict[String, Any]]()
    user_schema["username"] = Dict[String, Any]("type", "string", "required", True)
    user_schema["email"] = Dict[String, Any]("type", "email", "required", True)
    user_schema["age"] = Dict[String, Any]("type", "integer", "required", False)

    api.post("/users", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        # Access validated data from middleware
        let validated_data = ctx.get("validated_data")

        var user_data = Dict[String, Any]()
        user_data["id"] = "user_" + str(int(time()))
        user_data["username"] = validated_data["username"]
        user_data["email"] = validated_data["email"]
        user_data["created_at"] = str(int(time()))

        if validated_data.contains_key("age"):
            user_data["age"] = validated_data["age"]

        return res.json(user_data, 201)
    }).use(ValidationMiddleware(user_schema))

    # Get user by ID
    api.get("/users/{id}", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        let user_id = req.param("id")

        if not user_id:
            return res.json(Dict[String, Any]("error", "User ID required"), 400)

        var user_data = Dict[String, Any]()
        user_data["id"] = user_id
        user_data["username"] = "demo_user"
        user_data["email"] = "demo@example.com"

        return res.json(user_data)
    })

    # Web Routes

    # Home page with template rendering
    app.get("/", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        var template_data = Dict[String, Any]()
        template_data["title"] = "HyperMojo Ultimate Demo"
        template_data["features"] = List[String](
            "Advanced Routing", "Middleware System", "Session Management",
            "Template Engine", "File Uploads", "Security Features",
            "Rate Limiting", "CORS Support", "API Documentation"
        )
        template_data["current_year"] = 2024

        # Session-based visit counter
        var visit_count = 1
        if ctx.session:
            let session = ctx.session.value()
            visit_count = int(session.get("visit_count") or 1)
            session.set("visit_count", visit_count + 1)

        template_data["visit_count"] = visit_count

        # Render template
        let render_func = ctx.get("render_template")
        return render_func("index.html", template_data)
    })

    # Session demo page
    app.get("/session-demo", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        if not ctx.session:
            return res.html("<h1>No Session</h1><p>Session middleware not active</p>")

        let session = ctx.session.value()

        var session_data = Dict[String, Any]()
        session_data["session_id"] = session.id
        session_data["created_at"] = session.created_at
        session_data["expires_at"] = session.expires_at
        session_data["is_new"] = session.is_new
        session_data["data"] = session.data

        return res.json(session_data)
    })

    # File upload demo
    let upload_config = UploadConfig(
        max_file_size=5242880,  # 5MB
        allowed_extensions=List[String](".jpg", ".png", ".gif", ".pdf", ".txt"),
        upload_dir="demo_uploads"
    )

    app.post("/upload", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        let upload_result = handle_file_upload(req, upload_config)

        if not upload_result["success"]:
            return res.json(Dict[String, Any]("error", "Upload failed", "details", upload_result["errors"]), 400)

        return res.json(upload_result)
    })

    app.get("/uploads/{filename}", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        let filename = req.param("filename")
        if not filename:
            return res.text("Filename required", 400)

        let file_path = "demo_uploads/" + filename
        return download_file(file_path, filename, False)  # Inline display
    })

    # Error demonstration
    app.get("/error-demo", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        # This will cause an error
        let result = 1 / 0  # Division by zero
        return res.text("This won't execute", 200)
    })

    # Redirect demo
    app.get("/old-page", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        return res.redirect("/new-page", 301)
    })

    app.get("/new-page", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        return res.html("<h1>New Page</h1><p>You've been redirected from the old page!</p>")
    })

    # Cookie demo
    app.get("/cookies", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        let visit_cookie = req.cookie("visit_count")
        var visit_count = 1
        if visit_cookie:
            visit_count = int(visit_cookie) + 1

        var cookie_data = Dict[String, Any]()
        cookie_data["cookies"] = req.cookies
        cookie_data["visit_count"] = visit_count

        let response = res.json(cookie_data)
        response.set_cookie(Cookie("visit_count", str(visit_count), 86400))  # 24 hours
        return response
    })

    # API Documentation
    app.get("/docs", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        let html = """
<!DOCTYPE html>
<html>
<head>
    <title>HyperMojo API Documentation</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css">
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script>
        window.onload = function() {
            SwaggerUIBundle({
                url: '/api/v1/openapi.json',
                dom_id: '#swagger-ui',
                presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
                layout: "BaseLayout"
            });
        }
    </script>
</body>
</html>
        """
        return res.html(html)
    })

    # OpenAPI spec
    app.get("/api/v1/openapi.json", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        # In a real implementation, this would generate the OpenAPI spec from routes
        var spec = Dict[String, Any]()
        spec["openapi"] = "3.0.0"
        spec["info"] = Dict[String, Any]()
        spec["info"]["title"] = "HyperMojo Ultimate Demo API"
        spec["info"]["version"] = "1.0.0"
        spec["servers"] = List[Dict[String, Any]]()
        var server = Dict[String, Any]()
        server["url"] = "http://localhost:8080/api/v1"
        spec["servers"].append(server)

        return res.json(spec)
    })

    return app

fn main() raises:
    print("🚀 HyperMojo Ultimate Demo")
    print("==========================")
    print("Starting the most advanced Mojo web framework demo...")
    print("")

    let app = create_ultimate_demo()

    print("✅ Features loaded:")
    print("  📊 Advanced routing with groups and parameters")
    print("  🛡️  Security middleware (CORS, CSRF, security headers)")
    print("  🚦 Rate limiting and compression")
    print("  💾 Session management with memory store")
    print("  📄 Template engine with custom functions")
    print("  📁 File upload and static file serving")
    print("  🔍 Request validation and error handling")
    print("  📚 Auto-generated API documentation")
    print("")

    print("🌐 Available endpoints:")
    print("  GET  /                    - Home page with template")
    print("  GET  /session-demo         - Session management demo")
    print("  POST /upload               - File upload demo")
    print("  GET  /api/v1/health        - Health check")
    print("  POST /api/v1/users         - Create user (with validation)")
    print("  GET  /api/v1/users/{id}    - Get user by ID")
    print("  GET  /docs                 - API documentation")
    print("  GET  /cookies              - Cookie demo")
    print("  GET  /error-demo           - Error handling demo")
    print("")

    app.run()

# Forward declarations
struct HyperMojoApp: pass
struct ValidationMiddleware: pass
