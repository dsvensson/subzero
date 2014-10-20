#! /usr/bin/env python
# encoding: utf-8
# Jaap Haitsma, 2008

import os

# the following two variables are used by the target "waf dist"
VERSION = '0.1'
APPNAME = 'SubZero'

# these variables are mandatory ('/' are converted automatically)
top = '.'
out = 'build'

SO_REUSEPORT_FRAGMENT = """
#include <sys/socket.h>
int main(int argc, char **argv) {
	return SO_REUSEPORT;
}
"""

def options(opt):
	opt.load('compiler_c vala waf_unit_test')

def configure(conf):
	conf.load('compiler_c vala waf_unit_test')
	conf.check_vala((0, 24, 0))
	conf.check_cfg(package='gio-2.0', atleast_version='2.34.0', args='--cflags --libs')
	conf.check_cfg(package='gobject-introspection-1.0', mandatory=False)
	conf.find_program('g-ir-compiler', var='G_IR_COMPILER', mandatory=False)

	if 'CFLAGS' not in os.environ:
		conf.env.append_unique("CFLAGS", ["-g", "-O0", "-fdiagnostics-show-option"])

	conf.env.append_unique('CFLAGS', ['-fPIC', '-DPIC'])

	conf.env.VALADEFINES = []
	if conf.check_cc(fragment=SO_REUSEPORT_FRAGMENT, mandatory=False):
		conf.env.VALADEFINES = ['HAVE_SO_REUSEPORT']

def build(bld):
	bld.recurse('subzero examples tests')
