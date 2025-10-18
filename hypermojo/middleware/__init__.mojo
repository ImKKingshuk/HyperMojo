# Comprehensive Middleware System for HyperMojo

from collections import Dict, List
from time import time
from json import to_json
from hashlib import sha256

# Base Middleware trait
trait Middleware:
    fn name(self) -> String
    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse

# CORS Middleware
@value
struct CORSMiddleware:
    var allowed_origins: List[String]
    var allowed_methods: List[String]
    var allowed_headers: List[String]
    var allow_credentials: Bool
    var max_age: Int

    fn __init__(self, allowed_origins: List[String] = List[String](),
                allowed_methods: List[String] = List[String](),
                allowed_headers: List[String] = List[String](),
                allow_credentials: Bool = False, max_age: Int = 86400) raises -> None:
        self.allowed_origins = allowed_origins
        self.allowed_methods = allowed_methods if allowed_methods else List[String]("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH")
        self.allowed_headers = allowed_headers if allowed_headers else List[String]("Content-Type", "Authorization", "X-Requested-With")
        self.allow_credentials = allow_credentials
        self.max_age = max_age

    fn name(self) -> String:
        return "cors"

    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse:
        let origin = request.header("Origin")

        # Set CORS headers
        if len(self.allowed_origins) == 0 or "*" in self.allowed_origins or origin in self.allowed_origins:
            if len(self.allowed_origins) == 0 or "*" in self.allowed_origins:
                response.set_header("Access-Control-Allow-Origin", "*")
            else:
                response.set_header("Access-Control-Allow-Origin", origin)

        response.set_header("Access-Control-Allow-Methods", ", ".join(self.allowed_methods))
        response.set_header("Access-Control-Allow-Headers", ", ".join(self.allowed_headers))
        response.set_header("Access-Control-Max-Age", str(self.max_age))

        if self.allow_credentials:
            response.set_header("Access-Control-Allow-Credentials", "true")

        # Handle preflight requests
        if request.method == "OPTIONS":
            return response.set_status(204)

        return next(request, response, context)

# Logging Middleware
@value
struct LoggingMiddleware:
    var log_level: String
    var include_headers: Bool
    var include_body: Bool

    fn __init__(self, log_level: String = "info", include_headers: Bool = False, include_body: Bool = False) raises -> None:
        self.log_level = log_level
        self.include_headers = include_headers
        self.include_body = include_body

    fn name(self) -> String:
        return "logging"

    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse:
        let start_time = time()

        # Log request
        self._log_request(request)

        # Process request
        let result = next(request, response, context)

        let duration = time() - start_time

        # Log response
        self._log_response(result, duration)

        return result

    fn _log_request(self, request: HTTPRequest) raises -> None:
        var log_msg = "[" + str(int(time())) + "] " + request.method + " " + request.path
        log_msg += " from " + request.remote_addr

        if self.include_headers:
            log_msg += " Headers: " + str(request.headers)

        if self.include_body and request.body:
            log_msg += " Body: " + request.body

        print("[REQUEST] " + log_msg)

    fn _log_response(self, response: HTTPResponse, duration: Float64) raises -> None:
        var log_msg = "[" + str(int(time())) + "] " + str(response.status_code)
        log_msg += " in " + str(duration) + "s"

        print("[RESPONSE] " + log_msg)

# Rate Limiting Middleware
@value
struct RateLimitMiddleware:
    var requests_per_minute: Int
    var requests_per_hour: Int
    var burst_limit: Int
    var storage: Dict[String, RateLimitInfo]

    fn __init__(self, requests_per_minute: Int = 60, requests_per_hour: Int = 1000, burst_limit: Int = 10) raises -> None:
        self.requests_per_minute = requests_per_minute
        self.requests_per_hour = requests_per_hour
        self.burst_limit = burst_limit
        self.storage = Dict[String, RateLimitInfo]()

    fn name(self) -> String:
        return "rate_limit"

    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse:
        let client_key = self._get_client_key(request)

        if not self._is_allowed(client_key):
            response.set_status(429)
            response.set_header("Retry-After", "60")
            let error_data = Dict[String, Any]()
            error_data["error"] = "Too many requests"
            error_data["retry_after"] = 60
            return response.json(error_data)

        return next(request, response, context)

    fn _get_client_key(self, request: HTTPRequest) raises -> String:
        # Use IP address as client key (can be enhanced with API keys, etc.)
        return request.remote_addr

    fn _is_allowed(self, client_key: String) raises -> Bool:
        let current_time = time()

        if not self.storage.contains_key(client_key):
            self.storage[client_key] = RateLimitInfo(current_time, 1, 1)
            return True

        var info = self.storage[client_key]

        # Reset counters if time window has passed
        if current_time - info.minute_start >= 60:
            info.minute_count = 0
            info.minute_start = current_time

        if current_time - info.hour_start >= 3600:
            info.hour_count = 0
            info.hour_start = current_time

        # Check limits
        if info.minute_count >= self.requests_per_minute or info.hour_count >= self.requests_per_hour:
            return False

        # Allow burst
        if info.minute_count >= self.requests_per_minute + self.burst_limit:
            return False

        info.minute_count += 1
        info.hour_count += 1
        self.storage[client_key] = info

        return True

# Compression Middleware
@value
struct CompressionMiddleware:
    var min_size: Int
    var compression_level: Int

    fn __init__(self, min_size: Int = 1024, compression_level: Int = 6) raises -> None:
        self.min_size = min_size
        self.compression_level = compression_level

    fn name(self) -> String:
        return "compression"

    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse:
        let result = next(request, response, context)

        # Check if compression is supported and worthwhile
        let accepts_encoding = request.header("Accept-Encoding")
        let content_length = len(result.body)

        if "gzip" in accepts_encoding and content_length >= self.min_size:
            let compressed_body = self._gzip_compress(result.body)
            if len(compressed_body) < content_length:
                result.body = compressed_body
                result.set_header("Content-Encoding", "gzip")
                result.set_header("Content-Length", str(len(compressed_body)))

        return result

    fn _gzip_compress(self, data: String) raises -> String:
        # Placeholder for gzip compression
        # In a real implementation, this would use zlib or similar
        return data  # For now, return uncompressed

# Authentication Middleware
@value
struct AuthMiddleware:
    var auth_type: String
    var realm: String
    var user_store: Dict[String, String]  # username -> password hash

    fn __init__(self, auth_type: String = "basic", realm: String = "Restricted Area",
                user_store: Dict[String, String] = Dict[String, String]()) raises -> None:
        self.auth_type = auth_type
        self.realm = realm
        self.user_store = user_store

    fn name(self) -> String:
        return "auth"

    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse:
        let auth_header = request.header("Authorization")

        if not auth_header:
            return self._unauthorized(response)

        let user = self._authenticate(auth_header)
        if not user:
            return self._unauthorized(response)

        # Set user in context
        context.set("user", user)
        return next(request, response, context)

    fn _authenticate(self, auth_header: String) raises -> Optional[String]:
        if self.auth_type == "basic":
            return self._authenticate_basic(auth_header)
        return None

    fn _authenticate_basic(self, auth_header: String) raises -> Optional[String]:
        if not auth_header.startswith("Basic "):
            return None

        let encoded_creds = auth_header[6:]  # Remove "Basic "
        # In real implementation, decode base64
        let creds = encoded_creds  # Placeholder

        let parts = creds.split(":")
        if len(parts) != 2:
            return None

        let username = parts[0]
        let password = parts[1]

        if self.user_store.contains_key(username):
            let stored_hash = self.user_store[username]
            let password_hash = self._hash_password(password)
            if password_hash == stored_hash:
                return username

        return None

    fn _hash_password(self, password: String) raises -> String:
        # Simple hash for demo - use proper hashing in production
        return sha256(password).hex()

    fn _unauthorized(self, response: HTTPResponse) raises -> HTTPResponse:
        response.set_status(401)
        response.set_header("WWW-Authenticate", self.auth_type + " realm=\"" + self.realm + "\"")

        let error_data = Dict[String, Any]()
        error_data["error"] = "Authentication required"
        return response.json(error_data)

# CSRF Protection Middleware
@value
struct CSRFMiddleware:
    var token_name: String
    var header_name: String
    var cookie_name: String

    fn __init__(self, token_name: String = "_csrf", header_name: String = "X-CSRF-Token",
                cookie_name: String = "csrf_token") raises -> None:
        self.token_name = token_name
        self.header_name = header_name
        self.cookie_name = cookie_name

    fn name(self) -> String:
        return "csrf"

    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse:
        # Skip CSRF check for safe methods
        if request.method in List[String]("GET", "HEAD", "OPTIONS"):
            return next(request, response, context)

        let token_from_header = request.header(self.header_name)
        let token_from_form = request.form_data.get(self.token_name, "")
        let token_from_cookie = request.cookie(self.cookie_name)

        # Check if any token matches
        if token_from_header == token_from_cookie or token_from_form == token_from_cookie:
            return next(request, response, context)

        # CSRF token mismatch
        response.set_status(403)
        let error_data = Dict[String, Any]()
        error_data["error"] = "CSRF token mismatch"
        return response.json(error_data)

# Security Headers Middleware
@value
struct SecurityMiddleware:
    var hsts: Bool
    var no_sniff: Bool
    var frame_options: String
    var xss_protection: Bool

    fn __init__(self, hsts: Bool = True, no_sniff: Bool = True,
                frame_options: String = "DENY", xss_protection: Bool = True) raises -> None:
        self.hsts = hsts
        self.no_sniff = no_sniff
        self.frame_options = frame_options
        self.xss_protection = xss_protection

    fn name(self) -> String:
        return "security"

    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse:
        let result = next(request, response, context)

        if self.hsts:
            result.set_header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

        if self.no_sniff:
            result.set_header("X-Content-Type-Options", "nosniff")

        if self.frame_options:
            result.set_header("X-Frame-Options", self.frame_options)

        if self.xss_protection:
            result.set_header("X-XSS-Protection", "1; mode=block")

        return result

# Helper structures
@value
struct RateLimitInfo:
    var minute_start: Float64
    var minute_count: Int
    var hour_start: Float64
    var hour_count: Int

    fn __init__(self, current_time: Float64, minute_count: Int, hour_count: Int) raises -> None:
        self.minute_start = current_time
        self.minute_count = minute_count
        self.hour_start = current_time
        self.hour_count = hour_count

# Forward declarations
struct HTTPRequest: pass
struct HTTPResponse: pass
struct Context: pass
struct HandlerFn: pass
