import datetime

def beautify_terminal_output(header="", body="", border_style="="):
    print(f"{header}\n{border_style * len(header)}\n{body}")

def get_jenkins_job_name(stage_type, service_name, environment_name, action, application_name):
    return f"{stage_type}-{service_name}-{environment_name}-{action}-{application_name}"

def logging_info(message):
    print(f"{datetime.datetime.now()} INFO: {message}")

def logging_warning(message):
    print(f"{datetime.datetime.now()} WARNING: {message}")

def logging_error(message):
    print(f"{datetime.datetime.now()} ERROR: {message}")

def validate_parameters(params, valid_values):
    for param, value in params.items():
        if value not in valid_values.get(param, []):
            logging_error(f"Invalid value for {param}: {value}")
            return False
    return True
