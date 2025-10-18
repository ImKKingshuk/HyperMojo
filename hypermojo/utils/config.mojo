# Configuration Management System for HyperMojo

from collections import Dict, List
from json import parse_json, to_json
from os import path, getcwd
from io import open

# Configuration structure
@value
struct Config:
    var data: Dict[String, Any]
    var file_path: String

    fn __init__(self, file_path: String = "config.json") raises -> None:
        self.data = Dict[String, Any]()
        self.file_path = file_path
        self._load_defaults()

        if path.exists(file_path):
            self.load_from_file(file_path)

    fn _load_defaults(self) raises -> None:
        # Server defaults
        self.data["server"] = Dict[String, Any]()
        self.data["server"]["host"] = "0.0.0.0"
        self.data["server"]["port"] = 8080
        self.data["server"]["workers"] = 4
        self.data["server"]["max_request_size"] = 1048576
        self.data["server"]["timeout"] = 30

        # App defaults
        self.data["app"] = Dict[String, Any]()
        self.data["app"]["name"] = "HyperMojo App"
        self.data["app"]["version"] = "1.0.0"
        self.data["app"]["debug"] = False

        # Database defaults (placeholder)
        self.data["database"] = Dict[String, Any]()
        self.data["database"]["type"] = "none"

        # Security defaults
        self.data["security"] = Dict[String, Any]()
        self.data["security"]["secret_key"] = "change-me-in-production"
        self.data["security"]["session_timeout"] = 3600

        # Upload defaults
        self.data["upload"] = Dict[String, Any]()
        self.data["upload"]["max_file_size"] = 10485760
        self.data["upload"]["upload_dir"] = "uploads"

    fn load_from_file(self, file_path: String) raises -> Self:
        try:
            let file = open(file_path, "r")
            let content = file.read()
            file.close()

            let parsed = parse_json(content)
            self._merge_config(self.data, parsed)
            self.file_path = file_path
        except:
            print("Warning: Could not load config from " + file_path)

        return self

    fn save_to_file(self, file_path: String = "") raises -> None:
        let target_path = file_path if file_path else self.file_path

        let json_content = to_json(self.data)
        let file = open(target_path, "w")
        file.write(json_content)
        file.close()

    fn _merge_config(self, target: Dict[String, Any], source: Dict[String, Any]) raises -> None:
        for key in source:
            target[key] = source[key]

    fn get(self, key: String) raises -> Any:
        return self._get_nested_value(key)

    fn set(self, key: String, value: Any) raises -> None:
        self._set_nested_value(key, value)

    fn has(self, key: String) raises -> Bool:
        try:
            _ = self._get_nested_value(key)
            return True
        except:
            return False

    fn _get_nested_value(self, key: String) raises -> Any:
        let parts = key.split(".")
        var current = self.data

        for part in parts:
            if current.contains_key(part):
                let value = current[part]
                if part == parts[-1]:
                    return value
                # In real implementation, check if value is a dict
                current = value  # This would need proper type checking
            else:
                raise Error("Configuration key not found: " + key)

        raise Error("Configuration key not found: " + key)

    fn _set_nested_value(self, key: String, value: Any) raises -> None:
        let parts = key.split(".")
        var current = self.data

        for i in range(len(parts)):
            let part = parts[i]
            if i == len(parts) - 1:
                current[part] = value
            else:
                if not current.contains_key(part):
                    current[part] = Dict[String, Any]()
                # In real implementation, ensure it's a dict
                current = current[part]

# Environment variable support
fn load_from_env() raises -> Dict[String, Any]:
    # In Mojo, environment variables would need to be accessed via external libraries
    # This is a placeholder implementation
    return Dict[String, Any]()

# Validation utilities
fn validate_config(config: Config) raises -> List[String]:
    var errors = List[String]()

    # Validate server config
    try:
        let port = int(config.get("server.port"))
        if port < 1 or port > 65535:
            errors.append("Server port must be between 1 and 65535")
    except:
        errors.append("Invalid server port configuration")

    try:
        let workers = int(config.get("server.workers"))
        if workers < 1:
            errors.append("Server must have at least 1 worker")
    except:
        errors.append("Invalid server workers configuration")

    # Validate security config
    try:
        let secret_key = str(config.get("security.secret_key"))
        if len(secret_key) < 8:
            errors.append("Secret key must be at least 8 characters long")
    except:
        errors.append("Invalid security secret_key configuration")

    return errors

# Configuration helpers
fn get_app_config(config: Config) raises -> AppConfig:
    return AppConfig(
        str(config.get("server.host")),
        int(config.get("server.port")),
        bool(config.get("app.debug")),
        str(config.get("app.name")),
        str(config.get("app.version")),
        str(config.get("app.description")),
        int(config.get("server.workers")),
        int(config.get("server.max_request_size")),
        int(config.get("server.timeout"))
    )

# Forward declarations
struct AppConfig: pass
