from _fpgroups import *
__version__ = '1.0.0'
from fpgroups import ReducedWord

def version():
    return __version__

class FreeGroup:
    groups = {}

    def __new__(cls, *, rank):
        if not isinstance(rank, int) or rank < 1:
            raise ValueError('%s is not a valid rank'%rank)
        if rank not in cls.groups:
            cls.instance = super(FreeGroup, cls).__new__(cls)
            cls.groups[rank] = cls.instance
        return cls.groups[rank]

    def __init__(self, *, rank):
        self.rank = rank

    def __repr__(self):
        return 'FreeGroup(rank=%d)'%self.rank

    def __str__(self):
        return '<free group of rank %d>'%self.rank

    def __call__(self, word):
        return ReducedWord(word, rank=self.rank)
    
