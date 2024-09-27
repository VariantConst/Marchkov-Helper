import 'package:flutter/material.dart';

class UsernameField extends StatelessWidget {
  final FormFieldSetter<String> onSaved;
  final FormFieldValidator<String> validator;

  UsernameField({required this.onSaved, required this.validator});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      decoration: InputDecoration(
        labelText: '用户名',
        labelStyle: TextStyle(
            color: theme.textTheme.bodyMedium
                ?.color), // {{ edit_1 }} 将 bodyText1 更改为 bodyMedium
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.primaryColor),
        ),
        // ... existing code ...
      ),
      // ... existing code ...
    );
  }
}
