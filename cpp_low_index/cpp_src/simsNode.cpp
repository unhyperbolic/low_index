#include <iostream>

#include "simsNode.h"

SimsNode::SimsNode(const int rank,
                   const int max_degree,
                   const int num_relators)
 : CoveringSubgraph(rank, max_degree, num_relators)
 , _lift_indices(num_relators * max_degree, 0)
 , _lift_vertices(num_relators * max_degree, 0)
{
}

void
SimsNode::sprout(const std::vector<std::vector<int>> &relators)
{
    
    const std::pair<IntType, IntType> slot = first_empty_slot();

    std::cout << "sprout" << std::endl;
    
    if (slot == std::pair<IntType, IntType>{ 0, 0 }) {
        return;
    }

    std::vector<int> targets;

    if (degree < max_degree) {
        targets.push_back(degree + 1);
    }

    if (slot.first > 0) {
        for (int n = 0; n < degree; n++) {
            if (incoming[n * rank + slot.first - 1] == 0) {
                targets.push_back(n+1);
            }
        }
    } else {
        for (int n = 0; n < degree; n++) {
            if (incoming[n * rank - slot.first - 1] == 0) {
                targets.push_back(n+1);
            }
        }
    }

    _children.reserve(targets.size());
    
    for (const int n : targets) {
        std::cout << "target " << n << std::endl;
        
        SimsNode new_subgraph(*this);
        if (true) {
            new_subgraph.add_edge(slot.first, slot.second, n);
            _children.push_back(std::move(new_subgraph));
        }
    }
}
