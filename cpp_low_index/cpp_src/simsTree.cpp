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
    std::cout << "Entering _recurse" << std::endl;

    std::cout << n.num_edges << " " << n.rank << " " << n.degree << std::endl;
    
    if(n.is_complete()) {
        std::cout << "complete" << std::endl;
        
        node->push_back(n);
    } else {
        SimsNode tmp(n);
        tmp.sprout(relators);
//        const SimsNode * hacky = &n;
//        const_cast<SimsNode*>(hacky)->sprout({});
        for (const SimsNode &child : tmp._children) {

            std::cout << "Processing child" << std::endl;
            
            _recurse(child, node);
        }
    }
}
