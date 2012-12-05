#! /usr/bin/env python
# encoding: utf-8
# Jaap Haitsma, 2008

# the following two variables are used by the target "waf dist"
VERSION = '0.1'
APPNAME = 'SubZero'

# these variables are mandatory ('/' are converted automatically)
top = '.'
out = 'build'

def options(opt):
	opt.load('compiler_c')
	opt.load('vala')

def configure(conf):
	conf.load('compiler_c vala')
	conf.check_cfg(package='gio-2.0', atleast_version='2.34.0', mandatory=1, args='--cflags --libs')

def build(bld):
	bld.recurse('subzero examples')
