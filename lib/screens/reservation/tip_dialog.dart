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
        '点击班车按钮预约，再次点击取消预约，长按按钮查看对应班车详情。',
        style: TextStyle(
            color: theme.textTheme.bodyMedium
                ?.color), // {{ edit_2 }} 将 bodyText2 更改为 bodyMedium
      ),
      actions: [
        TextButton(
          onPressed: onDoNotShowAgain,
          child: Text(
            '不再显示',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        TextButton(
          onPressed: onDismiss,
          child: Text(
            '确定',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}
