"# cython: profile=True"
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.string cimport memset, memcpy
from libc.stdlib cimport div_t, div
from multiprocessing import Pool, get_context as get_mp_context
import pickle
include "words.pyx"
include "covers.pyx"
