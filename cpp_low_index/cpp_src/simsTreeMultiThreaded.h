#ifndef LOW_INDEX_SIMS_TREE_MULTI_THREADED_H
#define LOW_INDEX_SIMS_TREE_MULTI_THREADED_H

#include "simsTreeBasis.h"

#include <atomic>
#include <condition_variable>

namespace low_index {

class StackedSimsNode;

/// A class to recursively add edges to a SimsNode to find all covering
/// subgraphs up to a certain degree such that the given relators lift.
///
/// In other words, a class to find all low-index subgroup H of a finitely
/// presented group G with rank generators and short_relators and long_relators
/// as relations. The maximal index H in G is max_degree.
///
/// As explained in AbstractSimsNode, the short_relators are checked while
/// recursively adding edges and the long_relators only once the covering
/// subgraph is complete.
///
/// The class only stores the root of the tree that is to be visited
/// recursively.
///
class SimsTreeMultiThreaded : public SimsTreeBasis
{
public:
    /// Construct SimsTreeMultiThreaded with an empty root.
    /// That is a SimsNode for the given rank and max_degree and no edges.
    SimsTreeMultiThreaded(
        RankType rank,
        DegreeType max_degree,
        const std::vector<Relator> &short_relators,
        const std::vector<Relator> &long_relators,
        unsigned int thread_num);

    /// Find all complete covering subgraphs for which all relators lift.
    /// The parameters do not affect the result, but do affect the performance.
    ///
    /// The number of threads can be determined automatically to match the
    /// number of CPU cores (using std::thread::hardware_concurrency()) by
    /// setting thread_num = 0. To force a certain number of threads,
    /// set thread_num to a positive value. In particular, setting
    /// thread_num = 1 forces the single-threaded execution.
    ///
    std::vector<SimsNode> list() override;

public:
    class _Node {
    public:
        _Node(const SimsNode &root) : root(root) { }
        // The node to process.
        const SimsNode root;

        // Filled by worker thread with complete nodes.
        std::vector<SimsNode> complete_nodes;
        // Filled by worker thread with nodes that still need to be
        // recursed if worker thread was prompted to stop recursing.
        std::vector<_Node> children;
    };

    class _ThreadSharedContext {
    public:
        _ThreadSharedContext(const SimsNode &root)
            : root_infos{_Node(root)}
            , work_infos(&root_infos)
            , index(0)
            , interrupt_thread(false)
        {
        }

        std::vector<_Node> root_infos;

        std::vector<_Node> *work_infos;
        size_t index;

        std::atomic_bool interrupt_thread;

        std::condition_variable wake_up_threads;
    };

    class _ThreadContext {
    public:
        _ThreadContext(
                _ThreadSharedContext * const shared_ctx,
                _Node * const work_info)
          : shared_ctx(shared_ctx)
          , work_info(work_info)
          , was_interrupted(false)
        {
        }

        _ThreadSharedContext * const shared_ctx;
        _Node * const work_info;
        bool was_interrupted;
    };

    void _thread_worker(
        _ThreadSharedContext * ctx);

    void _recurse(
        const StackedSimsNode &n,
        _Node * result,
        _ThreadContext * c = nullptr);

    const unsigned int _thread_num;

    std::mutex _mutex;
    std::atomic_uint _num_working_threads;
};

} // Namespace low_index

#endif
