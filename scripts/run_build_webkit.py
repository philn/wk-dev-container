# Copyright (C) 2020 Igalia S.L.
# -*- coding: utf-8 -*-
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA 02110-1301, USA.

from __future__ import print_function
import logging
import optparse
import os
import shlex
import subprocess
import sys
import time
import traceback
import tomllib as toml

SOURCE_DIRECTORY = os.environ['WEBKIT_HOME']

sys.path.insert(0, os.path.join(SOURCE_DIRECTORY, 'Tools', 'Scripts'))
from webkitpy.common.system.executive import Executive
from webkitcorepy.string_utils import elapsed

from webkit_cli import OptionParser, runtime_environment

_log = logging.getLogger(__name__)

def main(argv):
    groups = [("Build options", [
        optparse.make_option("--cmakeargs", action="append", default=[],
                             help=("One or more optional CMake flags (e.g. --cmakeargs=\"-DFOO=bar -DCMAKE_PREFIX_PATH=/usr/local\"")),
        optparse.make_option("--no-ninja", action="store_true", default=False,
                             help=("Disable Ninja for CMake builds. In this case make will be used. Default: False")),
        optparse.make_option("--no-experimental-features", action="store_true", default=False,
                             help=("Disable experimental CMake features. Default: False")),
        optparse.make_option("--no-developer-mode", action="store_true", default=False,
                             help=("Disable developer mode. Default: False")),
        optparse.make_option("--verbose", action="store_true", default=False,
                             help=("Enable verbose output")),
        optparse.make_option("--configure-only", action="store_true", default=False,
                             help=("Only run the CMake configure step. Don't attempt any compilation job")),
        optparse.make_option("--git-update", action="store_true", default=False,
                             help=("Update the git checkout before building")),

    ])]
    parser = OptionParser(extra_groups=groups)
    options, args = parser.parse_known_args(argv)

    if "-h" in args or "--help" in args:
        parser.print_help()
        if not options.platform:
            print("\nTo see the available options on a specific platform, supply it on the command-line, for example --gtk --help")
        return 0

    try:
        return run(options, args, sys.stderr)
    except BaseException as e:
        if isinstance(e, Exception):
            print('\n%s raised: %s' % (e.__class__.__name__, str(e)), file=sys.stderr)
            traceback.print_exc(file=sys.stderr)
        return 1

def run(options, args, logging_stream):
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    startTime = time.time()
    builder = Builder(options)
    exitCode = builder.run(args)
    buildTime = elapsed(time.time() - startTime)
    _log.debug("Build completed, Exit status: %d" % exitCode)
    if exitCode == -1:
        # This was a configure run, so don't print any additional message.
        return 0
    if exitCode == 0:
        resultStr = "is now built! 🎉"
        is_debug = "--debug" if options.configuration == "Debug" else ""
        extra = f"\nTo run MiniBrowser with this newly-built code, use\nTools/Scripts/run-minibrowser --{options.platform} {is_debug}"
    else:
        resultStr = "build failed. 😟"
        extra = ""
    print("―" * 55)
    print("WebKit %s (build time: %s).%s" % (resultStr, buildTime, extra))
    print("―" * 55)
    return exitCode

class Builder:
    def __init__(self, options):
        self._options = options
        self._env = runtime_environment()
        self._makeargs = []

    def numberOfCPUs(self):
        for key in ("SCCACHE_NUM_CPUS", "NUMBER_OF_PROCESSORS"):
            try:
                return int(os.environ[key])
            except:
                continue
        return None

    def maxCPULoad(self):
        try:
            return int(os.environ["MAX_CPU_LOAD"])
        except:
            return None

    def run(self, args):
        self._makeargs = args

        if self._options.git_update:
            self.execute(('git', '-C', SOURCE_DIRECTORY, 'pull'))

        if self._options.configure_only:
            self._generateBuildSystemFromCMakeProject(force=True)
            return -1

        minusJOverride = True
        for opt in self._makeargs:
            if opt.startswith("-j"):
                minusJOverride = False
                break
        if minusJOverride:
            numberOfCPUs = self.numberOfCPUs()
            if numberOfCPUs:
                self._makeargs.append("-j%d" % numberOfCPUs)

        minusLOverride = True
        for opt in self._makeargs:
            if opt.startswith("-l"):
                minusLOverride = False
                break
        if minusLOverride:
            maxCPULoad = self.maxCPULoad()
            if maxCPULoad is not None and maxCPULoad > 0:
                self._options.makeargs.append("-l%d" % maxCPULoad)

        sccache_enabled = 'WEBKIT_USE_SCCACHE' in os.environ.keys()
        if sccache_enabled:
            sccache_env = os.environ.copy()
            sccache_env.update({"SCCACHE_START_SERVER": "1"})
            self.execute(["sccache"], env=sccache_env)

        if 'WEBKIT_SDK_LOCAL_DEPS' in os.environ.keys():
            self._buildLocalDeps()

        try:
            return self._buildCMakeProject()
        finally:
            if sccache_enabled:
                self.execute(["sccache", "--stop-server"])

    def _buildLocalDeps(self):
        src_dir = os.path.join(SOURCE_DIRECTORY, 'Tools', 'flatpak', 'local-projects')
        build_dir = os.path.join(SOURCE_DIRECTORY, 'WebKitBuild', 'deps-build')
        if not os.path.exists(os.path.join(build_dir, 'build.ninja')):
            projects = '-Dsubprojects=%s' % os.environ['WEBKIT_SDK_LOCAL_DEPS']
            options = shlex.split(os.environ.get('WEBKIT_SDK_LOCAL_DEPS_OPTIONS', ''))
            args = ['meson', 'setup', projects] + options + [src_dir, build_dir]
            self.execute(args, check=True)

        self.execute(('meson', 'compile', '-C', build_dir), check=True)

    def _cmakeArgFromOption(self, name, value):
        value_type = type(value)
        value_str = None
        if value_type == bool:
            value_str = 'ON' if value else 'OFF'
        elif value_type == str:
            value_str = value
        elif value_type == list:
            value_str = ','.join(value)

        if value_str is not None:
            return f'-D{name.upper()}={value_str}'

        return ''

    def _cmakeArgsFromConfig(self, config):
        def process_section(name):
            args = []
            for (name, value) in config[name].items():
                arg = self._cmakeArgFromOption(name, value)
                if arg:
                    args.append(arg)
            return args

        return process_section('common') + process_section(self._options.platform)

    def _cmakeArgsFromFeatures(self):
        args = []
        if not self._options.no_experimental_features:
            args.append("-DENABLE_EXPERIMENTAL_FEATURES=ON")

        try:
            with open(os.path.join(SOURCE_DIRECTORY, "features.toml"), "rb") as f:
                data = toml.load(f)
                args.extend(self._cmakeArgsFromConfig(data))
        except FileNotFoundError:
            pass

        return args

    def _mkdir(self, path):
        try:
            os.makedirs(path)
        except OSError:
            pass

    def _shouldRemoveCMakeCache(self, buildArgs):
        cachePath = os.path.join(self._buildDir(), "build-webkit-options.txt")
        contents = " ".join(buildArgs)

        def writeCache():
            with open(cachePath, "w") as f:
                f.write(contents)

        if not os.path.isfile(cachePath):
            self._mkdir(self._buildDir())
            writeCache()
            return True

        with open(cachePath) as f:
            options = set(f.read().strip().split())
            writeCache()
            if options != set(buildArgs):
                return True

        cacheFileModifiedTime = os.stat(cachePath).st_mtime

        for filename in ("OptionsCommon.cmake", "Options%s.cmake" % self._cmakePortName()):
            commonOptions = os.path.join(SOURCE_DIRECTORY, "Source", "cmake", filename)
            if os.path.isfile(commonOptions):
                mtime = os.stat(commonOptions).st_mtime
                if cacheFileModifiedTime < mtime:
                    return True

        return False

    def _cmakeCachePath(self):
        return os.path.join(self._buildDir(), "CMakeCache.txt")

    def _cmakeGeneratedBuildFile(self):
        if not self._options.no_ninja:
            filename = "build.ninja"
        else:
            filename = "Makefile"
        return os.path.join(self._buildDir(), filename)

    def _cmakePortName(self):
        # untested: playstation, win-cairo, mac, jsc-only
        mapping = {"gtk": "GTK", "wpe": "WPE", "playstation": "PlayStation", "win-cairo": "WinCairo",
                   "mac": "Mac", "jsc-only": "JSCOnly"}
        return mapping.get(self._options.platform, "")

    def _baseProductDir(self):
        baseProductDir = os.environ.get("WEBKIT_OUTPUTDIR", os.path.join(SOURCE_DIRECTORY, 'WebKitBuild'))
        return os.path.join(baseProductDir, self._cmakePortName())

    def _buildDir(self):
        try:
            # Useful mostly for CMake configure jobs done for clangd-indexer.
            return os.environ['WEBKIT_BUILDDIR']
        except KeyError:
            return os.path.join(self._baseProductDir(), self._options.configuration)

    def execute(self, args, cwd=None, env=None, check=False):
        _log.debug(" ".join(args))
        if check:
            return subprocess.check_call(args, cwd=cwd, env=env)
        return subprocess.call(args, cwd=cwd, env=env)

    def _asanEnabled(self):
        asan = os.path.join(self._buildDir(), "ASan")
        if not os.path.isfile(asan):
            return False

        with open(asan) as f:
            data = f.read()
            return data.strip().lower() == "yes"

    def _generateBuildSystemFromCMakeProject(self, force=False):
        cache_file = self._cmakeCachePath()
        build_file = self._cmakeGeneratedBuildFile()

        features = self._cmakeArgsFromFeatures()
        if self._shouldRemoveCMakeCache(features) and os.path.isfile(cache_file):
            os.unlink(cache_file)

        if force:
            if os.path.isfile(cache_file):
                os.unlink(cache_file)
            if os.path.isfile(build_file):
                os.unlink(build_file)
        else:
            # We try to be smart about when to rerun cmake, so that we can have faster incremental builds.
            if os.path.isfile(cache_file) and os.path.isfile(build_file):
                return

        self._cmakeConfigure(self._buildDir())

    def _cmakeConfigure(self, build_path):
        port = self._cmakePortName()
        cmd = ["cmake", "-S", SOURCE_DIRECTORY, "-B", build_path, f"-DPORT={port}",
               "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
               f"-DCMAKE_BUILD_TYPE={self._options.configuration}"]

        if not self._options.no_developer_mode:
            cmd.append("-DDEVELOPER_MODE=ON")

        if not self._options.no_ninja:
            cmd.append("-GNinja")

        if self._asanEnabled():
            cmd.append("-DENABLE_SANITIZERS=address")

        cmd.extend(self._cmakeArgsFromFeatures())
        for cmakearg in self._options.cmakeargs:
            cmd.extend(cmakearg.split(' '))
        self.execute(cmd, env=self._env)

    def _buildCMakeGeneratedProject(self):
        cmd = ["cmake", "--build", self._buildDir(), "--config", self._options.configuration]
        if self._makeargs:
            cmd.extend(self._makeargs)
        print(f"Running {' '.join(cmd)}")
        return self.execute(cmd, env=self._env)

    def _buildCMakeProject(self):
        self._generateBuildSystemFromCMakeProject()
        return self._buildCMakeGeneratedProject()
