#ifndef _SIMS_TREE_H
#define _SIMS_TREE_H

#include "simsNode.h"

class SimsTree
{
public:
    SimsTree(
        int rank,
        int max_degree,
        const std::vector<std::vector<int>> &short_relators,
        const std::vector<std::vector<int>> &long_relators);

    SimsNode root;

    std::vector<SimsNode> list();
    
private:
    const std::vector<std::vector<int>> short_relators;
    const std::vector<std::vector<int>> long_relators;

    void _recurse(const SimsNode &n, std::vector<SimsNode> *node);
};

#endif
