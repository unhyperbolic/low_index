#ifndef LOW_INDEX_RELATOR_H
#define LOW_INDEX_RELATOR_H

#include <vector>
#include <iterator>
#include "types.h"
#include "relator.h"

namespace low_index {

  class Relator {
  private:
    std::vector<LetterType> letters;
  public:
    void push_back(LetterType x);    
    void reserve(size_t n);
    size_t size();
    size_t size() const;
    LetterType back();
    LetterType back() const;
    LetterType operator[](int);
    LetterType operator[](int) const;
    friend bool operator<(const Relator& lhs, const Relator& rhs);
    friend bool operator==(const Relator& lhs, const Relator& rhs);
    std::vector<LetterType>::const_iterator begin() const;
    std::vector<LetterType>::const_iterator end() const;
    void insert(std::vector<LetterType>::const_iterator position,
		std::vector<LetterType>::const_iterator first,
		std::vector<LetterType>::const_iterator last);
  };

}
#endif
