# cython: profile=True
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.string cimport memset, memcpy
from libc.stdlib cimport div_t, div
include "words.pyx"
include "covers.pyx"
