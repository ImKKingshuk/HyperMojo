# HyperMojo 2.0 - The Ultimate Web Framework for Mojo 🔥

<div align="center">

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**The most advanced, feature-rich web framework for the Mojo programming language**

*Built for performance, security, and developer experience*

</div>

## 🌟 What's New in 2.0

HyperMojo 2.0 is a complete rewrite with a modular architecture, advanced features, and production-ready capabilities:

- **🏗️ Modular Architecture**: Clean separation of concerns with extensible components
- **🛡️ Advanced Security**: Sessions, CSRF protection, security headers, authentication
- **⚡ High Performance**: Multi-worker architecture, compression, caching
- **📄 Template Engine**: Built-in templating with custom functions and helpers
- **📁 File Handling**: Upload, download, and static file serving with validation
- **🔧 Configuration System**: Flexible configuration management
- **📚 Auto-Documentation**: OpenAPI/Swagger integration
- **🎯 Type Safety**: Full Mojo type system utilization
- **🔌 Extension System**: Plugin architecture for custom features

## 🚀 Quick Start

```bash
# Clone and setup
git clone https://github.com/ImKKingshuk/HyperMojo.git
cd HyperMojo

# Run the ultimate demo
mojo run ultimate_demo.mojo
```

Visit `http://localhost:8080` to see all features in action!

## 📦 Installation & Setup

### Basic Usage

```mojo
from hypermojo import create_app, HTTPRequest, HTTPResponse, Context

fn hello_handler(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse:
    return res.json({"message": "Hello, HyperMojo 2.0!"})

fn main() raises:
    var app = create_app("My App", "1.0.0", "0.0.0.0", 8080)
    app.get("/", hello_handler)
    app.run()
```

### Advanced Setup

```mojo
from hypermojo import web_app, cors, logging, rate_limit, security, SessionMiddleware

fn main() raises:
    # Create a full-featured web app
    var app = web_app("My Advanced App", "1.0.0", 8080, "templates")

    # Add comprehensive middleware
    app.use(logging("info"))
    app.use(cors())
    app.use(rate_limit(100, 1000))  # 100 req/min, 1000 req/hour
    app.use(security())
    app.use(SessionMiddleware())

    # Routes with validation
    var user_schema = {
        "username": {"type": "string", "required": True},
        "email": {"type": "email", "required": True}
    }

    app.post("/users", user_handler).use(validation_middleware(user_schema))

    app.run()
```

## 🏗️ Architecture

```
hypermojo/
├── core/           # Core abstractions and interfaces
│   ├── __init__.mojo
│   ├── application.mojo
│   └── http.mojo
├── routing/        # Advanced routing system
│   ├── __init__.mojo
│   └── router.mojo
├── middleware/     # Comprehensive middleware
│   ├── __init__.mojo
│   └── cors.mojo, logging.mojo, etc.
├── handlers/       # Built-in handlers
│   ├── template.mojo
│   └── file_upload.mojo
├── security/       # Security features
│   └── sessions.mojo
├── utils/          # Utilities
│   ├── config.mojo
│   └── validation.mojo
└── extensions/     # Plugin system
```

## 🎯 Key Features

### 🔐 Security First
- **Session Management**: Secure session storage with configurable backends
- **CSRF Protection**: Automatic CSRF token validation
- **Security Headers**: Comprehensive security headers (HSTS, CSP, etc.)
- **Authentication**: Built-in auth middleware with user management
- **Rate Limiting**: Configurable request rate limiting

### 🚀 Performance
- **Multi-Worker Architecture**: Handle concurrent requests efficiently
- **Response Compression**: Automatic gzip compression
- **Static File Caching**: Intelligent caching headers
- **Connection Pooling**: Optimized connection handling

### 📄 Templates & Assets
- **Template Engine**: Django-inspired templating with custom functions
- **Static File Serving**: Efficient static file delivery
- **File Upload**: Secure file upload with validation
- **Asset Pipeline**: Ready for CSS/JS bundling

### 🔧 Developer Experience
- **Type Safety**: Full Mojo type system utilization
- **Auto-Documentation**: OpenAPI/Swagger UI integration
- **Configuration Management**: Flexible config system
- **Extension System**: Plugin architecture
- **Comprehensive Logging**: Structured logging throughout

## 📚 Examples

### REST API with Validation

```mojo
from hypermojo import api_app, validation_middleware

var app = api_app("User API", "1.0.0", 8080)

# User schema
var user_schema = {
    "username": {"type": "string", "required": True, "min_length": 3},
    "email": {"type": "email", "required": True},
    "age": {"type": "integer", "required": False, "min": 18}
}

app.post("/users", create_user_handler).use(validation_middleware(user_schema))
app.get("/users/{id}", get_user_handler)
```

### Web App with Templates

```mojo
from hypermojo import web_app, TemplateEngine

var app = web_app("Blog App", "1.0.0", 8080, "templates")

app.get("/", fn(req, res, ctx) {
    var data = {"title": "My Blog", "posts": get_recent_posts()}
    return ctx.render_template("index.html", data)
})

app.get("/post/{slug}", get_post_handler)
```

### File Upload

```mojo
from hypermojo import UploadConfig, handle_file_upload

var upload_config = UploadConfig(
    max_file_size=5242880,  # 5MB
    allowed_extensions=[".jpg", ".png", ".pdf"],
    upload_dir="uploads"
)

app.post("/upload", fn(req, res, ctx) {
    let result = handle_file_upload(req, upload_config)
    return res.json(result)
})
```

## 🔧 Configuration

```json
{
  "server": {
    "host": "0.0.0.0",
    "port": 8080,
    "workers": 4,
    "max_request_size": 1048576
  },
  "app": {
    "name": "My HyperMojo App",
    "version": "1.0.0",
    "debug": false
  },
  "security": {
    "secret_key": "your-secret-key",
    "session_timeout": 3600
  },
  "upload": {
    "max_file_size": 10485760,
    "upload_dir": "uploads"
  }
}
```

## 📖 Documentation

- [Getting Started Guide](docs/getting_started.md)
- [API Reference](docs/api_reference.md)
- [Middleware Guide](docs/middleware.md)
- [Security Guide](docs/security.md)
- [Template Guide](docs/templates.md)

## 🎮 Demo Application

Run the ultimate demo to see all features:

```bash
mojo run ultimate_demo.mojo
```

Features the demo includes:
- ✅ Advanced routing with parameters and groups
- ✅ Session management and cookies
- ✅ File upload with validation
- ✅ Template rendering
- ✅ API endpoints with validation
- ✅ Auto-generated documentation
- ✅ Security middleware
- ✅ Rate limiting
- ✅ Error handling

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md).

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with the amazing [Mojo programming language](https://www.modular.com/mojo)
- Inspired by modern web frameworks like Express.js, FastAPI, and Django



---

<div align="center">

**HyperMojo 2.0 - Redefining web development in Mojo** 🔥

*Made with ❤️ by ImKKingshuk*

</div>
