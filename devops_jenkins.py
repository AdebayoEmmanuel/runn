import utils

class DevOpsJenkins:
    def __init__(self, action, env, reg, stages, override, token, resume, git):
        self.action = action
        self.env = env
        self.reg = reg
        self.stages = stages
        self.override = override
        self.token = token
        self.resume = resume
        self.git = git
    
    def validate_inputs(self):
        utils.logging_info("Validating inputs...")
    
    def prepare_queue(self):
        utils.logging_info("Preparing job queue...")
    
    def execute_queue(self):
        utils.logging_info("Executing job queue...")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("action", help="Action to perform")
    parser.add_argument("env", help="Environment")
    parser.add_argument("reg", help="Region")
    parser.add_argument("stages", help="Stages")
    parser.add_argument("override", help="Override parameters")
    parser.add_argument("token", help="Token")
    parser.add_argument("resume", help="Resume deployment")
    parser.add_argument("git", help="Git parameters")
    args = parser.parse_args()

    jenkins = DevOpsJenkins(args.action, args.env, args.reg, args.stages, args.override, args.token, args.resume, args.git)
    jenkins.validate_inputs()
    jenkins.prepare_queue()
    jenkins.execute_queue()
