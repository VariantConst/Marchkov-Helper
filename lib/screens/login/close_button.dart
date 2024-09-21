import 'package:flutter/material.dart';

class CloseButtonWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: IconButton(
        icon: Icon(
          Icons.close,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () {
          // 关闭操作，例如返回上一页
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
