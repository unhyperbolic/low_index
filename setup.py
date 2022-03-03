from setuptools import setup
from Cython.Build import cythonize
import re
import os
os.environ['CFLAGS'] = '-O3'

version = re.search("__version__ = '(.*)'",
                    open('python_src/__init__.py').read()).group(1)
setup(
    name = 'low_index',
    version = version,
    packages = ['low_index'],
    package_dir = {'low_index':'python_src'},
    ext_modules = cythonize(['cython_src/_low_index.pyx'],
        compiler_directives={'language_level' : "3"})
)
