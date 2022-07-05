#include "relator.h"

namespace low_index {

  void Relator::push_back(LetterType x) {
    letters.push_back(x);
  }
  size_t Relator::size() {
    return letters.size();
  }
  size_t Relator::size() const {
    return letters.size();
  }
  void Relator::reserve(size_t n) {
    letters.reserve(n);
  }
  LetterType Relator::back() {
    return letters.back();
  }
  LetterType Relator::back() const {
    return letters.back();
  }
  LetterType Relator::operator[](int index) {
    return letters[index];
  }
  LetterType Relator::operator[](int index) const {
    return letters[index];
  }
  bool operator<(const Relator& lhs, const Relator& rhs) {
    return lhs.letters < rhs.letters;
  }
  bool operator==(const Relator& lhs, const Relator& rhs) {
    return lhs.letters == rhs.letters;
  }
  std::vector<LetterType>::const_iterator Relator::begin() const {
    return letters.begin();
  }
  std::vector<LetterType>::const_iterator Relator::end() const {
    return letters.end();
  }
  void Relator::insert(std::vector<LetterType>::const_iterator position,
	      std::vector<LetterType>::const_iterator first,
	      std::vector<LetterType>::const_iterator last) {
    letters.insert(position, first, last);
  }
}
