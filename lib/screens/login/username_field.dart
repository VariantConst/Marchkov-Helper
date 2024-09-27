import 'package:flutter/material.dart';

class UsernameField extends StatelessWidget {
  final FormFieldSetter<String> onSaved;
  final FormFieldValidator<String> validator;

  UsernameField({required this.onSaved, required this.validator});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      decoration: InputDecoration(
        labelText: '学号/职工号/手机号',
        hintText: '请输入您的账号',
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
          Icons.person,
          color: theme.colorScheme.primary,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest, // 修改这里
      ),
      style: theme.textTheme.bodyLarge,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      onSaved: onSaved,
      validator: validator,
    );
  }
}
