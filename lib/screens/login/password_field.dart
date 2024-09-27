import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  final FormFieldSetter<String> onSaved;
  final FormFieldValidator<String> validator;

  PasswordField({required this.onSaved, required this.validator});

  @override
  PasswordFieldState createState() => PasswordFieldState(); // 修改这里
}

class PasswordFieldState extends State<PasswordField> {
  // 修改这里
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请输入您的密码',
        labelStyle: TextStyle(color: theme.colorScheme.primary),
        hintStyle: TextStyle(color: theme.hintColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
        prefixIcon: Icon(
          Icons.lock,
          color: theme.colorScheme.primary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility : Icons.visibility_off,
            color: theme.colorScheme.primary,
          ),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest, // 修改这里
      ),
      style: theme.textTheme.bodyLarge,
      obscureText: _obscureText,
      onSaved: widget.onSaved,
      validator: widget.validator,
    );
  }
}
