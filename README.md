# DevOps Automation Project

This project includes a set of Python scripts for automating DevOps tasks, triggered by a Rundeck job.

## File Structure

```
project/
├── start.py
├── utils.py
├── devops_jenkins.py
├── srv_region.yaml
└── region_abbreviations.yaml
```

## Setup Instructions

1. **Navigate to the Project Directory**

```bash
cd project/
```

2. **Install the Required Dependencies**

We need `PyYAML` for parsing YAML files.

```bash
pip install pyyaml
```

## Usage

The script uses subcommands and requires several arguments. The general syntax is:

```bash
python start.py <subcommand> --action ACTION --env ENV --reg REG --stages STAGES --override OVERRIDE --token TOKEN --resume RESUME --git GIT
```

## Example

```bash
python start.py validate \
  --action deploy \
  --env dev \
  --reg us-east-1 \
  --stages build,test \
  --override yes \
  --token abc123 \
  --resume no \
  --git true
```
### start.py

The `start.py` script is the entry point of the project. It performs the following tasks:

- **Argument Parsing**: Uses `argparse` to parse command-line arguments and defines subcommands (`validate`, `prepare`, `execute`) with their required arguments.
- **Loading YAML Files**: Reads `srv_region.yaml` and `region_abbreviations.yaml` to load valid regions and environment
