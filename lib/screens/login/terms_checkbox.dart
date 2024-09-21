import 'package:flutter/material.dart';

class TermsCheckbox extends StatelessWidget {
  final bool agreeToTerms;
  final ValueChanged<bool?> onChanged;

  TermsCheckbox({required this.agreeToTerms, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: agreeToTerms,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我同意服务条款',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              Text(
                '继续即表示您同意我们的隐私政策和服务条款',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
