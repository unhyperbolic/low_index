#ifndef LOW_INDEX_SIMS_TREE_BASIS_H
#define LOW_INDEX_SIMS_TREE_BASIS_H

#include "simsNode.h"

namespace low_index {

class SimsTreeBasis
{
public:
    virtual std::vector<SimsNode> list() = 0;

protected:
    SimsTreeBasis(
        RankType rank,
        DegreeType max_degree,
        const std::vector<Relator> &short_relators,
        const std::vector<Relator> &long_relators)
      : _root(rank, max_degree, short_relators.size())
      , _short_relators(short_relators)
      , _long_relators(long_relators)
    {
    }
   
    const SimsNode _root;
    const std::vector<Relator> _short_relators;
    const std::vector<Relator> _long_relators;
};

}

#endif
