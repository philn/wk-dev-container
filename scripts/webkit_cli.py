
import os
import sys
import argparse
import subprocess
import shlex

WEBKIT_HOME = os.environ['WEBKIT_HOME']

SCRIPTS_DIRECTORY = os.path.join(WEBKIT_HOME, 'Tools', 'Scripts')
sys.path.insert(0, SCRIPTS_DIRECTORY)
from webkitpy.port import configuration_options, platform_options

class OptionParser:
    def __init__(self, extra_groups=[]):
        self.option_parser = argparse.ArgumentParser(usage="%(prog)s [options]", add_help=False)
        groups = [("Platform options", platform_options()), ("Configuration options", configuration_options())] + extra_groups

        # Convert options to argparse, so that we can use parse_known_args() which is not supported in optparse.
        # FIXME: Globally migrate to argparse. https://bugs.webkit.org/show_bug.cgi?id=213463
        for group_name, group_options in groups:
            option_group = self.option_parser.add_argument_group(group_name)

            for option in group_options:
                # Skip deprecated option
                if option.get_opt_string() != "--target":
                    default = None
                    if option.default != ("NO", "DEFAULT"):
                        default = option.default

                    kw = dict(action=option.action, dest=option.dest, help=option.help, default=default)
                    if option.action != "store_true":
                        kw['const'] = option.const
                    option_group.add_argument(option.get_opt_string(), **kw)

    def parse_known_args(self, argv):
        options, args = self.option_parser.parse_known_args(argv)
        if not options.configuration:
            options.configuration = "Release"
        return options, args

    def print_help(self):
        self.option_parser.print_help()

def runtime_environment():
    if not os.environ.get('WEBKIT_SDK_LOCAL_DEPS'):
        return os.environ.copy()

    build_dir = os.path.join(WEBKIT_HOME, 'WebKitBuild', 'deps-build')
    if not os.path.isdir(build_dir):
        return os.environ.copy()

    command = ['meson', 'devenv', '-C', build_dir, '--dump']
    proc = subprocess.run(command, capture_output=True, text=True)
    if proc.returncode != 0:
        raise Exception(proc.returncode)
    local_env = proc.stdout.strip()

    env = os.environ.copy()
    for line in [line for line in local_env.splitlines() if not line.startswith("export")]:
        tokens = shlex.split(line)[0].split("=")
        var_name, contents = tokens[0], "=".join(tokens[1:])
        if var_name not in env:
            env[var_name] = contents
        elif var_name.endswith('PATH'):
            env[var_name] = f"{env[var_name]}:{contents}"
    return env
