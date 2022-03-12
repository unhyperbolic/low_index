from setuptools import setup, Extension
#from Cython.Build import cythonize
import re
import os
import sys

if sys.platform.startswith('win'):
    extra_compile_args = ['/Ox']
else:
    extra_compile_args = ['-O3']

low_index = Extension(
    name = 'low_index._low_index',
    sources = ['cython_src/_low_index.pyx'],
    compiler_directives = {'language_level' : "3"},
    extra_compile_args = extra_compile_args
)

setup(ext_modules = [low_index],
    long_description=open('README.rst').read(),
    long_description_content_type='text/x-rst')
