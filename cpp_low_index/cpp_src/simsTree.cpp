#include <iostream>

#include "simsTree.h"

SimsTree::SimsTree(
    const int rank,
    const int max_degree,
    const std::vector<std::vector<int>> &relators)
  : root(rank, max_degree, relators.size())
  , relators(relators)
{
}

void
SimsTree::pyList()
{
    list();
}

std::vector<SimsNode>
SimsTree::list()
{
    std::vector<SimsNode> nodes;

    _recurse(root, &nodes);
    
    return nodes;
}

void
SimsTree::_recurse(const SimsNode &n, std::vector<SimsNode> *node)
{
    std::cout << n.to_string() << "\n" << std::endl;
    
    if(n.is_complete()) {
        node->push_back(n);
    } else {
        SimsNode tmp(n);

        tmp.sprout(relators);
//        const SimsNode * hacky = &n;
//        const_cast<SimsNode*>(hacky)->sprout({});
        for (const SimsNode &child : tmp._children) {
            _recurse(child, node);
        }
    }
}
