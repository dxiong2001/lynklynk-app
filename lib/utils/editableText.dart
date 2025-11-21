import 'package:flutter/material.dart';

class DoubleTapEditableText extends StatefulWidget {
  const DoubleTapEditableText({
    super.key,
    required this.initialText,
    this.hintText = "Double-tap to edit",
    this.onSubmitted,
    this.padding = const EdgeInsets.all(8),
    this.textColor,
    this.fontSize,
    this.borderRadius = 0,
    this.borderColor = Colors.transparent,
    this.backgroundColor = const Color.fromARGB(255, 243, 242, 242),
  });

  final String initialText;
  final String hintText;

  final EdgeInsets padding;
  final ValueChanged<String>? onSubmitted;

  // ✨ New styling attributes
  final Color? textColor;
  final double? fontSize;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  State<DoubleTapEditableText> createState() => _DoubleTapEditableTextState();
}

class _DoubleTapEditableTextState extends State<DoubleTapEditableText>
    with TickerProviderStateMixin {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  late String originalText; // keep original
  final FocusNode _focusNode = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        _finishEditing();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _editing = true);
    originalText = _controller.text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _finishEditing() {
    final text = _controller.text.trimRight();
    if (text.isEmpty) {
      _controller.text = originalText;
    } else {
      widget.onSubmitted?.call(text);
    }

    setState(() => _editing = false);
  }

  TextStyle _baseTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge!.copyWith(
          height: 1.35,
          color: widget.textColor ?? Theme.of(context).colorScheme.onSurface,
          fontSize: widget.fontSize,
        );
  }

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: widget.backgroundColor ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      border: Border.all(
        color: widget.borderColor ?? Theme.of(context).dividerColor,
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: Alignment.topLeft,
      child: Container(
        width: double.infinity,
        padding: widget.padding,
        decoration: decoration,
        child: _editing ? _buildEditor(context) : _buildViewer(context),
      ),
    );
  }

  Widget _buildViewer(BuildContext context) {
    final text = _controller.text.isEmpty ? widget.hintText : _controller.text;
    final isHint = _controller.text.isEmpty;
    final style = _baseTextStyle(context);

    return GestureDetector(
      onDoubleTap: _startEditing,
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          style: isHint
              ? style.copyWith(
                  color: Theme.of(context).hintColor,
                  fontStyle: FontStyle.italic,
                )
              : style,
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.done,
        maxLines: null,
        minLines: 1,
        style: _baseTextStyle(context),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (_) => setState(() {}),
        onEditingComplete: _finishEditing,
      ),
    );
  }
}
