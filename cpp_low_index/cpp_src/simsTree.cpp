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
  : _short_relators(short_relators)
  , _long_relators(long_relators)
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

void
SimsTree::_recurse(
    const StackedSimsNode &n,
    std::vector<SimsNode> *nodes) const
{
    if(n.is_complete()) {
        if (n.relators_lift(_long_relators)) {
            SimsNode copy(n);
            if (copy.relators_may_lift(_short_relators)) {
                nodes->push_back(std::move(copy));
            }
        }
    } else {
        const std::pair<LetterType, DegreeType> slot =
            n.first_empty_slot();
        const DegreeType m =
            std::min<DegreeType>(
                n.degree() + 1,
                n.max_degree());
        for (DegreeType v = 1; v <= m; v++) {
            if (n.act_by(-slot.first, v) == 0) {
                StackedSimsNode new_subgraph(n);
                new_subgraph.add_edge(slot.first, slot.second, v);
                if (new_subgraph.relators_may_lift(_short_relators)) {
                    if (new_subgraph.may_be_minimal()) {
                        _recurse(new_subgraph, nodes);
                    }
                }
            }
        }
    }
}

std::vector<SimsNode>
SimsTree::_bloom(const size_t n) const
{
    std::list<SimsNode> r = { _root };

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
            const std::pair<LetterType, DegreeType> slot =
                it->first_empty_slot();
            const DegreeType m =
                std::min<DegreeType>(
                    it->degree() + 1,
                    it->max_degree());
            for (DegreeType v = 1; v <= m; v++) {
                if (it->act_by(-slot.first, v) == 0) {
                    SimsNode new_subgraph(*it);
                    new_subgraph.add_edge(slot.first, slot.second, v);
                    if (new_subgraph.relators_may_lift(_short_relators)) {
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

    return std::vector<SimsNode>(r.begin(), r.end());
}

std::vector<SimsNode>
SimsTree::list(
    const size_t bloom_size,
    const unsigned int thread_num) const
{
    const unsigned int resolved_thread_num =
        (thread_num > 0)
            ? thread_num
            : std::thread::hardware_concurrency();

    if (bloom_size <= 1 || resolved_thread_num == 1000) {
        return _list_single_threaded();
    } else {
        return _list_multi_threaded(bloom_size, resolved_thread_num);
    }
}

std::vector<SimsNode>
SimsTree::_list_single_threaded() const
{
    std::vector<SimsNode> nodes;

    SimsNodeStack stack(_root);

    _recurse(stack.get_node(), &nodes);

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

// _recurse(const StackedSimsNode &n,
//    const std::pair<std::vector<Relator>, std::vector<Relator>> &relators,
//    std::vector<SimsNode> *result,
//    _ThreadContext * ctx);

void
SimsTree::_recurse(
    _ThreadSharedContext * ctx,
    const StackedSimsNode &n,
    _PendingWorkInfo *work_info,
    _ThreadContext * c) const
{
    if(n.is_complete()) {
        if (n.relators_lift(_long_relators)) {
            SimsNode copy(n);
            if (copy.relators_may_lift(_short_relators)) {
                work_info->complete_nodes.push_back(copy);
//                    std::move(copy));
            }
        }
    } else {
        const std::pair<LetterType, DegreeType> slot =
            n.first_empty_slot();
        const DegreeType m =
            std::min<DegreeType>(
                n.degree() + 1,
                n.max_degree());
        for (DegreeType v = 1; v <= m; v++) {
            if (n.act_by(-slot.first, v) == 0) {
                StackedSimsNode new_subgraph(n);
                new_subgraph.add_edge(slot.first, slot.second, v);
                if (new_subgraph.relators_may_lift(_short_relators)) {
                    if (new_subgraph.may_be_minimal()) {
                        if (was_interrupted) {
                            work_info->children.push_back(
                                _PendingWorkInfo(new_subgraph));
                        } else {
                            if (!new_subgraph.is_complete() && ctx->interrupt_thread.exchange(false)) {
                                was_interrupted = true;
                                work_info->children.push_back(
                                    _PendingWorkInfo(new_subgraph));
                            } else {
                                _recurse(ctx, new_subgraph, work_info, c);
                            }
                        }
                    }
                }
            }
        }
    }
}
    
void
SimsTree::_thread_worker_new(
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
            SimsTree tree(work_info.root, _short_relators, _long_relators);
            tree.was_interrupted = false;
            SimsNodeStack stack(work_info.root);
            _ThreadContext c(ctx, &work_info);
            tree._recurse(ctx, stack.get_node(), &work_info, &c);
            if (tree.was_interrupted) {
                {
                    std::unique_lock<std::mutex> lk(ctx->m);
                    ctx->work_infos = &work_info.children;
                    ctx->index = 0;
                }
            }
            ctx->num_working_threads--;
            ctx->wake_up_threads.notify_all();
        } /* else {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            
//            std::mutex m;
//            std::unique_lock<std::mutex> lk(ctx->x);
//            ctx->wake_up_threads.wait(lk);
} */
    }
}
    
std::vector<SimsNode>
SimsTree::_list_multi_threaded(
    const size_t bloom_size,
    const unsigned int thread_num) const
{
    _ThreadSharedContext ctx(_root);

    std::vector<std::thread> threads;
    threads.reserve(thread_num);
    for (unsigned int i = 0; i < thread_num; i++) {
        threads.emplace_back(
            &SimsTree::_thread_worker_new,
            this, &ctx);
    }

    for (std::thread &t : threads) {
        t.join();
    }

//    std::cout << "Merging" << std::endl;
    
    std::vector<SimsNode> result;

    _merge_vectors(ctx.root_infos, &result);

//    std::cout << "Merged" << std::endl;
    
    return result;
    
    /*
    const std::vector<SimsNode> branches = _bloom(bloom_size);
    std::vector<std::vector<SimsNode>> nested_result(branches.size());

    std::atomic_size_t index(0);

    std::vector<std::thread> threads;
    threads.reserve(branches.size());
    for (unsigned int i = 0; i < thread_num; i++) {
        threads.emplace_back(
            &SimsTree::_thread_worker,
            this, branches, &index, &nested_result);
    }

    for (std::thread &t : threads) {
        t.join();
    }

    return _merge_vectors(std::move(nested_result));
    */
}

void
SimsTree::_thread_worker(
    const std::vector<SimsNode> &branches,
    std::atomic_size_t * const index,
    std::vector<std::vector<SimsNode>> * nested_result) const
{
    while(true) {
        const size_t i = (*index)++;

        if (i >= branches.size()) {
            break;
        }

        const SimsTree t(branches[i], _short_relators, _long_relators);
        (*nested_result)[i] = t._list_single_threaded();
    }
}

} // Namespace low_index
