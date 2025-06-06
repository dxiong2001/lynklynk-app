import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SmartTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final void Function()? onShiftEnter;

  // Standard TextField params
  final InputDecoration? decoration;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool expands;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final EdgeInsets scrollPadding;
  final bool enableSuggestions;
  final bool enableInteractiveSelection;
  final TextDirection? textDirection;
  final ScrollPhysics? scrollPhysics;
  final Color? cursorColor;

  const SmartTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.onShiftEnter,
    this.decoration,
    this.style,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.autofocus = false,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.inputFormatters,
    this.expands = false,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.enableSuggestions = true,
    this.enableInteractiveSelection = true,
    this.textDirection,
    this.scrollPhysics,
    this.cursorColor,
  });

  @override
  State<SmartTextField> createState() => _SmartTextFieldState();
}

class _SmartTextFieldState extends State<SmartTextField> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;
  bool _shouldDisposeFocus = false;
  bool _shouldDisposeController = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _shouldDisposeFocus = widget.focusNode == null;

    _controller = widget.controller ?? TextEditingController();
    _shouldDisposeController = widget.controller == null;
  }

  @override
  void dispose() {
    if (_shouldDisposeFocus) _focusNode.dispose();
    if (_shouldDisposeController) _controller.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isEnter = event.logicalKey == LogicalKeyboardKey.enter;
    final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftRight);

    if (isEnter && isShiftPressed) {
      widget.onShiftEnter?.call();
      return KeyEventResult.handled;
    } else if (isEnter) {
      final text = _controller.text;
      final selection = _controller.selection;

      final newText = text.replaceRange(selection.start, selection.end, '\n');
      _controller.text = newText;
      _controller.selection =
          TextSelection.collapsed(offset: selection.start + 1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: widget.decoration,
        style: widget.style,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.textInputAction,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        readOnly: widget.readOnly,
        enabled: widget.enabled,
        maxLines: widget.maxLines ?? null,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
        onSubmitted: widget.onSubmitted,
        inputFormatters: widget.inputFormatters,
        expands: widget.expands,
        textAlign: widget.textAlign,
        textAlignVertical: widget.textAlignVertical,
        scrollPadding: widget.scrollPadding,
        enableSuggestions: widget.enableSuggestions,
        enableInteractiveSelection: widget.enableInteractiveSelection,
        textDirection: widget.textDirection,
        scrollPhysics: widget.scrollPhysics,
        cursorColor: widget.cursorColor,
      ),
    );
  }
}
