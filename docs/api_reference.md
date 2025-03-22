# HyperMojo API Reference

This document provides detailed information about the HyperMojo API.

## Core Components

### HyperMojo

The main application class that handles routing and server operations.

```mojo
HyperMojo(
    host: String = "0.0.0.0",
    port: Int = 8080,
    api_title: String = "HyperMojo API",
    api_version: String = "1.0.0",
    api_description: String = "A HyperMojo API"
) raises -> None
```

#### Methods

- `get(path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[DependencyFn]()) raises -> None`
- `post(path: String, handler: HandlerFn, middleware: List[MiddlewareFn] = List[MiddlewareFn](), dependencies: List[DependencyFn] = List[
