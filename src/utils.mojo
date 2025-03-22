from collections import Dict, List, Tuple
from .http import HTTPRequest

@value
struct ValidationError:
    var field: String
    var message: String
    
    fn __init__(self, field: String, message: String) -> None:
        self.field = field
        self.message = message

fn validate_field(value: String, field_type: String, required: Bool = True) raises -> Tuple[Bool, String, Any]:
    # Check if required field is missing
    if required and value == "":
        return (False, "Field is required", None)
    
    # If not required and empty, return success with None
    if not required and value == "":
        return (True, "", None)
    
    # Validate based on type
    if field_type == "string":
        return (True, "", value)
    elif field_type == "integer":
        if value.isdigit():
            return (True, "", atol(value))
        else:
            return (False, "Must be an integer", None)
    elif field_type == "number" or field_type == "float":
        try:
            let num = atof(value)
            return (True, "", num)
        except:
            return (False, "Must be a number", None)
    elif field_type == "boolean":
        if value.lower() == "true":
            return (True, "", True)
        elif value.lower() == "false":
            return (True, "", False)
        else:
            return (False, "Must be true or false", None)
    elif field_type == "email":
        # Simple email validation
        if "@" in value and "." in value:
            return (True, "", value)
        else:
            return (False, "Invalid email format", None)
    else:
        # Default to string for unknown types
        return (True, "", value)

fn validate_request_data(req: HTTPRequest, schema: Dict[String, Dict[String, Any]]) raises -> Tuple[Bool, List[ValidationError], Dict[String, Any]]:
    var errors = List[ValidationError]()
    var validated_data = Dict[String, Any]()
    
    # Determine the source of data based on content type
    var data_source: Dict[String, String]
    if req.method == "GET":
        data_source = req.query_params
    elif req.headers.get("Content-Type", "").startswith("application/json"):
        # For JSON data, we need to extract string values from the parsed JSON
        data_source = Dict[String, String]()
        for key in req.json_body:
            data_source[key] = str(req.json_body[key])
    elif req.headers.get("Content-Type", "").startswith("application/x-www-form-urlencoded"):
        data_source = req.form_data
    else:
        # Default to query params if content type is not recognized
        data_source = req.query_params
    
    # Validate each field in the schema
    for field_name in schema:
        let field_schema = schema[field_name]
        let required = field_schema.get("required", True)
        let field_type = field_schema.get("type", "string")
        
        let value = data_source.get(field_name, "")
        let validation_result = validate_field(value, field_type, required)
        
        if validation_result[0]:  # If validation passed
            if validation_result[2] != None:  # If value is not None
                validated_data[field_name] = validation_result[2]
        else:  # If validation failed
            errors.append(ValidationError(field_name, validation_result[1]))
    
    return (len(errors) == 0, errors, validated_data)