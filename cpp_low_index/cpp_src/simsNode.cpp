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

std::vector<SimsNode>
SimsNode::get_children(const std::vector<std::vector<int>> &relators) const
{
    std::vector<SimsNode> children;
    
    const std::pair<int, VertexIndexType> slot = first_empty_slot();

    if (slot == std::pair<int, VertexIndexType>{ 0, 0 }) {
        return {};
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
            if (outgoing[n * rank - slot.first - 1] == 0) {
                targets.push_back(n+1);
            }
        }
    }

    children.reserve(targets.size());

    for (const int n : targets) {
        SimsNode new_subgraph(*this);
        new_subgraph.add_edge(slot.first, slot.second, n);
        if (relators_may_lift(&new_subgraph, relators)) {
            children.push_back(std::move(new_subgraph));
        }
    }

    return children;
}

bool
SimsNode::relators_may_lift(SimsNode * child,
                            const std::vector<std::vector<int>> &relators) const
{
    for (int n = 0; n < relators.size(); n++) {
        for (int v = 0; v < child->degree; v++) {

            const size_t j = n * max_degree + v;
            
            VertexIndexType vertex = _lift_vertices[n * max_degree + v];
            if (vertex == 255) {
                continue;
            }
            if (vertex == 0) {
                vertex = v + 1;
            }
            int i;
            VertexIndexType index = _lift_indices[n * max_degree + v];
            VertexIndexType save;
            int label;
            for (i = index; i < relators[n].size(); i++) {
                label = relators[n][i];
                save = vertex;
                if (label > 0) {
                    vertex = outgoing[rank * (vertex - 1) + label - 1];
                } else {
                    vertex = incoming[rank * (vertex - 1) - label - 1];
                }
                if (vertex == 0) {
                    child->_lift_vertices[j] = save;
                    child->_lift_indices[j] = i;
                    break;
                }
            }

            if (i >= relators[n].size() - 1) {
                if (vertex == 0) {
                    if (!child->verified_add_edge(label, save, v + 1)) {
                        return false;
                    }
                    if (child->is_complete()) {
                        return relators_may_lift(child, relators);
                    }
                }
                if (vertex == v + 1) {
                    child->_lift_vertices[j] = 255;
                    child->_lift_indices[j] = relators[n].size();
                } else {
                    return false;
                }
            }
        }
    }

    return true;
}
