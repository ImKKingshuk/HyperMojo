from sys import socket
from collections import Dict, List, KeyError
from json import to_json, parse_json

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

    fn __init__(self, raw_data: String) raises -> None:
        self.query_params = Dict[String, String]()
        self.headers = Dict[String, String]()
        self.path_params = Dict[String, String]()
        self.json_body = Dict[String, Any]()
        self.form_data = Dict[String, String]()
        self.cookies = Dict[String, String]()
        self.body = ""
        
        let lines = raw_data.split("\r\n")
        if len(lines) < 1:
            self.method = ""
            self.path = "/"
            return
        
        let request_line = lines[0].split(" ")
        self.method = request_line[0]
        let full_path = request_line[1]
        
        let path_parts = full_path.split("?")
        self.path = path_parts[0]
        if len(path_parts) > 1:
            let query = path_parts[1].split("&")
            for param in query:
                let kv = param.split("=")
                if len(kv) == 2:
                    self.query_params[kv[0]] = kv[1]
        
        var body_start = -1
        for i in range(1, len(lines)):
            if lines[i] == "":
                body_start = i + 1
                break
            let header = lines[i].split(": ")
            if len(header) == 2:
                self.headers[header[0]] = header[1]
                # Parse cookies
                if header[0] == "Cookie":
                    let cookie_parts = header[1].split("; ")
                    for cookie in cookie_parts:
                        let cookie_kv = cookie.split("=")
                        if len(cookie_kv) == 2:
                            self.cookies[cookie_kv[0]] = cookie_kv[1]
        
        if body_start != -1 and body_start < len(lines):
            self.body = "\r\n".join(lines[body_start:])
            
            # Try to parse JSON body
            if self.headers.get("Content-Type", "").startswith("application/json"):
                try:
                    self.json_body = parse_json(self.body)
                except:
                    pass  # Invalid JSON, keep json_body empty
                    
            # Parse form data
            elif self.headers.get("Content-Type", "").startswith("application/x-www-form-urlencoded"):
                let form_items = self.body.split("&")
                for item in form_items:
                    let kv = item.split("=")
                    if len(kv) == 2:
                        self.form_data[kv[0]] = kv[1]


@value
struct HTTPResponse:
    var body: String
    var status_code: Int
    var headers: Dict[String, String]

    fn __init__(self, body: String, status_code: Int = 200) raises -> None:
        self.body = body
        self.status_code = status_code
        self.headers = Dict[String, String]()
        self.headers["Content-Length"] = str(len(body))
        self.headers["Content-Type"] = "text/plain"

    fn json(self, data: Dict[String, Any], status_code: Int = 200) raises -> Self:
        let json_body = to_json(data)
        var resp = HTTPResponse(json_body, status_code)
        resp.headers["Content-Type"] = "application/json"
        return resp
        
    fn html(self, content: String, status_code: Int = 200) raises -> Self:
        var resp = HTTPResponse(content, status_code)
        resp.headers["Content-Type"] = "text/html"
        return resp
        
    fn redirect(self, url: String, status_code: Int = 302) raises -> Self:
        var resp = HTTPResponse("", status_code)
        resp.headers["Location"] = url
        return resp
        
    fn set_cookie(self, name: String, value: String, max_age: Int = 3600, 
http_only: Bool = True) raises -> Self:
        var cookie = name + "=" + value + "; Max-Age=" + str(max_age)
        if http_only:
            cookie += "; HttpOnly"
        self.headers["Set-Cookie"] = cookie
        return self

    fn to_bytes(self) raises -> String:
        var status = ""
        if self.status_code == 200:
            status = "200 OK"
        elif self.status_code == 201:
            status = "201 Created"
        elif self.status_code == 204:
            status = "204 No Content"
        elif self.status_code == 302:
            status = "302 Found"
        elif self.status_code == 400:
            status = "400 Bad Request"
        elif self.status_code == 401:
            status = "401 Unauthorized"
        elif self.status_code == 403:
            status = "403 Forbidden"
        elif self.status_code == 404:
            status = "404 Not Found"
        elif self.status_code == 500:
            status = "500 Internal Server Error"
        else:
            status = str(self.status_code) + " Status"
            
        var headers_str = ""
        for key in self.headers:
            headers_str += key + ": " + self.headers[key] + "\r\n"
        return "HTTP/1.1 " + status + "\r\n" + headers_str + "\r\n" + self.body