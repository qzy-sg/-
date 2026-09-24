import 'package:flutter/material.dart';

const disclaimerText =
    'AI 输出仅用于设计灵感和空间规划讨论，不构成结构、消防、水电、施工、安全或法律意见。'
    '涉及拆改墙体、承重结构、燃气、电气、消防和正式施工时，必须由具备资质的专业人员现场核验并出具正式方案。';

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(disclaimerText, style: TextStyle(fontSize: 13, height: 1.4)),
      ),
    );
  }
}
