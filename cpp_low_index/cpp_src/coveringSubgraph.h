#ifndef _COVERING_SUBGRAPH_H_
#define _COVERING_SUBGRAPH_H_

#include <vector>
#include <string>

class CoveringSubgraph
{
public:
    using DegreeType = unsigned char;
    using RankType = unsigned int;
    using LetterType = std::make_signed<RankType>::type;

    CoveringSubgraph(RankType rank,
                     DegreeType max_degree,
                     unsigned int num_relators = 0);

    const RankType rank;
    DegreeType degree;
    const DegreeType max_degree;
    unsigned int num_edges;
    const unsigned int num_relators;
    std::vector<DegreeType> outgoing;
    std::vector<DegreeType> incoming;

    bool is_complete() const {
        return num_edges == rank * degree;
    }

    void add_edge(LetterType letter, DegreeType from_vertex, DegreeType to_vertex);
    bool verified_add_edge(LetterType letter, DegreeType from_vertex, DegreeType to_vertex);

    std::string to_string() const;

    std::vector<std::vector<int>> permutation_rep() const;

    DegreeType act_by(LetterType letter, DegreeType vertex) const;

    std::pair<LetterType, DegreeType> first_empty_slot() const;

protected:
    mutable int _slot_index;

private:
    template<bool check>
    bool _add_edge(LetterType label, DegreeType from_vertex, DegreeType to_vertex);
};

#endif
