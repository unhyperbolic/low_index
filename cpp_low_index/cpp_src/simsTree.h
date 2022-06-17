#ifndef _SIMS_TREE_H
#define _SIMS_TREE_H

#include "heapedSimsNode.h"

#include <atomic>

class StackedSimsNode;

class SimsTree
{
public:
    SimsTree(
        int rank,
        int max_degree,
        const std::vector<std::vector<int>> &short_relators,
        const std::vector<std::vector<int>> &long_relators);

    std::vector<HeapedSimsNode> list(
        size_t bloom_size,
        unsigned int thread_num);

private:
    SimsTree(
        const HeapedSimsNode &root,
        const std::vector<std::vector<int>> &short_relators,
        const std::vector<std::vector<int>> &long_relators);

    void _recurse(const StackedSimsNode &n, std::vector<HeapedSimsNode> *nodes);
    std::vector<HeapedSimsNode> _bloom(size_t n);

    std::vector<HeapedSimsNode> _list_single_threaded();
    std::vector<HeapedSimsNode> _list_multi_threaded(
        size_t bloom_size, unsigned int thread_num);

    std::vector<HeapedSimsNode> _threaded(
        const std::vector<HeapedSimsNode> &nodes,
        unsigned int thread_num);
    void _thread(const std::vector<HeapedSimsNode> &nodes,
                 std::vector<std::vector<HeapedSimsNode>> * result);
    
    const std::vector<std::vector<int>> _short_relators;
    const std::vector<std::vector<int>> _long_relators;
    const HeapedSimsNode _root;

    std::atomic_size_t _index;
};

#endif
