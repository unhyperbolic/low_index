#include <iostream>

#include "simsTree.h"
#include "stackedSimsNode.h"
#include "simsNodeStack.h"
#include "stackedSimsNode.h"

#include <list>

SimsTree::SimsTree(
    const HeapedSimsNode &root,
    const std::vector<std::vector<int>> &short_relators,
    const std::vector<std::vector<int>> &long_relators)
  : root(root)
  , short_relators(short_relators)
  , long_relators(long_relators)
{
}

SimsTree::SimsTree(
    const int rank,
    const int max_degree,
    const std::vector<std::vector<int>> &short_relators,
    const std::vector<std::vector<int>> &long_relators)
  : SimsTree(
      HeapedSimsNode(rank, max_degree, short_relators.size()),
      short_relators,
      long_relators)
{
}

std::vector<HeapedSimsNode>
SimsTree::list()
{
    std::vector<HeapedSimsNode> nodes;

    SimsNodeStack stack(root);
    
    _recurse(stack.GetNode(), &nodes);

    return nodes;
}

void
SimsTree::_recurse(const StackedSimsNode &n, std::vector<HeapedSimsNode> *nodes)
{
    if(n.is_complete()) {
        if (n.relators_lift(long_relators)) {
            nodes->push_back(n);
        }
    } else {
        const std::pair<CoveringSubgraph::LetterType,
                        CoveringSubgraph::DegreeType> slot =
            n.first_empty_slot();
        const CoveringSubgraph::DegreeType m =
            std::min<CoveringSubgraph::DegreeType>(
                n.degree() + 1,
                n.max_degree());
        for (CoveringSubgraph::DegreeType v = 1; v <= m; v++) {
            if (n.act_by(-slot.first, v) == 0) {
                StackedSimsNode new_subgraph(n);
                new_subgraph.add_edge(slot.first, slot.second, v);
                if (new_subgraph.relators_may_lift(short_relators)) {
                    if (new_subgraph.may_be_minimal()) {
                        _recurse(new_subgraph, nodes);
                    }
                }
            }
        }
    }
}

std::vector<HeapedSimsNode>
SimsTree::bloom(const size_t n)
{
    std::list<HeapedSimsNode> r = { root };

    auto it = r.begin();    
    bool has_incomplete_node = false;

    while (r.size() < n) {
        if (it == r.end()) {
            if (it == r.begin()) {
                break;
            }
            if (!has_incomplete_node) {
                break;
            }
            it = r.begin();
            has_incomplete_node = false;
        }

        if (it->is_complete()) {
            ++it;
        } else {
            const std::pair<CoveringSubgraph::LetterType,
                            CoveringSubgraph::DegreeType> slot =
                it->first_empty_slot();
            const CoveringSubgraph::DegreeType m =
                std::min<CoveringSubgraph::DegreeType>(
                    it->degree() + 1,
                    it->max_degree());
            for (CoveringSubgraph::DegreeType v = 1; v <= m; v++) {
                if (it->act_by(-slot.first, v) == 0) {
                    HeapedSimsNode new_subgraph(*it);
                    new_subgraph.add_edge(slot.first, slot.second, v);
                    if (new_subgraph.relators_may_lift(short_relators)) {
                        if (new_subgraph.may_be_minimal()) {
                            r.insert(it, new_subgraph);
                            has_incomplete_node = true;
                        }
                    }
                }
            }
            it = r.erase(it);
        }
    }

    return std::vector<HeapedSimsNode>(r.begin(), r.end());
}
