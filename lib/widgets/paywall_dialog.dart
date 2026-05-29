import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/design_system.dart';

class PaywallDialog extends StatelessWidget {
  final String featureName;

  const PaywallDialog({super.key, required this.featureName});

  static void show(BuildContext context, {required String feature}) {
    showDialog(
      context: context,
      builder: (_) => PaywallDialog(featureName: feature),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
      title: Row(
        children: [
          Icon(Icons.star, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Text("Pro Feature", style: AppTypography.textTheme.headlineMedium),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "The '$featureName' feature is available on the Mbeck Pro plan.",
            style: AppTypography.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBenefit("☁️ Cloud Backup & Sync"),
          _buildBenefit("📱 Multi-Device Access"),
          _buildBenefit("📊 Cloud Analytics"),
          _buildBenefit("⚡ Priority Support"),
          const SizedBox(height: AppSpacing.md),
          Text(
            "Upgrade today for just KSh 500/month.",
            style: AppTypography.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("MAYBE LATER"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: AppColors.surfaceWhite,
          ),
          onPressed: () async {
            Navigator.pop(context);
            final uri = Uri.parse("https://wa.me/254700000000?text=I%20want%20to%20upgrade%20to%20Mbeck%20Pro");
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
          child: const Text("UPGRADE NOW"),
        ),
      ],
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.check, color: AppColors.primaryGreen, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: AppTypography.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
