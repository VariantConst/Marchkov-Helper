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
    return AlertDialog(
      title: Text('使用提示'),
      content: Text('点击按钮变蓝即成功预约,再点一次即可取消。长按可以查看对应班车详情。'),
      actions: [
        TextButton(
          onPressed: onDoNotShowAgain,
          child: Text('不再显示'),
        ),
        TextButton(
          onPressed: onDismiss,
          child: Text('确定'),
        ),
      ],
    );
  }
}
