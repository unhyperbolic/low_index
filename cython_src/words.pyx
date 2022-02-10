"""
Words, reduced words and cyclically reduced words in a free group.
"""
alphabet = 'ZYXWVUTSRQPONMLKJIHGFEDCBA abcdefghijklnmopqrstuvwxyz'

cdef class cWord():
    cdef int rank, start, length, size
    cdef char* buffer

    def __cinit__(self, int rank, letters):
        self.rank = rank
        self.start = 1
        self.length = len(letters)
        self.size = self.length + 2
        self.buffer = <char *>PyMem_Malloc(self.size)

    def __init__(self, int rank, letters):
        cdef int x  # GRRR C allows negative chars but Cython doesn't.
        if isinstance(letters, str):
            byteseq = [alphabet.index(l) - 26 for l in letters]
        for n in range(len(byteseq)):
            x = byteseq[n]
            x = x if x < 128 else x - 256  # GRRR No negative chars in Cython.
            if x == 0 or x > self.rank or x < -self.rank :
                raise ValueError(
                    'Invalid letter {0}; must be non-zero and in [-{1},{1}]'.format(
                        x, self.rank)
                    )
            self.buffer[self.start + n] = x

    def __dealloc__(self):
        PyMem_Free(self.buffer)

    def __len__(self):
        return self.length

    def __repr__(self):
        return 'cWord(%d, %s)'%(
            self.rank,
            [x if x < 128 else x - 256 for x in
                 self.buffer[self.start:self.start + self.length]])

    def __str__(self):
        word = []
        for i in range(self.start, self.start + self.length):
            word.append(alphabet[self.buffer[i] + 26])
        return ''.join(word)

    cdef repack(self):
        cdef char *old = self.buffer
        self.size = self.length + 2
        self.buffer = <char *>PyMem_Malloc(self.size)
        self.buffer[0] = 0
        for i in range(self.length):
            self.buffer[i] = old[self.start + i]
        self.start = 1
        PyMem_Free(old)
        
    cdef reduce(self):
        """
        This method reduces a word in a single pass though the word.
        """

        cdef int head = self.start, tail = self.start, length = self.length
        while True:
            tail += 1
            if tail >= length:
                break
            if self.buffer[head] + self.buffer[tail] == 0:
                self.length -= 2
                head -= 1
                continue
            head += 1
            self.buffer[head] = self.buffer[tail]
        if head < tail:
            self.buffer[head + 1] = self.buffer[tail]

    cdef cyclically_reduce(self):
        """
        Cancels beginning and end letters only.  Assumes the word is reduced.
        """
        cdef int start = self.start
        cdef int end = self.start + self.length - 1
        while end > start:
            if self.buffer[start] + self.buffer[end] == 0:
                start += 1
                end -= 1
                self.length -= 2
            else:
                break
        self.start = start

cdef class ReducedWord(cWord):

    def __init__(self, int rank, letters):
        cWord.__init__(self, rank, letters)
        cWord.reduce(self)

    cdef _next_letter(self, int n):
        if n > 0:
            return -n
        if n > -self.rank:
            return 1 - n
        return 1

    cpdef _increment(self):
        """
        Private method!  Rewrites the buffer with the next word in the
        (length, lex) ordering, reallocating memory if necessary.
        [[This is harder that one would expect]].
        """
        cdef char next
        cdef char* buf = &self.buffer[self.start]
        cdef int len = self.length
        # Special case for the trivial word
        if len == 0:
            buf[0] = 1
            self.length = 1
            return
        # Easy case; just increase the last letter.
        if buf[len - 1] + self.rank != 0:
            next = self._next_letter(buf[len - 1])
            # But do not create a cancellation
            if len > 1 and (next + buf[len - 2] == 0):
                next = self._next_letter(next)
            if next != 1:
                buf[len - 1] = next
                return
        # Backtracking in the Cayley graph of the free group.
        n = len - 1
        # The word ends in a power of the next to biggest generator.
        if buf[n] == self.rank:
            while n > 0 and buf[n - 1] == self.rank:
                buf[n] = 1
                n -= 1
            buf[n] = -self.rank
        # The word ends in a power of the biggest generator.
        elif buf[n] + self.rank == 0:
            while buf[n] + self.rank == 0:
                n -= 1
            if n >= 0:
                buf[n] = self._next_letter(buf[n])
                if n > 0 and buf[n-1] + buf[n] == 0:
                    buf[n] = self._next_letter(buf[n])
                if buf[n] + 1 == 0:
                    for n in range(n + 1, self.length):
                        buf[n] = -1
                else:
                    for n in range(n + 1, self.length):
                        buf[n] = 1
        if n < 0:
            # We need to increase the length.
            # The first word will be a power of the first generator.
            if self.start < 1:
                self.repack()
            self.start -= 1
            self.length += 1
            buf = &self.buffer[self.start]
            for i in range(self.length):
                buf[i] = 1

    def __copy__(self):
        if self.length == 0:
            return ReducedWord(self.rank, [])
        return ReducedWord(self.rank,
            self.buffer[self.start:self.start + self.length])

cdef class ReducedWords:
    """
    Iterator for reduced words of a given rank with bounded length.
    """
    cdef ReducedWord current
    cdef int rank, max_length

    def __init__(self, int rank, int max_length=1, ReducedWord start=None):
        self.rank = rank
        self.max_length = max_length
        if start:
            self.current = start
        else:
            self.current = ReducedWord(rank, [])

    def __next__(self):
        if self.current.length > self.max_length:
            raise StopIteration
        result = self.current.__copy__()
        self.current._increment()
        return result

    def __iter__(self):
        return self

cdef class CyclicallyReducedWord(ReducedWord):

    def __init__(self, int rank, byteseq):
        ReducedWord.__init__(self, rank, byteseq)
        cWord.cyclically_reduce(self)            
