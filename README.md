# DevOps Automation Script

## File Structure

```
project/
├── start.py
├── utils.py
├── devops_jenkins.py
├── srv_region.yaml
└── region_abbreviations.yaml
```

## Instructions

### Navigate to the Project Directory

Ensure you're in the directory containing the scripts and YAML files.

\`\`\`bash
cd project/
\`\`\`

### Install the Required Dependencies

We need \`PyYAML\` for parsing YAML files.

\`\`\`bash
pip install pyyaml
\`\`\`

### Usage

The script uses subcommands and requires several arguments. The general syntax is:

```bash
python start.py <subcommand> --action ACTION --env ENV --reg REG --stages STAGES --override OVERRIDE --token TOKEN --resume RESUME --git GIT
```

### Example

\`\`\`bash
python start.py validate \\
  --action deploy \\
  --env dev \\
  --reg us-east-1 \\
  --stages build,test \\
  --override yes \\
  --token abc123 \\
  --resume no \\
  --git true
```
### start.py

The start.py script is the entry point of the project. It performs the following tasks:

- **Argument Parsing**: Uses argparse to define and parse command-line arguments.
- **Loading YAML Files**: Reads srv_region.yaml and region_abbreviations.yaml to load valid regions and environment abbreviations.
- **Parameter Validation**: Validates the parsed parameters.
- **Logging Parameters**: Logs the validated parameters using utils.logging_info.
- **Creating DevOpsJenkins Instance**: Creates an instance of DevOpsJenkins with the parsed arguments.
- **Executing Commands**: Executes the corresponding method based on the subcommand (validate, prepare, execute).

### utils.py

Contains utility functions used throughout the project:

- **logging_info, logging_warning, logging_error**: Logs informational, warning, and error messages with timestamps.

### devops_jenkins.py

Contains the DevOpsJenkins class, which handles the execution of DevOps tasks:

- **\_\_init\_\_**: Initializes the instance with provided parameters.
- **validate_inputs**: Logs that inputs are being validated.
- **prepare_queue**: Logs that the job queue is being prepared.
- **execute_queue**: Logs that the job queue is being executed.

### srv_region.yaml

Contains valid regions:
\`\`\`yaml
- us-east-1
- us-west-2
- eu-central-1
\`\`\`

### region_abbreviations.yaml

Contains valid environment abbreviations:
\`\`\`yaml
dev: development
qa: quality_assurance
prod: production
