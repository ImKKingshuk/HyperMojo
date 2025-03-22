# HyperMojo

<div align="center">

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**A lightweight, high-performance web framework for Mojo 🔥**

</div>

## Overview

HyperMojo is a modern web framework for the Mojo programming language, designed to make building web applications and APIs fast and intuitive. HyperMojo provides a clean, expressive API leveraging Mojo's performance benefits.

## Features

- **Fast and Lightweight**: Built for performance using Mojo's speed and memory safety
- **Intuitive Routing**: Simple route definitions with support for path parameters
- **Middleware Support**: Built-in middleware for logging, validation, and CORS
- **JSON Handling**: Native support for JSON requests and responses
- **Form Data Processing**: Easy handling of form submissions
- **Dependency Injection**: Flexible dependency management system
- **Type Validation**: Request validation with clear error messages
- **Cookie Support**: Built-in cookie handling

## Installation

```bash
# Clone the repository
git clone https://github.com/ImKKingshuk/HyperMojo.git
cd HyperMojo
```

## Quick Start

Create a simple HyperMojo application:

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

## Documentation

For more detailed information, check out:

- [Getting Started Guide](docs/getting_started.md)
- [API Reference](docs/api_reference.md)

## Examples

Explore the [examples](examples/) directory for more complex applications:

- [Basic App](examples/basic_app.mojo): A simple API with multiple endpoints
- [Advanced App](examples/advanced_app.mojo): Demonstrates middleware, validation, and more

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Author

[ImKKingshuk](https://github.com/ImKKingshuk)
