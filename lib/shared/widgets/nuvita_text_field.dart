import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class NuvitaTextField extends StatefulWidget {
  const NuvitaTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.validator,
    this.prefixIcon,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final void Function(String)? onChanged;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;

  @override
  State<NuvitaTextField> createState() => _NuvitaTextFieldState();
}

class _NuvitaTextFieldState extends State<NuvitaTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword && _obscureText,
      validator: widget.validator,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
      focusNode: widget.focusNode,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: AppColors.secondary, size: 22)
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.secondary,
                  size: 22,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              )
            : null,
      ),
    );
  }
}