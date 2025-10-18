# Session Management System for HyperMojo

from collections import Dict, List
from time import time
from hashlib import sha256
from random import random

# Session structure
@value
struct Session:
    var id: String
    var data: Dict[String, Any]
    var created_at: Int
    var expires_at: Int
    var is_new: Bool

    fn __init__(self, id: String = "", max_age: Int = 3600) raises -> None:
        self.id = id if id else self._generate_id()
        self.data = Dict[String, Any]()
        self.created_at = int(time())
        self.expires_at = self.created_at + max_age
        self.is_new = True

    fn _generate_id(self) raises -> String:
        let timestamp = str(int(time()))
        let random_part = str(int(random() * 1000000))
        let combined = timestamp + random_part
        return sha256(combined).hex()[:32]

    fn get(self, key: String) raises -> Any:
        return self.data.get(key, None)

    fn set(self, key: String, value: Any) raises -> None:
        self.data[key] = value
        self.is_new = False

    fn has(self, key: String) raises -> Bool:
        return self.data.contains_key(key)

    fn delete(self, key: String) raises -> None:
        if self.data.contains_key(key):
            _ = self.data.pop(key)
        self.is_new = False

    fn clear(self) raises -> None:
        self.data = Dict[String, Any]()
        self.is_new = False

    fn is_expired(self) raises -> Bool:
        return int(time()) > self.expires_at

    fn extend(self, max_age: Int) raises -> None:
        self.expires_at = int(time()) + max_age

# User structure for authentication
@value
struct User:
    var id: String
    var username: String
    var email: String
    var roles: List[String]
    var metadata: Dict[String, Any]

    fn __init__(self, id: String, username: String, email: String = "",
                roles: List[String] = List[String]()) raises -> None:
        self.id = id
        self.username = username
        self.email = email
        self.roles = roles
        self.metadata = Dict[String, Any]()

    fn has_role(self, role: String) raises -> Bool:
        return role in self.roles

    fn add_role(self, role: String) raises -> None:
        if not self.has_role(role):
            self.roles.append(role)

    fn remove_role(self, role: String) raises -> None:
        if role in self.roles:
            let index = self.roles.index(role)
            if index >= 0:
                _ = self.roles.pop(index)

# Session Store interface
trait SessionStore:
    fn get(self, session_id: String) raises -> Optional[Session]
    fn save(self, session: Session) raises -> None
    fn delete(self, session_id: String) raises -> None
    fn cleanup_expired(self) raises -> None

# In-memory session store implementation
@value
struct MemorySessionStore:
    var sessions: Dict[String, Session]
    var cleanup_interval: Int
    var last_cleanup: Int

    fn __init__(self, cleanup_interval: Int = 300) raises -> None:  # 5 minutes
        self.sessions = Dict[String, Session]()
        self.cleanup_interval = cleanup_interval
        self.last_cleanup = int(time())

    fn get(self, session_id: String) raises -> Optional[Session]:
        self._maybe_cleanup()

        if self.sessions.contains_key(session_id):
            let session = self.sessions[session_id]
            if session.is_expired():
                _ = self.sessions.pop(session_id)
                return None
            return session
        return None

    fn save(self, session: Session) raises -> None:
        self.sessions[session.id] = session

    fn delete(self, session_id: String) raises -> None:
        if self.sessions.contains_key(session_id):
            _ = self.sessions.pop(session_id)

    fn cleanup_expired(self) raises -> None:
        var expired_keys = List[String]()

        for session_id in self.sessions:
            let session = self.sessions[session_id]
            if session.is_expired():
                expired_keys.append(session_id)

        for key in expired_keys:
            _ = self.sessions.pop(key)

        self.last_cleanup = int(time())

    fn _maybe_cleanup(self) raises -> None:
        let current_time = int(time())
        if current_time - self.last_cleanup >= self.cleanup_interval:
            self.cleanup_expired()

# Session Middleware
@value
struct SessionMiddleware:
    var store: SessionStore
    var cookie_name: String
    var max_age: Int
    var secure: Bool
    var http_only: Bool

    fn __init__(self, store: SessionStore = MemorySessionStore(),
                cookie_name: String = "session_id", max_age: Int = 3600,
                secure: Bool = False, http_only: Bool = True) raises -> None:
        self.store = store
        self.cookie_name = cookie_name
        self.max_age = max_age
        self.secure = secure
        self.http_only = http_only

    fn name(self) -> String:
        return "session"

    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse:
        # Get session ID from cookie
        let session_id = request.cookie(self.cookie_name)

        var session: Optional[Session] = None
        if session_id:
            session = self.store.get(session_id)

        # Create new session if none exists
        if not session:
            session = Session("", self.max_age)

        # Set session in context
        context.session = session

        # Process request
        let result = next(request, response, context)

        # Save session if modified
        if session and (session.value().is_new or len(session.value().data) > 0):
            self.store.save(session.value())

            # Set session cookie
            let cookie = Cookie(self.cookie_name, session.value().id, self.max_age,
                              "/", "", self.secure, self.http_only)
            result.set_cookie(cookie)

        return result

# Authentication helpers
fn hash_password(password: String) raises -> String:
    # Use proper password hashing in production (e.g., bcrypt, argon2)
    return sha256(password + "salt").hex()

fn verify_password(password: String, hashed: String) raises -> Bool:
    return hash_password(password) == hashed

fn generate_token(length: Int = 32) raises -> String:
    var token = ""
    for i in range(length):
        let char_code = int(random() * 62)
        if char_code < 26:
            token += chr(ord('A') + char_code)
        elif char_code < 52:
            token += chr(ord('a') + char_code - 26)
        else:
            token += chr(ord('0') + char_code - 52)
    return token

# Forward declarations
struct HTTPRequest: pass
struct HTTPResponse: pass
struct Context: pass
struct HandlerFn: pass
struct Cookie: pass
