import 'package:flutter/material.dart';
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';
import 'package:kazumi/services/update/update_channel.dart';

class UpdateSourceStep extends StatelessWidget {
  const UpdateSourceStep({super.key});

  @override
  Widget build(BuildContext context) => const OnboardingStepLayout(
    leading: OnboardingStepIcon(
      icon: Icons.system_update_rounded,
      shape: OnboardingIconShape.cookie,
    ),
    title: UpdateChannel.title,
    subtitle: UpdateChannel.notice,
    child: OnboardingHint(
      text: '软件更新来自自己的 GitHub Releases；播放源更新只更新规则，不会安装原版 Kazumi。',
    ),
  );
}
