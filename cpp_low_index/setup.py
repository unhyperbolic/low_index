import sys
from setuptools import setup, Extension

__version__ = "0.0.1"

sources = [
    "cpp_src/lowIndex.cpp",
    "cpp_src/coveringSubgraph.cpp",
    "cpp_src/simsNode.cpp",
    "cpp_src/stackedSimsNode.cpp",
    "cpp_src/abstractSimsNode.cpp",
    "cpp_src/simsTree.cpp",
    "cpp_src/wrapLowIndex.cpp",
    "cpp_src/wrapCoveringSubgraph.cpp",
    "cpp_src/wrapSimsNode.cpp",
    "cpp_src/wrapAbstractSimsNode.cpp",
    "cpp_src/wrapSimsTree.cpp",
    "cpp_src/wrapModule.cpp"
]

if sys.platform.startswith('win'):
    extra_compile_args = ['/Ox', '/std:c++11']
else:
    extra_compile_args = ['-O3', '-std=c++11']

ext_modules = [
    Extension(
        name = 'cpp_low_index',
        sources = sources,
        extra_compile_args = extra_compile_args)
]

setup(
    name="cpp_low_index",
    version=__version__,
    author="MMN",
    author_email="",
    url="",
    description="A test project using pybind11",
    long_description="",
    ext_modules=ext_modules,
#    extras_require={"test": "pytest"},
    # Currently, build_ext only provides an optional "highest supported C++
    # level" feature, but in the future it may provide more features.
    zip_safe=False,
    python_requires=">=3.6",
)
