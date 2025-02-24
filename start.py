#!/usr/bin/env python3
import argparse
import yaml
import gitlab
from utils import logging_info, logging_error

def read_auth_config(file_path):
    with open(file_path, 'r') as file:
        config = yaml.safe_load(file)
    return config

def validate(auth_config):
    # Connecting to GitLab
    gl = gitlab.Gitlab(auth_config['git']['repo_url'], private_token=auth_config['git']['repo_token'])

    # Get the project
    project = gl.projects.get(auth_config['project']['project_id'])
    logging_info(f"Connected to GitLab project: {project.name}")

    # Get the pipeline
    pipeline = project.pipelines.get(auth_config['project']['pipeline_id'])
    logging_info(f"Connected to GitLab pipeline: {pipeline.id}")

    # Example operations on the pipeline
    logging_info(f"Pipeline status: {pipeline.status}")
    logging_info(f"Pipeline ref: {pipeline.ref}")
    logging_info(f"Pipeline sha: {pipeline.sha}")

    # List all jobs in the pipeline
    jobs = pipeline.jobs.list()
    for job in jobs:
        logging_info(f"Job {job.id} status: {job.status}")

    # Retry a failed job
    for job in jobs:
        if job.status == 'failed':
            logging_info(f"Retrying job {job.id}")
            job.retry()

    # Trigger a new pipeline
    new_pipeline = project.pipelines.create({'ref': 'main'})
    logging_info(f"Triggered new pipeline: {new_pipeline.id}")

def main():
    # Argument Parsing
    parser = argparse.ArgumentParser(description='DevOps Automation Script')
    parser.add_argument('--auth-file', required=True, help='Path to the auth YAML file')
    parser.add_argument('command', choices=['validate'], help='Command to execute')
    args = parser.parse_args()

    # Logging Parameters
    logging_info(f"Parameters: {vars(args)}")

    # Reading Auth Config
    auth_config = read_auth_config(args.auth_file)

    # Executing Commands
    if args.command == 'validate':
        validate(auth_config)

if __name__ == '__main__':
    main()