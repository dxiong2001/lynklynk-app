import 'package:flutter/material.dart';

class SearchBarDropdown extends StatefulWidget {
  final List<String> items;
  final void Function(String)? onItemSelected;

  const SearchBarDropdown({
    super.key,
    required this.items,
    this.onItemSelected,
  });

  @override
  State<SearchBarDropdown> createState() => _SearchBarDropdownState();
}

class _SearchBarDropdownState extends State<SearchBarDropdown> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _filtered = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  void _onSearchChanged() {
    final query = _controller.text.toLowerCase();
    setState(() {
      _filtered = widget.items
          .where((item) => item.toLowerCase().contains(query))
          .toList();
      _showSuggestions = query.isNotEmpty;
    });
  }

  void _selectItem(String value) {
    _controller.text = value;
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
    if (widget.onItemSelected != null) widget.onItemSelected!(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search...',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.search),
          ),
        ),
        if (_showSuggestions)
          Container(
            constraints: BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final item = _filtered[index];
                return ListTile(
                  title: Text(item),
                  onTap: () => _selectItem(item),
                );
              },
            ),
          ),
      ],
    );
  }
}
