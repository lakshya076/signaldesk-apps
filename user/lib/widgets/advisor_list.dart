import 'package:flutter/material.dart';
import 'package:signaldesk_user/models/advisor_profile.dart';
import 'package:signaldesk_user/widgets/advisor_card.dart';

class AdvisorList extends StatelessWidget {
  final List<AdvisorProfile> advisors;
  final bool isSubscribedList;
  final Function(String) onSubscriptionChange;

  const AdvisorList({super.key,
    required this.advisors,
    required this.isSubscribedList,
    required this.onSubscriptionChange,
  });

  @override
  Widget build(BuildContext context) {
    if (advisors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            isSubscribedList
                ? 'You are not subscribed to any advisors yet.\nGo to the Discover tab to find new advisors.'
                : 'No new advisors to discover.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: advisors.length,
      itemBuilder: (context, index) {
        final advisor = advisors[index];

        // Return the AdvisorCardWidget with real data
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: AdvisorCardWidget(
            advisorName: advisor.fullName,
            isSubscribed: isSubscribedList,
            onSubscriptionChange: () => onSubscriptionChange(advisor.id),
            // Pass the new, real data to the card
            followerCount: advisor.followerCount,
            hitRate: advisor.hitRate,
            licenseType: advisor.licenseType,
            specialties: advisor.specialties,
            experience: advisor.experience,
          ),
        );
      },
    );
  }
}
