import doctest
import inspect
import fpgroups
import types
from doctest import DocTestFinder, DocTestParser, DocTestRunner

def fix_module_doctest(module):
    """
    Extract docstrings from cython functions that would be skipped by doctest
    otherwise.
    """
    module.__test__ = {}
    for name in dir(module):
        value = getattr(module, name)
        # Avoid duplicate tests for python classes.
        try:
            if value.__module__ == module.__name__:
                continue
        except AttributeError:
            pass
        if inspect.isclass(value) or inspect.isfunction(value):
            if value.__doc__ and isinstance(value.__doc__, str):
                print('Including doctests for Cython class %s.'%name)
                module.__test__[name] = value.__doc__

def doctest_module(module, verbose=False):
    finder = doctest.DocTestFinder(parser=DocTestParser())
    failed, attempted = 0, 0
    if isinstance(module, types.ModuleType):
        fix_module_doctest(module)
        runner = doctest.DocTestRunner(verbose=verbose)
        for test in finder.find(module):
            runner.run(test)
        result = runner.summarize()
    else:
        result = module(verbose=verbose)
    failed += result.failed
    attempted += result.attempted
    print(result)

def runtests(verbose=False):
    doctest_module(fpgroups, verbose=verbose)
