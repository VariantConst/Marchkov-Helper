import 'package:flutter/material.dart';

class TipDialog extends StatelessWidget {
  final Function() onDismiss;
  final Function() onDoNotShowAgain;

  const TipDialog({
    super.key,
    required this.onDismiss,
    required this.onDoNotShowAgain,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.dialogBackgroundColor, // 使用主题对话框背景色
      title: Text(
        '使用提示',
        style: TextStyle(
            color: theme.textTheme.titleMedium
                ?.color), // {{ edit_1 }} 将 headline6 更改为 titleMedium
      ),
      content: Text(
        '这里是一些使用提示信息。',
        style: TextStyle(
            color: theme.textTheme.bodySmall
                ?.color), // {{ edit_2 }} 将 bodyText2 更改为 bodySmall
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: Text(
            '取消',
            style: TextStyle(color: theme.primaryColor),
          ),
        ),
        TextButton(
          onPressed: onDoNotShowAgain,
          child: Text(
            '不再显示',
            style: TextStyle(color: theme.primaryColor),
          ),
        ),
      ],
    );
  }
}
