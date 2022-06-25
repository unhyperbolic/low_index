#ifndef LOW_INDEX_SIMS_TREE_H
#define LOW_INDEX_SIMS_TREE_H

#include "simsNode.h"

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
class SimsTree
{
public:
    /// Construct SimsTree with an empty root.
    /// That is a SimsNode for the given rank and max_degree and no edges.
    SimsTree(
        RankType rank,
        DegreeType max_degree,
        const std::vector<Relator> &short_relators,
        const std::vector<Relator> &long_relators);

    /// Find all complete covering subgraphs for which all relators lift.
    /// The parameters do not affect the result, but do affect the performance.
    ///
    /// The number of threads can be determined automatically to match the
    /// number of CPU cores (using std::thread::hardware_concurrency()) by
    /// setting thread_num = 0. To force a certain number of threads,
    /// set thread_num to a positive value. In particular, setting
    /// thread_num = 1 forces the single-threaded execution.
    ///
    /// When using multi-threading, there are two stages. First a work queue
    /// of SimsNodes is generated by single threaded. The work queue is then
    /// (embarassingly parallelly) executed by multiple threads. The size of
    /// the work queue generated is given by bloom_size.
    ///
    /// If bloom_size is too large, the single-threaded stage will take
    /// a long time. If bloom_size is too small, there is a risk that one
    /// of tasks is taking much longer and the other threads run out of work.
    std::vector<SimsNode> list(
        size_t bloom_size,
        unsigned int thread_num) const;

public:
    SimsTree(
        const SimsNode &root,
        const std::vector<Relator> &short_relators,
        const std::vector<Relator> &long_relators);

    // Recursively add edges to n. Add complete covering graphs where
    // all relators lift to nodes. Order is depth-first search.
    void _recurse(
        const StackedSimsNode &n,
        std::vector<SimsNode> *nodes) const;

    class _ThreadSharedContext;
    class _PendingWorkInfo;
    
    void _recurse(
        _ThreadSharedContext * ctx,
        const StackedSimsNode &n,
        _PendingWorkInfo *workInfo) const;

    class _PendingWorkInfo {
    public:
        _PendingWorkInfo(const SimsNode &root) : root(root) { }
        // The node to process.
        const SimsNode root;

        // Filled in by worker thread with complete nodes.
        std::vector<SimsNode> complete_nodes;
        // If worker thread was interrupted, filled with the remaining nodes that need to be processed.
        std::vector<_PendingWorkInfo> pending_work_infos;
    };

    class _ThreadSharedContext {
    public:
        _ThreadSharedContext(const SimsNode &root)
            : root_info(root),
              index(0)
            , interrupt_thread(false)
            , num_working_threads(0)
        {
            root_info.pending_work_infos.push_back(_PendingWorkInfo(root));
            work_infos = &root_info.pending_work_infos;
        }
        
        _PendingWorkInfo root_info;

        // The next thread needs to pick up
        // parent_work_record->work_records[work_records.size() - 1 - index];
        std::vector<_PendingWorkInfo> *work_infos;
        size_t index;
  
        // Interrupted thread needs to set parent_work_record to its own _WorkRecord.
        // Set index to work_recors.size() - 1.
        
        
        // index-- to pick up next work_record. If index is negative,  
        // If index == -1, then set interrupt_thread.
        std::atomic_bool interrupt_thread;

        // Called when thread has added new work_record.
        std::condition_variable wake_up_threads;

        // Number of working threads + 1 if there is any work on the parent_work_record.
        std::atomic_uint num_working_threads;

        std::mutex m;

        std::mutex x;
        
        std::mutex out_mutex;
    };
    
    // Enumerate at least n nodes by recursively adding edges to root in a
    // breadth-first search manner. Note that the order in the returned
    // vector is depth-first search though - so consistent with _recurse.
    std::vector<SimsNode> _bloom(size_t n) const;

    std::vector<SimsNode> _list_single_threaded() const;
    std::vector<SimsNode> _list_multi_threaded(
        size_t bloom_size, unsigned int thread_num) const;

    void _thread_worker(
        const std::vector<SimsNode> &branches,
        std::atomic_size_t * index,
        std::vector<std::vector<SimsNode>> * nested_result) const;

    void _thread_worker_new(
        _ThreadSharedContext * ctx) const;

    
    
    const std::vector<Relator> _short_relators;
    const std::vector<Relator> _long_relators;
    const SimsNode _root;

    mutable bool was_interrupted;
};

} // Namespace low_index

#endif
