import fpgroups, pickle, time

degree = 7
rels = ['aaBcbbcAc', 'aacAbCBBaCAAbbcBc']

s = fpgroups.SimsTree(3, degree, rels, 'spin_short')
start = time.time()
print('init count: ', len(s.list()))
print('time:', time.time() - start)

t = fpgroups.SimsTree(3, degree, rels, 'spin_short')
blooms = t.bloom(6)
print('bloom count:', len(blooms))

def plant(sims_node):
    return fpgroups.SimsTree(3, degree, rels, 'spin_short', sims_node).list()


import multiprocessing
pool = multiprocessing.Pool(8)

start = time.time()
ans = sum(pool.map(plant, blooms), [])
print('final count:', len(ans))
print('time:', time.time() - start)
