from setuptools import setup, Command, Extension
import os
import sys
import re
import shutil
from glob import glob

if sys.platform.startswith('win'):
    extra_compile_args = ['/Ox']
else:
    extra_compile_args = ['-O3', '-g']

low_index = Extension(
    name = 'low_index._low_index',
    sources = ['cython_src/_low_index.c'],
    extra_compile_args = extra_compile_args
)

version = eval(re.search("__version__\s+=\s+('.*')",
                    open('python_src/__init__.py').read()).group(1))

setup(name = 'low_index',
      version = version,
      description = 'Enumerates low index subgroups of a finitely presented group',
      long_description = open('README.rst').read(),
      long_description_content_type = 'text/x-rst',
      url = 'https://github.com/3-manifolds/low_index',
      author = 'Marc Culler, Nathan M. Dunfield and Matthias Goerner',
      author_email = 'culler@marc-culler.info, nathan@dunfield.info, enischte@gmail.com',
      license = 'GPLv2+',
      python_requires = '>= 3',
      packages = ['low_index'],
      package_dir = {'low_index':'python_src'},
      zip_safe = False,
      ext_modules = [low_index],
      classifiers = [
           'Development Status :: 5 - Production/Stable',
           'Intended Audience :: Science/Research',
           'License :: OSI Approved :: GNU General Public License v2 or later (GPLv2+)',
           'Operating System :: OS Independent',
           'Programming Language :: C',
           'Programming Language :: C++',
           'Programming Language :: Python',
           'Programming Language :: Cython',
           'Topic :: Scientific/Engineering :: Mathematics',
        ],
)
