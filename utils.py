import datetime
import sys

def logging_info(message):
    timestamp = datetime.datetime.now().isoformat()
    print(f"[INFO] [{timestamp}] {message}")

def logging_warning(message):
    timestamp = datetime.datetime.now().isoformat()
    print(f"[WARNING] [{timestamp}] {message}", file=sys.stderr)

def logging_error(message):
    timestamp = datetime.datetime.now().isoformat()
    print(f"[ERROR] [{timestamp}] {message}", file=sys.stderr)
