#include <iostream>
#include <chrono>

#include "simsTreeMultiThreaded.h"
#include "stackedSimsNode.h"

#include <thread>

namespace low_index {

SimsTreeMultiThreaded::SimsTreeMultiThreaded(
    const RankType rank,
    const DegreeType max_degree,
    const std::vector<Relator> &short_relators,
    const std::vector<Relator> &long_relators,
    const unsigned int thread_num)
  : SimsTreeBasis(rank, max_degree, short_relators, long_relators)
  , _thread_num(thread_num)
  , _nodes(nullptr)
  , _node_index(0)
  , _recursion_stop_requested(false)
  , _num_working_threads(0)
{
}

void
SimsTreeMultiThreaded::_recurse(
    const StackedSimsNode &n,
    _Node * const result)
{
    if(n.is_complete()) {
        if (!n.relators_lift(_long_relators)) {
            return;
        }
        SimsNode copy(n);
        if (!copy.relators_may_lift(_short_relators)) {
            return;
        }
        result->complete_nodes.push_back(std::move(copy));
        return;
    }

    const std::pair<LetterType, DegreeType> slot = n.first_empty_slot();
    const DegreeType m = std::min<DegreeType>(n.degree() + 1, n.max_degree());
    for (DegreeType v = 1; v <= m; v++) {
        if (n.act_by(-slot.first, v) != 0) {
            continue;
        }
        StackedSimsNode new_subgraph(n);
        new_subgraph.add_edge(slot.first, slot.second, v);
        if (!new_subgraph.relators_may_lift(_short_relators)) {
            continue;
        }
        if (!new_subgraph.may_be_minimal()) {
            continue;
        }

        if (!result->stopped_recursion) {
            if (!n.is_complete() && _recursion_stop_requested.exchange(false)) {
                result->stopped_recursion = true;
            }
        }
        if (result->stopped_recursion) {
            result->children.emplace_back(new_subgraph);
            continue;
        }

        _recurse(new_subgraph, result);
    }
}

void
SimsTreeMultiThreaded::_thread_worker()
{
    while(true) {
        size_t index;
        std::vector<_Node> * nodes = nullptr;

        {
            std::unique_lock<std::mutex> lk(_mutex);
            index = _node_index;

            const size_t n = _nodes->size();

            if (index < n) {
                _num_working_threads++;
                _node_index++;
                nodes = _nodes;
            } else {
                if (index == n) {
                    _node_index++;
                    _recursion_stop_requested.exchange(true);
                }

                if (_num_working_threads == 0) {
                    _wake_up_threads.notify_all();
                    break;
                }

                _wake_up_threads.wait(lk);
            }
        }

        if (nodes) {
            _Node &node = (*nodes)[index];
            SimsNodeStack stack(node.root);
            _recurse(stack.get_node(), &node);
            if (node.stopped_recursion) {
                std::unique_lock<std::mutex> lk(_mutex);
                _nodes = &node.children;
                _node_index = 0;
            }
            _num_working_threads--;
            _wake_up_threads.notify_all();
        }
    }
}

void
SimsTreeMultiThreaded::_merge_vectors(
    const std::vector<_Node> &nodes,
    std::vector<SimsNode> * const result)
{
    for (const auto &node : nodes) {
        for (const SimsNode &complete_node : node.complete_nodes) {
            result->push_back(complete_node);
        }
        _merge_vectors(node.children, result);
    }
}

std::vector<SimsNode>
SimsTreeMultiThreaded::list()
{
    std::vector<_Node> root_nodes{_Node(_root)};
    _nodes = &root_nodes;
    
    std::vector<std::thread> threads;
    threads.reserve(_thread_num);
    for (unsigned int i = 0; i < _thread_num; i++) {
        threads.emplace_back(&SimsTreeMultiThreaded::_thread_worker, this);
    }

    for (std::thread &t : threads) {
        t.join();
    }

    std::vector<SimsNode> result;
    _merge_vectors(root_nodes, &result);
    return result;
}

} // Namespace low_index
