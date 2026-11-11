import 'package:flutter/material.dart';

class AdvisorCardWidget extends StatelessWidget {
  final String advisorName;
  final bool isSubscribed;
  final VoidCallback onSubscriptionChange;

  // These are no longer placeholders
  final String licenseType;
  final String specialties;
  final int experience;
  final int followerCount;
  final double hitRate;

  const AdvisorCardWidget({
    Key? key,
    required this.advisorName,
    required this.isSubscribed,
    required this.onSubscriptionChange,
    // Add the new required fields
    required this.licenseType,
    required this.specialties,
    required this.experience,
    required this.followerCount,
    required this.hitRate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profitColor = theme.colorScheme.secondary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: .1,
                  ),
                  child: Text(
                    advisorName.isNotEmpty ? advisorName[0].toUpperCase() : 'A',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$advisorName ($licenseType)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.verified, color: profitColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'SEBI Registered',
                            style: TextStyle(
                              color: profitColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   specialties,
                      //   style: theme.textTheme.bodySmall?.copyWith(
                      //     color: theme.hintColor,
                      //   ),
                      //   maxLines: 1,
                      //   overflow: TextOverflow.ellipsis,
                      // ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onSubscriptionChange,
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isSubscribed ? Colors.grey : theme.colorScheme.primary,
                    side: BorderSide(
                      color:
                          isSubscribed
                              ? Colors.grey
                              : theme.colorScheme.primary,
                    ),
                  ),
                  child: Text(isSubscribed ? 'Unsubscribe' : 'Subscribe'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // _buildStatRow(
                    //   context,
                    //   Icons.work_outline,
                    //   '$experience Yrs. experience',
                    // ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                      context,
                      Icons.people_outline,
                      '$followerCount Followers',
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: hitRate / 100,
                        strokeWidth: 6,
                        backgroundColor: profitColor.withValues(alpha: .2),
                        valueColor: AlwaysStoppedAnimation<Color>(profitColor),
                      ),
                      Center(
                        child: Text(
                          '${hitRate.toStringAsFixed(1)}%',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).hintColor),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
