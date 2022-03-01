import fpgroups, pickle, time, sys
import multiprocessing

def subtree_list(data):
    rank, max_degree, rels, strategy, sims_node = data
    return fpgroups.SimsTree(rank, max_degree, rels, strategy, sims_node).list()

def main(rank, max_degree, depth, relators):
    if sys.platform != 'win32':
        context = multiprocessing.get_context('fork')
    else:
        context = multiprocessing.get_context('spawn')
    pool = context.Pool(multiprocessing.cpu_count())
    tree = fpgroups.SimsTree(rank, max_degree, relators, 'spin_short')
    nodes = tree.bloom(depth)
    inputs = [(rank, max_degree, relators, 'spin_short', node) for node in nodes]
    subgroups = sum(pool.map(subtree_list, inputs), [])
    for subgroup in subgroups:
        print(pickle.dumps(subgroup))

if __name__ == '__main__':
    rank, max_degree, depth = (int(arg) for arg in sys.argv[1:4])
    relators = sys.argv[4:]
    main(rank, max_degree, depth, relators)
