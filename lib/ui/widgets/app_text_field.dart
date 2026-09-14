import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Text field used across the app.
///
/// On some Android keyboards Flutter can believe Shift is still held after
/// tapping the on-screen Shift key. A tap then extends the selection from the
/// start of the text instead of moving the cursor. A single tap should always
/// place the cursor, so an extended selection caused by a tap is collapsed
/// to the tapped position.
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? suffix;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final InputBorder? border;
  final bool filled;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.suffix,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.border,
    this.filled = false,
  });

  const AppTextField.number({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.suffix,
    this.errorText,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  }) : keyboardType = const TextInputType.numberWithOptions(decimal: true),
       textCapitalization = TextCapitalization.none,
       maxLines = 1,
       minLines = null,
       obscureText = false,
       border = null,
       filled = false;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  Offset? _lastPointerDown;

  RenderEditable? _findRenderEditable() {
    RenderEditable? found;
    void visit(RenderObject object) {
      if (found != null) return;
      if (object is RenderEditable) {
        found = object;
        return;
      }
      object.visitChildren(visit);
    }

    final root = context.findRenderObject();
    if (root != null) visit(root);
    return found;
  }

  void _collapseTapSelection() {
    final controller = widget.controller;
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final tapPosition = _lastPointerDown;
    final editable = _findRenderEditable();
    final offset = tapPosition != null && editable != null && editable.attached
        ? editable.getPositionForPoint(tapPosition).offset
        : selection.extentOffset;
    controller.selection = TextSelection.collapsed(
      offset: offset.clamp(0, controller.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Listener(
      onPointerDown: (event) => _lastPointerDown = event.position,
      child: TextField(
        controller: w.controller,
        focusNode: w.focusNode,
        keyboardType: w.keyboardType,
        textInputAction: w.textInputAction,
        textCapitalization: w.textCapitalization,
        maxLines: w.obscureText ? 1 : w.maxLines,
        minLines: w.minLines,
        autofocus: w.autofocus,
        obscureText: w.obscureText,
        enableSuggestions: !w.obscureText,
        autocorrect: !w.obscureText,
        enabled: w.enabled,
        onChanged: w.onChanged,
        onSubmitted: w.onSubmitted,
        onTap: _collapseTapSelection,
        decoration: InputDecoration(
          labelText: w.label,
          hintText: w.hint,
          helperText: w.helper,
          helperMaxLines: 3,
          suffixText: w.suffix,
          errorText: w.errorText,
          filled: w.filled,
          border: w.border ?? const OutlineInputBorder(),
        ),
      ),
    );
  }
}
