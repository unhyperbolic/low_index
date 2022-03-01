"# cython: profile=True"
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.string cimport memset, memcpy
from libc.stdlib cimport div_t, div
from fpgroups import multi
from subprocess import run
import sys
import pickle
import json
include "words.pyx"
include "covers.pyx"
