#ifndef _SIMS_TREE_H
#define _SIMS_TREE_H

#include "heapedSimsNode.h"

#include <atomic>

class StackedSimsNode;

class SimsTree
{
public:
    SimsTree(
        const HeapedSimsNode &root,
        const std::vector<std::vector<int>> &short_relators,
        const std::vector<std::vector<int>> &long_relators);

    SimsTree(
        int rank,
        int max_degree,
        const std::vector<std::vector<int>> &short_relators,
        const std::vector<std::vector<int>> &long_relators);

    HeapedSimsNode root;

    std::vector<HeapedSimsNode> list();

    std::vector<HeapedSimsNode> bloom(size_t n);

    std::vector<HeapedSimsNode> threaded(
        const std::vector<HeapedSimsNode> &nodes,
        unsigned int thread_num);

    std::vector<HeapedSimsNode> list_multithreaded(
        size_t bloom_size, unsigned int thread_num);

private:
    const std::vector<std::vector<int>> short_relators;
    const std::vector<std::vector<int>> long_relators;

    void _recurse(const StackedSimsNode &n, std::vector<HeapedSimsNode> *nodes);

    void _thread(const std::vector<HeapedSimsNode> &nodes,
                 std::vector<std::vector<HeapedSimsNode>> * result);
    
    std::atomic_size_t _index;
};

#endif
