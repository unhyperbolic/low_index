#ifndef LOW_INDEX_RELATOR_H
#define LOW_INDEX_RELATOR_H

#include "types.h"

#include <vector>

namespace low_index {

class Relator
{
public:
    void push_back(LetterType x);    
    void reserve(size_t n);
    size_t size() const;
    LetterType back() const;
    LetterType &operator[](int);
    LetterType operator[](int) const;
    std::vector<LetterType>::const_iterator begin() const;
    std::vector<LetterType>::const_iterator end() const;
    template <class InputIterator>
    void insert(std::vector<LetterType>::const_iterator position,
                InputIterator first,
                InputIterator last)
    {
        _letters.insert(position, first, last);
    }

private:
    friend bool operator<(const Relator& lhs, const Relator& rhs);
    friend bool operator==(const Relator& lhs, const Relator& rhs);

    std::vector<LetterType> _letters;
};

bool operator<(const Relator& lhs, const Relator& rhs);
bool operator==(const Relator& lhs, const Relator& rhs);

}
#endif
