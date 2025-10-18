# Enhanced HTTP Request and Response structures

from collections import Dict, List
from json import to_json, parse_json
from base64 import encode as base64_encode
from time import time
from pathlib import Path

# Enhanced HTTP Request
@value
struct HTTPRequest:
    var method: String
    var path: String
    var query_params: Dict[String, String]
    var headers: Dict[String, String]
    var body: String
    var path_params: Dict[String, String]
    var json_body: Dict[String, Any]
    var form_data: Dict[String, String]
    var cookies: Dict[String, String]
    var files: Dict[String, UploadedFile]
    var raw_data: String
    var timestamp: Int
    var remote_addr: String
    var user_agent: String
    var content_type: String
    var content_length: Int

    fn __init__(self, raw_data: String, remote_addr: String = "") raises -> None:
        self.query_params = Dict[String, String]()
        self.headers = Dict[String, String]()
        self.path_params = Dict[String, String]()
        self.json_body = Dict[String, Any]()
        self.form_data = Dict[String, String]()
        self.cookies = Dict[String, String]()
        self.files = Dict[String, UploadedFile]()
        self.body = ""
        self.raw_data = raw_data
        self.remote_addr = remote_addr
        self.timestamp = int(time())
        self.user_agent = ""
        self.content_type = ""
        self.content_length = 0

        self._parse_request(raw_data)

    fn _parse_request(self, raw_data: String) raises -> None:
        let lines = raw_data.split("\r\n")
        if len(lines) < 1:
            self.method = ""
            self.path = "/"
            return

        # Parse request line
        let request_line = lines[0].split(" ")
        if len(request_line) >= 2:
            self.method = request_line[0]
            let full_path = request_line[1]

            # Parse path and query parameters
            let path_parts = full_path.split("?")
            self.path = path_parts[0]
            if len(path_parts) > 1:
                self._parse_query_params(path_parts[1])

        # Parse headers
        var body_start = -1
        for i in range(1, len(lines)):
            if lines[i] == "":
                body_start = i + 1
                break
            let header = lines[i].split(": ")
            if len(header) == 2:
                let header_name = header[0]
                let header_value = header[1]
                self.headers[header_name] = header_value

                # Extract common headers
                if header_name == "User-Agent":
                    self.user_agent = header_value
                elif header_name == "Content-Type":
                    self.content_type = header_value
                elif header_name == "Content-Length":
                    self.content_length = atol(header_value)
                elif header_name == "Cookie":
                    self._parse_cookies(header_value)

        # Parse body
        if body_start != -1 and body_start < len(lines):
            self.body = "\r\n".join(lines[body_start:])
            self._parse_body()

    fn _parse_query_params(self, query_string: String) raises -> None:
        let params = query_string.split("&")
        for param in params:
            let kv = param.split("=")
            if len(kv) == 2:
                self.query_params[kv[0]] = kv[1]

    fn _parse_cookies(self, cookie_header: String) raises -> None:
        let cookie_parts = cookie_header.split("; ")
        for cookie in cookie_parts:
            let cookie_kv = cookie.split("=")
            if len(cookie_kv) == 2:
                self.cookies[cookie_kv[0]] = cookie_kv[1]

    fn _parse_body(self) raises -> None:
        # Parse JSON body
        if self.content_type.startswith("application/json"):
            try:
                self.json_body = parse_json(self.body)
            except:
                pass  # Invalid JSON, keep json_body empty

        # Parse form data
        elif self.content_type.startswith("application/x-www-form-urlencoded"):
            let form_items = self.body.split("&")
            for item in form_items:
                let kv = item.split("=")
                if len(kv) == 2:
                    self.form_data[kv[0]] = kv[1]

        # Parse multipart form data (basic implementation)
        elif self.content_type.startswith("multipart/form-data"):
            self._parse_multipart_data()

    fn _parse_multipart_data(self) raises -> None:
        # Basic multipart parsing - can be enhanced
        let boundary = self._extract_boundary()
        if boundary:
            let parts = self.body.split("--" + boundary)
            for part in parts:
                if part.strip() and not part.startswith("--"):
                    self._parse_multipart_part(part.strip())

    fn _extract_boundary(self) -> String:
        if "boundary=" in self.content_type:
            let boundary_part = self.content_type.split("boundary=")[1]
            return boundary_part.split(";")[0].strip()
        return ""

    fn _parse_multipart_part(self, part: String) raises -> None:
        let lines = part.split("\r\n")
        if len(lines) < 3:
            return

        # Parse headers
        var content_disposition = ""
        var filename = ""
        var field_name = ""

        for line in lines:
            if line.startswith("Content-Disposition:"):
                content_disposition = line
                # Extract field name and filename
                if "name=" in line:
                    let name_part = line.split("name=\"")[1].split("\"")[0]
                    field_name = name_part
                if "filename=" in line:
                    let filename_part = line.split("filename=\"")[1].split("\"")[0]
                    filename = filename_part
                break

        # Extract content (skip headers)
        var content_start = -1
        for i in range(len(lines)):
            if lines[i] == "":
                content_start = i + 1
                break

        if content_start != -1:
            let content = "\r\n".join(lines[content_start:])
            if filename:
                # File upload
                let uploaded_file = UploadedFile(field_name, filename, content)
                self.files[field_name] = uploaded_file
            else:
                # Form field
                self.form_data[field_name] = content

    # Utility methods
    fn param(self, name: String) raises -> String:
        if self.path_params.contains_key(name):
            return self.path_params[name]
        elif self.query_params.contains_key(name):
            return self.query_params[name]
        return ""

    fn has_param(self, name: String) raises -> Bool:
        return self.path_params.contains_key(name) or self.query_params.contains_key(name)

    fn header(self, name: String) raises -> String:
        return self.headers.get(name, "")

    fn cookie(self, name: String) raises -> String:
        return self.cookies.get(name, "")

    fn is_json(self) raises -> Bool:
        return self.content_type.startswith("application/json")

    fn is_form(self) raises -> Bool:
        return self.content_type.startswith("application/x-www-form-urlencoded") or self.content_type.startswith("multipart/form-data")

# Uploaded File structure
@value
struct UploadedFile:
    var field_name: String
    var filename: String
    var content: String
    var size: Int

    fn __init__(self, field_name: String, filename: String, content: String) raises -> None:
        self.field_name = field_name
        self.filename = filename
        self.content = content
        self.size = len(content)

    fn save(self, directory: String) raises -> Bool:
        try:
            let file_path = Path(directory) / self.filename
            let file = open(str(file_path), "wb")
            file.write(self.content.encode())
            file.close()
            return True
        except:
            return False

# Enhanced HTTP Response
@value
struct HTTPResponse:
    var status_code: Int
    var headers: Dict[String, String]
    var body: String
    var cookies: List[Cookie]

    fn __init__(self, body: String = "", status_code: Int = 200) raises -> None:
        self.status_code = status_code
        self.headers = Dict[String, String]()
        self.body = body
        self.cookies = List[Cookie]()

        # Set default headers
        self.headers["Content-Length"] = str(len(body))
        self.headers["Content-Type"] = "text/plain"
        self.headers["Server"] = "HyperMojo"

    fn json(self, data: Dict[String, Any], status_code: Int = 200) raises -> Self:
        let json_body = to_json(data)
        var resp = HTTPResponse(json_body, status_code)
        resp.headers["Content-Type"] = "application/json"
        return resp

    fn html(self, content: String, status_code: Int = 200) raises -> Self:
        var resp = HTTPResponse(content, status_code)
        resp.headers["Content-Type"] = "text/html"
        return resp

    fn text(self, content: String, status_code: Int = 200) raises -> Self:
        var resp = HTTPResponse(content, status_code)
        resp.headers["Content-Type"] = "text/plain"
        return resp

    fn redirect(self, url: String, status_code: Int = 302) raises -> Self:
        var resp = HTTPResponse("", status_code)
        resp.headers["Location"] = url
        return resp

    fn set_header(self, name: String, value: String) raises -> Self:
        self.headers[name] = value
        return self

    fn set_cookie(self, cookie: Cookie) raises -> Self:
        self.cookies.append(cookie)
        return self

    fn set_status(self, status_code: Int) raises -> Self:
        self.status_code = status_code
        return self

    fn to_bytes(self) raises -> String:
        var status_line = self._get_status_line()
        var headers_str = ""

        # Add response headers
        for key in self.headers:
            headers_str += key + ": " + self.headers[key] + "\r\n"

        # Add cookie headers
        for cookie in self.cookies:
            headers_str += "Set-Cookie: " + cookie.to_header_string() + "\r\n"

        return status_line + "\r\n" + headers_str + "\r\n" + self.body

    fn _get_status_line(self) raises -> String:
        var status_text = ""
        if self.status_code == 200:
            status_text = "200 OK"
        elif self.status_code == 201:
            status_text = "201 Created"
        elif self.status_code == 202:
            status_text = "202 Accepted"
        elif self.status_code == 204:
            status_text = "204 No Content"
        elif self.status_code == 301:
            status_text = "301 Moved Permanently"
        elif self.status_code == 302:
            status_text = "302 Found"
        elif self.status_code == 303:
            status_text = "303 See Other"
        elif self.status_code == 304:
            status_text = "304 Not Modified"
        elif self.status_code == 400:
            status_text = "400 Bad Request"
        elif self.status_code == 401:
            status_text = "401 Unauthorized"
        elif self.status_code == 403:
            status_text = "403 Forbidden"
        elif self.status_code == 404:
            status_text = "404 Not Found"
        elif self.status_code == 405:
            status_text = "405 Method Not Allowed"
        elif self.status_code == 409:
            status_text = "409 Conflict"
        elif self.status_code == 422:
            status_text = "422 Unprocessable Entity"
        elif self.status_code == 429:
            status_text = "429 Too Many Requests"
        elif self.status_code == 500:
            status_text = "500 Internal Server Error"
        elif self.status_code == 501:
            status_text = "501 Not Implemented"
        elif self.status_code == 502:
            status_text = "502 Bad Gateway"
        elif self.status_code == 503:
            status_text = "503 Service Unavailable"
        else:
            status_text = str(self.status_code) + " Status"

        return "HTTP/1.1 " + status_text

# Cookie structure
@value
struct Cookie:
    var name: String
    var value: String
    var max_age: Int
    var path: String
    var domain: String
    var secure: Bool
    var http_only: Bool
    var same_site: String

    fn __init__(self, name: String, value: String, max_age: Int = 3600,
                path: String = "/", domain: String = "", secure: Bool = False,
                http_only: Bool = True, same_site: String = "Lax") raises -> None:
        self.name = name
        self.value = value
        self.max_age = max_age
        self.path = path
        self.domain = domain
        self.secure = secure
        self.http_only = http_only
        self.same_site = same_site

    fn to_header_string(self) raises -> String:
        var cookie_str = self.name + "=" + self.value
        cookie_str += "; Max-Age=" + str(self.max_age)
        cookie_str += "; Path=" + self.path
        if self.domain:
            cookie_str += "; Domain=" + self.domain
        if self.secure:
            cookie_str += "; Secure"
        if self.http_only:
            cookie_str += "; HttpOnly"
        if self.same_site:
            cookie_str += "; SameSite=" + self.same_site
        return cookie_str
