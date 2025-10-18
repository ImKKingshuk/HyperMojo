# Advanced Routing System for HyperMojo

from collections import Dict, List
from re import match as regex_match

# Route structure with enhanced features
@value
struct Route:
    var method: String
    var path: String
    var handler: HandlerFn
    var name: String
    var middleware: List[Middleware]
    var constraints: Dict[String, String]
    var defaults: Dict[String, String]
    var metadata: Dict[String, Any]

    fn __init__(self, method: String, path: String, handler: HandlerFn,
                name: String = "", middleware: List[Middleware] = List[Middleware]()) raises -> None:
        self.method = method
        self.path = path
        self.handler = handler
        self.name = name
        self.middleware = middleware
        self.constraints = Dict[String, String]()
        self.defaults = Dict[String, String]()
        self.metadata = Dict[String, Any]()

    fn add_middleware(self, middleware: Middleware) raises -> Self:
        self.middleware.append(middleware)
        return self

    fn add_constraint(self, param: String, pattern: String) raises -> Self:
        self.constraints[param] = pattern
        return self

    fn add_default(self, param: String, value: String) raises -> Self:
        self.defaults[param] = value
        return self

    fn set_metadata(self, key: String, value: Any) raises -> Self:
        self.metadata[key] = value
        return self

# Route Match Result
@value
struct RouteMatch:
    var route: Route
    var params: Dict[String, String]
    var matched: Bool

    fn __init__(self, route: Route, params: Dict[String, String], matched: Bool) raises -> None:
        self.route = route
        self.params = params
        self.matched = matched

# Route Group for organizing routes
@value
struct RouteGroup:
    var prefix: String
    var middleware: List[Middleware]
    var routes: List[Route]
    var subgroups: List[RouteGroup]
    var name_prefix: String

    fn __init__(self, prefix: String = "", middleware: List[Middleware] = List[Middleware](),
                name_prefix: String = "") raises -> None:
        self.prefix = prefix
        self.middleware = middleware
        self.routes = List[Route]()
        self.subgroups = List[RouteGroup]()
        self.name_prefix = name_prefix

    fn add_route(self, method: String, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        let full_path = self._build_full_path(path)
        let full_name = self._build_full_name(name)
        var route = Route(method, full_path, handler, full_name)

        # Add group middleware to route
        for mw in self.middleware:
            route.add_middleware(mw)

        self.routes.append(route)
        return self

    fn get(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        return self.add_route("GET", path, handler, name)

    fn post(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        return self.add_route("POST", path, handler, name)

    fn put(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        return self.add_route("PUT", path, handler, name)

    fn delete(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        return self.add_route("DELETE", path, handler, name)

    fn patch(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        return self.add_route("PATCH", path, handler, name)

    fn options(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        return self.add_route("OPTIONS", path, handler, name)

    fn head(self, path: String, handler: HandlerFn, name: String = "") raises -> Self:
        return self.add_route("HEAD", path, handler, name)

    fn group(self, prefix: String, middleware: List[Middleware] = List[Middleware](),
             name_prefix: String = "") raises -> RouteGroup:
        let full_prefix = self._build_full_path(prefix)
        let full_name_prefix = self._build_full_name(name_prefix)
        var subgroup = RouteGroup(full_prefix, middleware, full_name_prefix)

        # Inherit parent middleware
        for mw in self.middleware:
            subgroup.middleware.append(mw)

        self.subgroups.append(subgroup)
        return subgroup

    fn use(self, middleware: Middleware) raises -> Self:
        self.middleware.append(middleware)
        return self

    fn _build_full_path(self, path: String) raises -> String:
        if self.prefix and not path.startswith("/"):
            return self.prefix + "/" + path
        elif self.prefix:
            return self.prefix + path
        else:
            return path

    fn _build_full_name(self, name: String) raises -> String:
        if self.name_prefix and name:
            return self.name_prefix + "." + name
        elif self.name_prefix:
            return self.name_prefix
        else:
            return name

# Main Router class
@value
struct Router:
    var routes: List[Route]
    var groups: List[RouteGroup]
    var static_routes: Dict[String, String]
    var route_names: Dict[String, Route]

    fn __init__(self) raises -> None:
        self.routes = List[Route]()
        self.groups = List[RouteGroup]()
        self.static_routes = Dict[String, String]()
        self.route_names = Dict[String, Route]()

    fn add_route(self, method: String, path: String, handler: HandlerFn,
                 name: String = "", middleware: List[Middleware] = List[Middleware]()) raises -> Self:
        var route = Route(method, path, handler, name, middleware)
        self.routes.append(route)

        if name:
            self.route_names[name] = route

        return self

    fn get(self, path: String, handler: HandlerFn, name: String = "",
           middleware: List[Middleware] = List[Middleware]()) raises -> Self:
        return self.add_route("GET", path, handler, name, middleware)

    fn post(self, path: String, handler: HandlerFn, name: String = "",
            middleware: List[Middleware] = List[Middleware]()) raises -> Self:
        return self.add_route("POST", path, handler, name, middleware)

    fn put(self, path: String, handler: HandlerFn, name: String = "",
           middleware: List[Middleware] = List[Middleware]()) raises -> Self:
        return self.add_route("PUT", path, handler, name, middleware)

    fn delete(self, path: String, handler: HandlerFn, name: String = "",
              middleware: List[Middleware] = List[Middleware]()) raises -> Self:
        return self.add_route("DELETE", path, handler, name, middleware)

    fn patch(self, path: String, handler: HandlerFn, name: String = "",
             middleware: List[Middleware] = List[Middleware]()) raises -> Self:
        return self.add_route("PATCH", path, handler, name, middleware)

    fn options(self, path: String, handler: HandlerFn, name: String = "",
               middleware: List[Middleware] = List[Middleware]()) raises -> Self:
        return self.add_route("OPTIONS", path, handler, name, middleware)

    fn head(self, path: String, handler: HandlerFn, name: String = "",
            middleware: List[Middleware] = List[Middleware]()) raises -> Self:
        return self.add_route("HEAD", path, handler, name, middleware)

    fn group(self, prefix: String, middleware: List[Middleware] = List[Middleware](),
             name_prefix: String = "") raises -> RouteGroup:
        var group = RouteGroup(prefix, middleware, name_prefix)
        self.groups.append(group)
        return group

    fn static(self, path: String, directory: String) raises -> Self:
        self.static_routes[path] = directory
        return self

    fn find_route(self, method: String, path: String) raises -> RouteMatch:
        # Check direct routes first
        for route in self.routes:
            let match = self._match_route(route, method, path)
            if match.matched:
                return match

        # Check group routes
        for group in self.groups:
            let match = self._find_in_group(group, method, path)
            if match.matched:
                return match

        return RouteMatch(Route("", "", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse { return res }), Dict[String, String](), False)

    fn _find_in_group(self, group: RouteGroup, method: String, path: String) raises -> RouteMatch:
        # Check group routes
        for route in group.routes:
            let match = self._match_route(route, method, path)
            if match.matched:
                return match

        # Check subgroups recursively
        for subgroup in group.subgroups:
            let match = self._find_in_group(subgroup, method, path)
            if match.matched:
                return match

        return RouteMatch(Route("", "", fn(req: HTTPRequest, res: HTTPResponse, ctx: Context) raises -> HTTPResponse { return res }), Dict[String, String](), False)

    fn _match_route(self, route: Route, method: String, path: String) raises -> RouteMatch:
        if route.method != method:
            return RouteMatch(route, Dict[String, String](), False)

        let route_parts = route.path.split("/")
        let request_parts = path.split("/")

        if len(route_parts) != len(request_parts):
            return RouteMatch(route, Dict[String, String](), False)

        var params = Dict[String, String]()

        for i in range(len(route_parts)):
            let route_part = route_parts[i]
            let request_part = request_parts[i]

            if route_part.startswith("{") and route_part.endswith("}"):
                # Parameter
                let param_name = route_part[1:-1]

                # Check constraints
                if route.constraints.contains_key(param_name):
                    let constraint = route.constraints[param_name]
                    if not self._matches_constraint(request_part, constraint):
                        return RouteMatch(route, Dict[String, String](), False)

                params[param_name] = request_part
            elif route_part != request_part:
                return RouteMatch(route, Dict[String, String](), False)

        return RouteMatch(route, params, True)

    fn _matches_constraint(self, value: String, constraint: String) raises -> Bool:
        # Simple constraint matching (can be enhanced with regex)
        if constraint.startswith("^") and constraint.endswith("$"):
            # Regex constraint
            try:
                return bool(regex_match(constraint, value))
            except:
                return False
        elif constraint == "int":
            return value.isdigit()
        elif constraint == "float":
            try:
                _ = atof(value)
                return True
            except:
                return False
        elif constraint == "alpha":
            return value.isalpha()
        elif constraint == "alphanum":
            return value.isalnum()
        else:
            return value == constraint

    fn get_route_by_name(self, name: String) raises -> Optional[Route]:
        if self.route_names.contains_key(name):
            return self.route_names[name]
        return None

    fn get_all_routes(self) raises -> List[Route]:
        var all_routes = List[Route]()

        # Add direct routes
        for route in self.routes:
            all_routes.append(route)

        # Add group routes
        for group in self.groups:
            self._collect_group_routes(group, all_routes)

        return all_routes

    fn _collect_group_routes(self, group: RouteGroup, routes: List[Route]) raises -> None:
        for route in group.routes:
            routes.append(route)

        for subgroup in group.subgroups:
            self._collect_group_routes(subgroup, routes)

# URL Generation
fn url_for(router: Router, route_name: String, **params) raises -> String:
    let route = router.get_route_by_name(route_name)
    if not route:
        raise Error("Route not found: " + route_name)

    var url = route.value().path

    # Replace parameters
    for param_name in params:
        let param_value = str(params[param_name])
        url = url.replace("{" + param_name + "}", param_value)

    return url

# Forward declarations
struct HandlerFn: pass
struct Middleware: pass
struct Context: pass
