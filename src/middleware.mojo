from collections import Dict, List
from .http import HTTPRequest, HTTPResponse
from .utils import validate_request_data
from .routing import HandlerFn, MiddlewareFn

fn validation_middleware(schema: Dict[String, Dict[String, Any]]) raises -> MiddlewareFn:
    return fn(req: HTTPRequest, next: HandlerFn, deps: Dict[String, Any]) raises -> HTTPResponse:
        let validation_result = validate_request_data(req, schema)
        if not validation_result[0]:  # If validation failed
            var error_data = Dict[String, Any]()
            error_data["detail"] = "Validation Error"
            var error_list = List[Dict[String, String]]()
            
            for error in validation_result[1]:
                var error_dict = Dict[String, String]()
                error_dict["field"] = error.field
                error_dict["message"] = error.message
                error_list.append(error_dict)
            
            error_data["errors"] = error_list
            return HTTPResponse().json(error_data, 422)  # Unprocessable Entity
        
        # Add validated data to deps
        deps["validated_data"] = validation_result[2]
        return next(req, deps)

fn logging_middleware(req: HTTPRequest, next: HandlerFn, deps: Dict[String, Any]) raises -> HTTPResponse:
    print("Request: " + req.method + " " + req.path)
    return next(req, deps)

fn auth_middleware(token_validator: fn(String) raises -> Bool) raises -> MiddlewareFn:
    return fn(req: HTTPRequest, next: HandlerFn, deps: Dict[String, Any]) raises -> HTTPResponse:
        let token = req.headers.get("Authorization", "")
        if not token or not token_validator(token):
            var error_data = Dict[String, Any]()
            error_data["detail"] = "Authentication failed"
            return HTTPResponse().json(error_data, 401)  # Unauthorized
        return next(req, deps)