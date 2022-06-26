#include <iostream>
#include <chrono>

#include "simsTreeMultiThreaded.h"
#include "stackedSimsNode.h"

#include <list>
#include <thread>
#include <atomic>

namespace low_index {

SimsTreeMultiThreaded::SimsTreeMultiThreaded(
    const RankType rank,
    const DegreeType max_degree,
    const std::vector<Relator> &short_relators,
    const std::vector<Relator> &long_relators,
    const unsigned int thread_num)
  : SimsTreeBasis(rank, max_degree, short_relators, long_relators)
  , _thread_num(thread_num)
{
}

static
void
_merge_vectors(
    const std::vector<SimsTreeMultiThreaded::_Node> &infos,
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
SimsTreeMultiThreaded::_recurse(
    const StackedSimsNode &n,
    std::vector<SimsNode> * result,
    _ThreadContext * c)
{
    if(n.is_complete()) {
        if (!n.relators_lift(_long_relators)) {
            return;
        }
        SimsNode copy(n);
        if (!copy.relators_may_lift(_short_relators)) {
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
        if (!new_subgraph.relators_may_lift(_short_relators)) {
            continue;
        }
        if (!new_subgraph.may_be_minimal()) {
            continue;
        }

        if (!c->was_interrupted) {
            if (!n.is_complete() && c->shared_ctx->interrupt_thread.exchange(false)) {
                c->was_interrupted = true;
            }
        }
        if (c->was_interrupted) {
            c->work_info->children.push_back(_Node(new_subgraph));
            continue;
        }

        _recurse(new_subgraph, result, c);
    }
}

void
SimsTreeMultiThreaded::_thread_worker(
    _ThreadSharedContext * ctx)
{
    while(true) {
        size_t index;
        std::vector<_Node> * work_infos = nullptr;

        {
            std::unique_lock<std::mutex> lk(_mutex);
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
            _Node &work_info = (*work_infos)[index];
            SimsNodeStack stack(work_info.root);
            _ThreadContext c(ctx, &work_info);
            _recurse(stack.get_node(), &work_info.complete_nodes, &c);
            if (c.was_interrupted) {
                std::unique_lock<std::mutex> lk(_mutex);
                ctx->work_infos = &work_info.children;
                ctx->index = 0;
            }
            ctx->num_working_threads--;
            ctx->wake_up_threads.notify_all();
        }
    }
}

std::vector<SimsNode>
SimsTreeMultiThreaded::list()
{
    _ThreadSharedContext ctx(_root);

    std::vector<std::thread> threads;
    threads.reserve(_thread_num);
    for (unsigned int i = 0; i < _thread_num; i++) {
        threads.emplace_back(
            &SimsTreeMultiThreaded::_thread_worker,
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
