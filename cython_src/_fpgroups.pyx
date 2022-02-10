"# cython: profile=True"
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.string cimport memset, memcpy
include "words.pyx"
include "covers.pyx"
