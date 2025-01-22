from utils import logging_info

class DevOpsJenkins:
    def __init__(self, args):
        self.args = args

    def validate_inputs(self):
        logging_info("Validating inputs...")
        # Convert all values to strings and check if they are non-empty
        params = vars(self.args)
        for key, value in params.items():
            value_str = str(value).strip()
            if value_str:
                print(f"{key}: {value_str}")
            else:
                print(f"{key}: Invalid value")

    def prepare_queue(self):
        logging_info("Preparing job queue...")
        # Implement queue preparation logic here

    def execute_queue(self):
        logging_info("Executing job queue...")
        # Implement execution logic here
