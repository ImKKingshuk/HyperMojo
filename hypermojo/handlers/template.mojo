# Template System for HyperMojo

from collections import Dict, List
from os import path, getcwd
from io import open

# Template structure
@value
struct Template:
    var name: String
    var content: String
    var path: String

    fn __init__(self, name: String, content: String = "", path: String = "") raises -> None:
        self.name = name
        self.content = content
        self.path = path

    fn load_from_file(self, file_path: String) raises -> Self:
        if not path.exists(file_path):
            raise Error("Template file not found: " + file_path)

        let file = open(file_path, "r")
        self.content = file.read()
        file.close()
        self.path = file_path
        return self

    fn render(self, context: Dict[String, Any]) raises -> String:
        var result = self.content

        # Simple template variable replacement: {{variable}}
        for key in context:
            let placeholder = "{{" + key + "}}"
            let value = str(context[key])
            result = result.replace(placeholder, value)

        # Handle conditionals: {% if condition %}...{% endif %}
        result = self._process_conditionals(result, context)

        # Handle loops: {% for item in items %}...{% endfor %}
        result = self._process_loops(result, context)

        return result

    fn _process_conditionals(self, template: String, context: Dict[String, Any]) raises -> String:
        # Simple conditional processing
        var result = template
        var start_pos = 0

        while True:
            let if_start = result.find("{% if ", start_pos)
            if if_start == -1:
                break

            let condition_start = if_start + 6  # Skip "{% if "
            let condition_end = result.find(" %}", condition_start)
            if condition_end == -1:
                break

            let condition = result[condition_start:condition_end].strip()
            let endif_pos = result.find("{% endif %}", condition_end)
            if endif_pos == -1:
                break

            let if_block = result[if_start:endif_pos + 11]
            let content_start = condition_end + 3
            let content = result[content_start:endif_pos]

            # Evaluate condition
            let show_content = self._evaluate_condition(condition, context)

            if show_content:
                result = result.replace(if_block, content)
            else:
                result = result.replace(if_block, "")

            start_pos = if_start

        return result

    fn _process_loops(self, template: String, context: Dict[String, Any]) raises -> String:
        # Simple loop processing
        var result = template
        var start_pos = 0

        while True:
            let for_start = result.find("{% for ", start_pos)
            if for_start == -1:
                break

            let loop_start = for_start + 7  # Skip "{% for "
            let loop_end = result.find(" %}", loop_start)
            if loop_end == -1:
                break

            let loop_expr = result[loop_start:loop_end].strip()
            let endfor_pos = result.find("{% endfor %}", loop_end)
            if endfor_pos == -1:
                break

            let for_block = result[for_start:endfor_pos + 12]
            let content_start = loop_end + 3
            let content = result[content_start:endfor_pos]

            # Parse loop expression: "item in items"
            let parts = loop_expr.split(" in ")
            if len(parts) != 2:
                break

            let item_var = parts[0].strip()
            let list_var = parts[1].strip()

            # Get list from context
            if not context.contains_key(list_var):
                break

            let list_data = context[list_var]
            # In real implementation, check if it's actually a list

            var rendered_content = ""
            # Simple loop simulation - in real implementation, iterate over actual list
            for i in range(3):  # Placeholder
                var loop_context = Dict[String, Any]()
                for key in context:
                    loop_context[key] = context[key]
                loop_context[item_var] = "item_" + str(i)
                rendered_content += self._render_simple(content, loop_context)

            result = result.replace(for_block, rendered_content)
            start_pos = for_start

        return result

    fn _evaluate_condition(self, condition: String, context: Dict[String, Any]) raises -> Bool:
        # Simple condition evaluation
        if condition.startswith("not "):
            let var_name = condition[4:]
            return not (context.contains_key(var_name) and context[var_name])

        return context.contains_key(condition) and context[condition]

    fn _render_simple(self, template: String, context: Dict[String, Any]) raises -> String:
        # Simple variable replacement for loops/conditionals
        var result = template
        for key in context:
            let placeholder = "{{" + key + "}}"
            let value = str(context[key])
            result = result.replace(placeholder, value)
        return result

# Template Engine
@value
struct TemplateEngine:
    var templates: Dict[String, Template]
    var template_dir: String
    var cache_templates: Bool

    fn __init__(self, template_dir: String = "templates", cache_templates: Bool = True) raises -> None:
        self.templates = Dict[String, Template]()
        self.template_dir = template_dir
        self.cache_templates = cache_templates

    fn load_template(self, name: String, file_path: String = "") raises -> Self:
        if not file_path:
            file_path = path.join(self.template_dir, name + ".html")

        let template = Template(name).load_from_file(file_path)
        self.templates[name] = template
        return self

    fn render(self, name: String, context: Dict[String, Any]) raises -> String:
        if not self.templates.contains_key(name):
            if not self.cache_templates:
                # Try to load on demand
                let file_path = path.join(self.template_dir, name + ".html")
                if path.exists(file_path):
                    let template = Template(name).load_from_file(file_path)
                    self.templates[name] = template
                else:
                    raise Error("Template not found: " + name)
            else:
                raise Error("Template not found: " + name)

        return self.templates[name].render(context)

    fn render_string(self, template_string: String, context: Dict[String, Any]) raises -> String:
        let template = Template("inline", template_string)
        return template.render(context)

# Template Middleware for automatic template rendering
@value
struct TemplateMiddleware:
    var engine: TemplateEngine
    var template_name_header: String

    fn __init__(self, engine: TemplateEngine, template_name_header: String = "X-Template-Name") raises -> None:
        self.engine = engine
        self.template_name_header = template_name_header

    fn name(self) -> String:
        return "template"

    fn process(self, request: HTTPRequest, response: HTTPResponse, context: Context, next: HandlerFn) raises -> HTTPResponse:
        # Add template rendering to context
        context.set("render_template", fn(template_name: String, template_context: Dict[String, Any]) raises -> HTTPResponse {
            let content = self.engine.render(template_name, template_context)
            return response.html(content)
        })

        context.set("render_string", fn(template_string: String, template_context: Dict[String, Any]) raises -> HTTPResponse {
            let content = self.engine.render_string(template_string, template_context)
            return response.html(content)
        })

        return next(request, response, context)

# Helper functions for template rendering
fn render_template(engine: TemplateEngine, name: String, context: Dict[String, Any]) raises -> String:
    return engine.render(name, context)

fn render_string(engine: TemplateEngine, template_string: String, context: Dict[String, Any]) raises -> String:
    return engine.render_string(template_string, context)

# Common template functions
fn include_template(engine: TemplateEngine, name: String, context: Dict[String, Any]) raises -> String:
    try:
        return engine.render(name, context)
    except:
        return "<!-- Template '" + name + "' not found -->"

# Forward declarations
struct HTTPRequest: pass
struct HTTPResponse: pass
struct Context: pass
struct HandlerFn: pass
struct Error: pass
