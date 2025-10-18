# HyperMojo - The Ultimate Web Framework for Mojo
# Main entry point and public API

from .core.application import HyperMojoApp, create_app, cors, logging, rate_limit, compression, auth_basic, csrf, security
from .core.http import HTTPRequest, HTTPResponse, Cookie
from .core import Context, AppConfig, Error
from .routing import Router, RouteGroup
from .middleware import CORSMiddleware, LoggingMiddleware, RateLimitMiddleware, CompressionMiddleware, AuthMiddleware, CSRFMiddleware, SecurityMiddleware
from .security.sessions import SessionMiddleware, Session, User, MemorySessionStore
from .handlers.template import TemplateEngine, TemplateMiddleware
from .handlers.file_upload import handle_file_upload, download_file, UploadConfig, StaticFileHandler
from .utils.config import Config, validate_config, get_app_config

# Re-export main components for easy importing
__all__ = [
    # Core
    "HyperMojoApp",
    "create_app",
    "HTTPRequest",
    "HTTPResponse",
    "Context",
    "Cookie",
    "AppConfig",
    "Error",

    # Routing
    "Router",
    "RouteGroup",

    # Middleware
    "cors",
    "logging",
    "rate_limit",
    "compression",
    "auth_basic",
    "csrf",
    "security",
    "CORSMiddleware",
    "LoggingMiddleware",
    "RateLimitMiddleware",
    "CompressionMiddleware",
    "AuthMiddleware",
    "CSRFMiddleware",
    "SecurityMiddleware",

    # Sessions & Security
    "SessionMiddleware",
    "Session",
    "User",
    "MemorySessionStore",

    # Templates
    "TemplateEngine",
    "TemplateMiddleware",

    # File Handling
    "handle_file_upload",
    "download_file",
    "UploadConfig",
    "StaticFileHandler",

    # Configuration
    "Config",
    "validate_config",
    "get_app_config",
]

# Convenience functions for quick start

fn quick_start(port: Int = 8080, debug: Bool = False) raises -> HyperMojoApp:
    """Create a HyperMojo app with sensible defaults"""
    var app = create_app("QuickStart App", "1.0.0", "0.0.0.0", port, debug)

    # Add common middleware
    app.use(logging())
    app.use(cors())
    app.use(security())

    return app

fn api_app(name: String = "API App", version: String = "1.0.0", port: Int = 8080) raises -> HyperMojoApp:
    """Create a REST API app with common middleware"""
    var app = create_app(name, version, "0.0.0.0", port)

    # Add API middleware
    app.use(logging())
    app.use(cors())
    app.use(rate_limit())
    app.use(security())

    return app

fn web_app(name: String = "Web App", version: String = "1.0.0", port: Int = 8080,
           template_dir: String = "templates") raises -> HyperMojoApp:
    """Create a web app with templates and sessions"""
    var app = create_app(name, version, "0.0.0.0", port)

    # Add web app middleware
    app.use(logging())
    app.use(SessionMiddleware())
    app.use(cors())
    app.use(security())
    app.use(csrf())

    # Add template support
    let template_engine = TemplateEngine(template_dir)
    app.use(TemplateMiddleware(template_engine))

    return app

# Example usage and demo functions
fn demo_app() raises -> HyperMojoApp:
    """Create a demo app showcasing all features"""
    var app = web_app("HyperMojo Demo", "2.0.0", 8080)

    # Static files
    app.static("/static", "static")

    # Routes
    app.get("/", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        var data = Dict[String, Any]()
        data["title"] = "HyperMojo Demo"
        data["message"] = "Welcome to the ultimate Mojo web framework!"

        # Use template rendering if available
        if ctx.has("render_template"):
            let render_func = ctx.get("render_template")
            return render_func("index.html", data)
        else:
            return res.html("<h1>HyperMojo Demo</h1><p>Welcome!</p>")
    })

    # JSON API
    app.get("/api/health", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        var data = Dict[String, Any]()
        data["status"] = "healthy"
        data["timestamp"] = str(int(time()))
        return res.json(data)
    })

    # Session demo
    app.get("/session", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        if ctx.session:
            let session = ctx.session.value()
            let count = int(session.get("visit_count") or 0) + 1
            session.set("visit_count", count)

            var data = Dict[String, Any]()
            data["visit_count"] = count
            data["session_id"] = session.id
            return res.json(data)

        return res.json(Dict[String, Any]("error", "No session"))
    })

    # User management demo
    app.post("/users", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse {
        var data = Dict[String, Any]()
        data["message"] = "User created"
        data["user_id"] = "user_123"
        return res.json(data, 201)
    }).use(ValidationMiddleware(Dict[String, Dict[String, Any]](
        "username", Dict[String, Any]("type", "string", "required", True),
        "email", Dict[String, Any]("type", "email", "required", True)
    )))

    return app

# CLI helpers (for future use)
fn run_demo() raises -> None:
    """Run the demo application"""
    let app = demo_app()
    print("🚀 Starting HyperMojo Demo...")
    print("📱 Visit: http://localhost:8080")
    print("🔗 API: http://localhost:8080/api/health")
    app.run()

# Forward declarations for missing imports
struct ValidationMiddleware: pass
