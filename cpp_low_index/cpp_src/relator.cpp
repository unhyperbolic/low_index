#include "relator.h"

namespace low_index {

void Relator::push_back(LetterType x) {
    _letters.push_back(x);
}

size_t Relator::size() const {
    return _letters.size();
}
    
void Relator::reserve(size_t n) {
    _letters.reserve(n);
}
    
LetterType Relator::back() const {
    return _letters.back();
}

LetterType &Relator::operator[](int index) {
    return _letters[index];
}

LetterType Relator::operator[](int index) const {
    return _letters[index];
}
    
std::vector<LetterType>::const_iterator Relator::begin() const {
    return _letters.begin();
}

std::vector<LetterType>::const_iterator Relator::end() const {
    return _letters.end();
}
    
bool operator<(const Relator& lhs, const Relator& rhs) {
    return lhs._letters < rhs._letters;
}

bool operator==(const Relator& lhs, const Relator& rhs) {
    return lhs._letters == rhs._letters;
}

}

