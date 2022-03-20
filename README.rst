Low Index Subgroups
===================

The low_index project provides a Python module which implements a variant
of Charles Sims' Low Index Subgroups algorithm for enumerating all of
the conjugacy classes of subgroups of a finitely presented group with
finite index less than a given bound.

The package is available on pypi, so the simplest way to install it for
Python versions 3.6 - 3.10 is to use pip:

.. code-block:: bash

    pip3 install low-index

Here is a sample computation:

.. code-block:: python

    >>> from low_index import *
    >>>  # Conjugacy classes of subgroups of F_3 with index at most 4: 
    >>> sgps = SimsTree(rank=3, max_degree=4).list()
    >>> len(sgps)
    653
    >>> from snappy import *
    >>> G = Manifold('K11n34').fundamental_group(); G
    Generators:
       a,b,c
    Relators:
       aaBcbbcAc
       aacAbCBBaCAAbbcBc
    >>> # Degree at most 7 covers of the exterior of the Conway knot:
    >>> t = SimsTree(G.num_generators(), 7, G.relators(), num_long_relators=1)
    >>> sgrps = t.list()
    >>> len(sgps)
    52
    >>> sgps[25].permutation_rep()
    [[1, 0, 3, 5, 2, 4], [0, 2, 4, 1, 5, 3], [2, 3, 4, 0, 1, 5]]


Credits
=======

Primarily developed by `Marc Culler <https://marc-culler.info>`_,
`Nathan Dunfield <http://dunfield.info>`_, and `Matthias Goerner
<http://www.unhyperbolic.org/>`_

License
=======

Copyright 2022 by Marc Culler, Nathan Dunfield, Matthias Goerner
and others.

This code is released under the `GNU General Public License, version 2
<http://www.gnu.org/licenses/gpl-2.0.txt>`_ or (at your option) any
later version as published by the Free Software Foundation.

