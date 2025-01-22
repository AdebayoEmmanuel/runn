import argparse
import devops_jenkins
import utils
import yaml

def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")

    validate_parser = subparsers.add_parser("validate")
    prepare_parser = subparsers.add_parser("prepare")
    execute_parser = subparsers.add_parser("execute")

    for subparser in (validate_parser, prepare_parser, execute_parser):
        subparser.add_argument("--action", required=True)
        subparser.add_argument("--env", required=True)
        subparser.add_argument("--reg", required=True)
        subparser.add_argument("--stages", required=True)
        subparser.add_argument("--override", required=True)
        subparser.add_argument("--token", required=True)
        subparser.add_argument("--resume", required=True)
        subparser.add_argument("--git", required=True)

    args = parser.parse_args()
    params = vars(args)

    with open('resources/srv_region.yaml', 'r') as file:
        valid_regions = yaml.safe_load(file)['regions']

    with open('resources/region_abbreviations.yaml', 'r') as file:
        valid_abbreviations = yaml.safe_load(file)

    valid_values = {
        'reg': valid_regions,
        'env': list(valid_abbreviations.keys())
    }

    if not utils.validate_parameters(params, valid_values):
        return

    utils.logging_info(f"Parameters: {params}")

    jenkins = devops_jenkins.DevOpsJenkins(
        args.action, args.env, args.reg, args.stages, args.override, args.token, args.resume, args.git
    )

    if args.command == "validate":
        jenkins.validate_inputs()
    elif args.command == "prepare":
        jenkins.prepare_queue()
    elif args.command == "execute":
        jenkins.execute_queue()

if __name__ == "__main__":
    main()
