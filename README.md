# Project Name

This project is designed to validate and execute DevOps tasks using parameters passed from YAML files and Rundeck options. The main script, `start.py`, handles the parsing of command-line arguments, validation of parameters, and execution of tasks.

## Installation

1. Clone the repository:
   ```sh
   git clone git@github.com:AdebayoEmmanuel/pyreq.git

### start.py

The `start.py` script is the entry point of the project. It parses command-line arguments, validates parameters, and executes the corresponding tasks.

#### Expected Parameters:
- `--action <action>`: Specifies the action to perform. Possible values are `validate`, `prepare`, and `execute`.
- `--env <env>`: Specifies the environment in which the action should be performed.
- `--reg <reg>`: Specifies the region for the action.
- `--stages <stages>`: Specifies the stages involved in the action.
- `--override <override>`: Specifies whether to override existing configurations.
- `--token <token>`: Specifies the authentication token.
- `--resume <resume>`: Specifies whether to resume from a previous state.
- `--git <git>`: Specifies the Git repository information.

### utils.py

The `utils.py` module contains utility functions for logging, parameter validation, and other helper functions.

#### Functions:
- `log(message)`: Logs a message to the console.
    - `message (str)`: The message to log.
- `validate_params(params)`: Validates the provided parameters.
    - `params (dict)`: The parameters to validate.
- `helper_function()`: A placeholder for other helper functions.

### devops_jenkins.py

The `devops_jenkins.py` module defines the `DevOpsJenkins` class, which handles the validation, preparation, and execution of Jenkins jobs.

#### Class: DevOpsJenkins

- `__init__(self, config)`: Initializes the DevOpsJenkins instance with the provided configuration.
    - `config (dict)`: The configuration for the Jenkins jobs.

- `validate(self)`: Validates the Jenkins job configuration.

- `prepare(self)`: Prepares the Jenkins job for execution.

- `execute(self)`: Executes the Jenkins job.


#### Run Arguments:
- `--config <config>`: Specifies the configuration file for the  job.
- `--job <job>`: Specifies the Jenkins job to run.
- `--params <params>`: Specifies additional parameters for the job.
