class Suggestions {
  final _terms = <String>[];

  void initTerms(List<String> terms) {
    _terms.clear();
    for (int i = 0; i < terms.length; i++) {
      _terms.add(terms[i]);
    }
  }

  void printSuggestions() {
    print(_terms);
  }

  void addTerm(String term) => _terms.add(term);
  void clearSuggestions() => _terms.clear();
  void setTerm(String term, int index) {
    _terms[index] = term;
  }

  void insertTerm(
    int index,
    String term,
  ) {
    _terms.insert(index, term);
  }

  String getTerm(int index) {
    return _terms[index];
  }

  List<String> getTerms() {
    List<String> termsTemp = List.from(_terms);
    termsTemp.removeWhere((item) => item.isEmpty);
    return termsTemp;
  }

  void swapLocation(int oldIndex, int newIndex) {
    _terms.insert(newIndex, _terms.removeAt(oldIndex));
  }

  void removeAt(int index) => _terms.removeAt(index);

  List<String> getSuggestion(String filterString,
      {bool contains = false, bool caseSensitive = false}) {
    if (filterString.isEmpty) {
      return [];
    }
    if (!caseSensitive) {
      filterString = filterString.toLowerCase();
    }
    if (!contains) {
      return caseSensitive
          ? _terms.where((term) => term.startsWith(filterString)).toList()
          : _terms
              .where((term) => term.toLowerCase().startsWith(filterString))
              .toList();
    } else {
      List<String> startsWithList = caseSensitive
          ? _terms.where((term) => term.startsWith(filterString)).toList()
          : _terms
              .where((term) => term.toLowerCase().startsWith(filterString))
              .toList();
      List<String> containsList = caseSensitive
          ? _terms.where((term) => term.contains(filterString, 1)).toList()
          : _terms
              .where((term) => term.toLowerCase().contains(filterString, 1))
              .toList();
      return startsWithList + containsList;
    }
  }
}
