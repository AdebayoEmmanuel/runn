from utils import logging_info

class DevOpsJenkins:
    def __init__(self, args):
        self.args = args

    def validate_inputs(self):
        logging_info("Validating inputs...")
        # Check if each argument is a non-empty string and print key:value
        params = vars(self.args)
        for key, value in params.items():
            if isinstance(value, str) and value.strip():
                print(f"{key}: {value}")
            else:
                print(f"{key}: Invalid value")

    def prepare_queue(self):
        logging_info("Preparing job queue...")
        # Implement queue preparation logic here

    def execute_queue(self):
        logging_info("Executing job queue...")
        # Implement execution logic here
