#include <iostream>
#include <chrono>

#include "simsTree.h"
#include "stackedSimsNode.h"

#include <list>
#include <thread>
#include <atomic>

namespace low_index {

SimsTree::SimsTree(
    const SimsNode &root,
    const std::vector<Relator> &short_relators,
    const std::vector<Relator> &long_relators)
  : _relators{short_relators, long_relators}
  , _root(root)
{

}

SimsTree::SimsTree(
    const RankType rank,
    const DegreeType max_degree,
    const std::vector<Relator> &short_relators,
    const std::vector<Relator> &long_relators)
  : SimsTree(
      SimsNode(rank, max_degree, short_relators.size()),
      short_relators,
      long_relators)
{
}

std::vector<SimsNode>
SimsTree::list(const unsigned int thread_num) const
{
    const unsigned int resolved_thread_num =
        (thread_num > 0)
            ? thread_num
            : std::thread::hardware_concurrency();

    if (resolved_thread_num == 1) {
        return _list_single_threaded();
    } else {
        return _list_multi_threaded(resolved_thread_num);
    }
}

std::vector<SimsNode>
SimsTree::_list_single_threaded() const
{
    std::vector<SimsNode> nodes;

    SimsNodeStack stack(_root);

    _recurse(stack.get_node(), _relators, &nodes);

    return nodes;
}

static
void
_merge_vectors(
    const std::vector<SimsTree::_PendingWorkInfo> &infos,
    std::vector<SimsNode> * result)
{
    for (const auto &info : infos) {
        for (const SimsNode &n : info.complete_nodes) {
            result->push_back(n);
        }
        _merge_vectors(info.children, result);
    }
}

void
SimsTree::_recurse(
    const StackedSimsNode &n,
    const ShortAndLongRelators &relators,
    std::vector<SimsNode> * result,
    _ThreadContext * c)
{
    if(n.is_complete()) {
        if (!n.relators_lift(relators.long_relators)) {
            return;
        }
        SimsNode copy(n);
        if (!copy.relators_may_lift(relators.short_relators)) {
            return;
        }
        result->push_back(std::move(copy));
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
        if (!new_subgraph.relators_may_lift(relators.short_relators)) {
            continue;
        }
        if (!new_subgraph.may_be_minimal()) {
            continue;
        }
        if (c && !c->should_recurse(new_subgraph)) {
            continue;
        }
        _recurse(new_subgraph, relators, result, c);
    }
}

void
SimsTree::_thread_worker(
    _ThreadSharedContext * ctx) const
{
    while(true) {
        size_t index;
        std::vector<_PendingWorkInfo> * work_infos = nullptr;
        
        {
            std::unique_lock<std::mutex> lk(ctx->m);
            index = ctx->index;

            const size_t n = ctx->work_infos->size();

            if (index < n) {
                ctx->num_working_threads++;
                ctx->index++;
                work_infos = ctx->work_infos;
            } else {
                if (index == n) {
                    ctx->index++;
                    ctx->interrupt_thread.exchange(true);
                }
            
                if (ctx->num_working_threads == 0) {
                    ctx->wake_up_threads.notify_all();
                    break;
                }

                ctx->wake_up_threads.wait(lk);
            }
        }

        if (work_infos) {
            _PendingWorkInfo &work_info = (*work_infos)[index];
            SimsNodeStack stack(work_info.root);
            _ThreadContext c(ctx, &work_info);
            SimsTree::_recurse(stack.get_node(), _relators, &work_info.complete_nodes, &c);
            if (c.was_interrupted) {
                std::unique_lock<std::mutex> lk(ctx->m);
                ctx->work_infos = &work_info.children;
                ctx->index = 0;
            }
            ctx->num_working_threads--;
            ctx->wake_up_threads.notify_all();
        }
    }
}
    
std::vector<SimsNode>
SimsTree::_list_multi_threaded(
    const unsigned int thread_num) const
{
    _ThreadSharedContext ctx(_root);

    std::vector<std::thread> threads;
    threads.reserve(thread_num);
    for (unsigned int i = 0; i < thread_num; i++) {
        threads.emplace_back(
            &SimsTree::_thread_worker,
            this, &ctx);
    }

    for (std::thread &t : threads) {
        t.join();
    }
    
    std::vector<SimsNode> result;

    _merge_vectors(ctx.root_infos, &result);
    
    return result;
}

} // Namespace low_index
