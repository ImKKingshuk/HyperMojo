# File Upload Handling for HyperMojo

from collections import Dict, List
from os import path, getcwd
from io import open
from pathlib import Path

# File Upload Configuration
@value
struct UploadConfig:
    var max_file_size: Int
    var allowed_extensions: List[String]
    var upload_dir: String
    var preserve_filename: Bool
    var generate_filename: Bool

    fn __init__(self, max_file_size: Int = 10485760,  # 10MB
                allowed_extensions: List[String] = List[String](),
                upload_dir: String = "uploads",
                preserve_filename: Bool = False,
                generate_filename: Bool = True) raises -> None:
        self.max_file_size = max_file_size
        self.allowed_extensions = allowed_extensions
        self.upload_dir = upload_dir
        self.preserve_filename = preserve_filename
        self.generate_filename = generate_filename

# Enhanced UploadedFile with more functionality
@value
struct UploadedFile:
    var field_name: String
    var filename: String
    var content: String
    var content_type: String
    var size: Int
    var temp_path: String

    fn __init__(self, field_name: String, filename: String, content: String,
                content_type: String = "application/octet-stream") raises -> None:
        self.field_name = field_name
        self.filename = filename
        self.content = content
        self.content_type = content_type
        self.size = len(content)
        self.temp_path = ""

    fn is_valid_size(self, max_size: Int) raises -> Bool:
        return self.size <= max_size

    fn has_valid_extension(self, allowed_extensions: List[String]) raises -> Bool:
        if len(allowed_extensions) == 0:
            return True

        let ext = self._get_extension().lower()
        for allowed_ext in allowed_extensions:
            if ext == allowed_ext.lower():
                return True
        return False

    fn _get_extension(self) raises -> String:
        let parts = self.filename.split(".")
        if len(parts) > 1:
            return "." + parts[-1]
        return ""

    fn save(self, directory: String = "", filename: String = "") raises -> String:
        # Create directory if it doesn't exist
        let target_dir = directory if directory else "uploads"
        if not path.exists(target_dir):
            Path(target_dir).mkdir(parents=True, exist_ok=True)

        # Generate filename if needed
        let final_filename = filename if filename else self._generate_filename()

        let file_path = path.join(target_dir, final_filename)

        # Save file
        let file = open(file_path, "wb")
        file.write(self.content.encode())
        file.close()

        return file_path

    fn save_to_temp(self) raises -> String:
        if self.temp_path:
            return self.temp_path

        # Create temp directory
        let temp_dir = path.join(getcwd(), "temp")
        if not path.exists(temp_dir):
            Path(temp_dir).mkdir(parents=True, exist_ok=True)

        let temp_filename = "temp_" + str(hash(self.content)) + "_" + self.filename
        self.temp_path = path.join(temp_dir, temp_filename)

        let file = open(self.temp_path, "wb")
        file.write(self.content.encode())
        file.close()

        return self.temp_path

    fn _generate_filename(self) raises -> String:
        from time import time
        from random import random

        let timestamp = str(int(time()))
        let random_part = str(int(random() * 10000))
        let ext = self._get_extension()
        return "upload_" + timestamp + "_" + random_part + ext

    fn delete_temp(self) raises -> None:
        if self.temp_path and path.exists(self.temp_path):
            # In real implementation, delete the file
            self.temp_path = ""

# File Upload Handler
fn handle_file_upload(request: HTTPRequest, config: UploadConfig) raises -> Dict[String, Any]:
    var result = Dict[String, Any]()
    var uploaded_files = List[UploadedFile]()
    var errors = List[String]()

    # Process uploaded files
    for field_name in request.files:
        let uploaded_file = request.files[field_name]

        # Validate file size
        if not uploaded_file.is_valid_size(config.max_file_size):
            errors.append("File '" + uploaded_file.filename + "' exceeds maximum size")
            continue

        # Validate extension
        if not uploaded_file.has_valid_extension(config.allowed_extensions):
            errors.append("File '" + uploaded_file.filename + "' has invalid extension")
            continue

        # Save file
        let saved_path = uploaded_file.save(config.upload_dir)
        uploaded_files.append(uploaded_file)

        var file_info = Dict[String, Any]()
        file_info["original_name"] = uploaded_file.filename
        file_info["saved_path"] = saved_path
        file_info["size"] = uploaded_file.size
        file_info["content_type"] = uploaded_file.content_type

        result[field_name] = file_info

    result["uploaded_files"] = uploaded_files
    result["errors"] = errors
    result["success"] = len(errors) == 0

    return result

# Static File Handler with enhanced features
@value
struct StaticFileHandler:
    var root_dir: String
    var url_prefix: String
    var cache_max_age: Int
    var enable_gzip: Bool

    fn __init__(self, root_dir: String, url_prefix: String = "/static",
                cache_max_age: Int = 86400, enable_gzip: Bool = True) raises -> None:
        self.root_dir = root_dir
        self.url_prefix = url_prefix
        self.cache_max_age = cache_max_age
        self.enable_gzip = enable_gzip

    fn serve_file(self, request: HTTPRequest) raises -> HTTPResponse:
        # Extract file path from URL
        if not request.path.startswith(self.url_prefix):
            return HTTPResponse("Not Found", 404)

        let rel_path = request.path[len(self.url_prefix):].strip("/")
        let file_path = path.join(self.root_dir, rel_path)

        # Security check - prevent directory traversal
        if ".." in rel_path or not path.exists(file_path) or path.isdir(file_path):
            return HTTPResponse("Not Found", 404)

        # Read file
        try:
            let file = open(file_path, "rb")
            let content = file.read()
            file.close()

            # Determine content type
            let content_type = self._get_content_type(file_path)

            # Create response
            var response = HTTPResponse(content.decode())
            response.set_header("Content-Type", content_type)
            response.set_header("Cache-Control", "max-age=" + str(self.cache_max_age))

            # Set content length
            response.set_header("Content-Length", str(len(content)))

            return response

        except:
            return HTTPResponse("Internal Server Error", 500)

    fn _get_content_type(self, file_path: String) raises -> String:
        if file_path.endswith(".html"):
            return "text/html"
        elif file_path.endswith(".css"):
            return "text/css"
        elif file_path.endswith(".js"):
            return "application/javascript"
        elif file_path.endswith(".json"):
            return "application/json"
        elif file_path.endswith(".png"):
            return "image/png"
        elif file_path.endswith(".jpg") or file_path.endswith(".jpeg"):
            return "image/jpeg"
        elif file_path.endswith(".gif"):
            return "image/gif"
        elif file_path.endswith(".svg"):
            return "image/svg+xml"
        elif file_path.endswith(".ico"):
            return "image/x-icon"
        elif file_path.endswith(".woff"):
            return "font/woff"
        elif file_path.endswith(".woff2"):
            return "font/woff2"
        elif file_path.endswith(".ttf"):
            return "font/ttf"
        elif file_path.endswith(".pdf"):
            return "application/pdf"
        else:
            return "application/octet-stream"

# File Download Handler
fn download_file(file_path: String, filename: String = "", as_attachment: Bool = True) raises -> HTTPResponse:
    if not path.exists(file_path):
        return HTTPResponse("File not found", 404)

    try:
        let file = open(file_path, "rb")
        let content = file.read()
        file.close()

        var response = HTTPResponse(content.decode())

        # Set content type based on extension
        let ext_start = file_path.rfind(".")
        if ext_start != -1:
            let ext = file_path[ext_start:]
            if ext == ".pdf":
                response.set_header("Content-Type", "application/pdf")
            elif ext in [".txt", ".md"]:
                response.set_header("Content-Type", "text/plain")
            elif ext in [".jpg", ".jpeg"]:
                response.set_header("Content-Type", "image/jpeg")
            elif ext == ".png":
                response.set_header("Content-Type", "image/png")
            # Add more content types as needed

        # Set content disposition
        let download_name = filename if filename else path.basename(file_path)
        if as_attachment:
            response.set_header("Content-Disposition", "attachment; filename=\"" + download_name + "\"")
        else:
            response.set_header("Content-Disposition", "inline; filename=\"" + download_name + "\"")

        response.set_header("Content-Length", str(len(content)))

        return response

    except:
        return HTTPResponse("Error reading file", 500)

# Forward declarations
struct HTTPRequest: pass
