#!/usr/bin/env python3

import argparse
import sys
from utils import logging_info, logging_error
from devops_jenkins import DevOpsJenkins

def main():
    # Argument Parsing
    parser = argparse.ArgumentParser(description='DevOps Automation Script')
    subparsers = parser.add_subparsers(dest='command', required=True)

    # Subcommands and their arguments
    for cmd in ['validate', 'prepare', 'execute']:
        subparser = subparsers.add_parser(cmd)
        subparser.add_argument('--action', required=True)
        subparser.add_argument('--env', required=True)
        subparser.add_argument('--reg', required=True)
        subparser.add_argument('--stages', required=True)
        subparser.add_argument('--override', required=True)
        subparser.add_argument('--token', required=True)
        subparser.add_argument('--resume', required=True)
        subparser.add_argument('--git', required=True)

    args = parser.parse_args()

    # Logging Parameters
    logging_info(f"Parameters: {vars(args)}")

    # Creating DevOpsJenkins Instance
    devops = DevOpsJenkins(args)

    # Executing Commands
    if args.command == 'validate':
        devops.validate_inputs()
    elif args.command == 'prepare':
        devops.prepare_queue()
    elif args.command == 'execute':
        devops.execute_queue()

if __name__ == '__main__':
    main()
