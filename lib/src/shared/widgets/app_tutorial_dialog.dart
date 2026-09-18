import 'package:flutter/material.dart';

class AppTutorialSlide {
  const AppTutorialSlide({
    required this.section,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.buttonHint,
  });

  final String section;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String? buttonHint;
}

/// Full first-time walkthrough covering main tabs and toolbar actions.
Future<void> showAppTutorialDialog(BuildContext context) {
  final slides = <AppTutorialSlide>[
    const AppTutorialSlide(
      section: 'Welcome',
      title: 'Welcome to A-Chatz',
      description:
          'This short guide explains every main button so you can chat, share status, call, and customize the app with confidence.',
      icon: Icons.waving_hand_outlined,
      accentColor: Color(0xFF00FFB2),
    ),
    const AppTutorialSlide(
      section: 'Navigation',
      title: 'Chats tab',
      description:
          'Your conversations live here. Unread chats show a green badge on this tab icon.',
      icon: Icons.chat_bubble_outline,
      accentColor: Color(0xFF0A84FF),
      buttonHint: 'Bottom bar → Chats',
    ),
    const AppTutorialSlide(
      section: 'Navigation',
      title: 'Status tab',
      description:
          'View friends\' updates and post your own photo, video, text, or voice status. A blue dot means someone posted since you last looked.',
      icon: Icons.circle_outlined,
      accentColor: Color(0xFF42A5F5),
      buttonHint: 'Bottom bar → Status',
    ),
    const AppTutorialSlide(
      section: 'Navigation',
      title: 'Channels tab',
      description:
          'Follow broadcast channels for announcements, news-style feeds, and community updates.',
      icon: Icons.hub_outlined,
      accentColor: Color(0xFFAB47BC),
      buttonHint: 'Bottom bar → Channels',
    ),
    const AppTutorialSlide(
      section: 'Navigation',
      title: 'Calls tab',
      description:
          'Start voice or video calls and review missed calls. Missed calls show a red badge.',
      icon: Icons.call_outlined,
      accentColor: Color(0xFFE53935),
      buttonHint: 'Bottom bar → Calls',
    ),
    const AppTutorialSlide(
      section: 'Navigation',
      title: 'AI Agent tab',
      description:
          'Open the built-in AI assistant for smart replies, summaries, and productivity help inside the app.',
      icon: Icons.smart_toy_outlined,
      accentColor: Color(0xFFFFB74D),
      buttonHint: 'Bottom bar → AI Agent',
    ),
    const AppTutorialSlide(
      section: 'Navigation',
      title: 'Profile tab',
      description:
          'Edit your photo, bio, linked accounts, privacy, storage, language, and app appearance.',
      icon: Icons.person_outline,
      accentColor: Color(0xFFCE93D8),
      buttonHint: 'Bottom bar → Profile',
    ),
    const AppTutorialSlide(
      section: 'Chats toolbar',
      title: 'Message yourself',
      description:
          'Bookmark icon — save notes, drafts, and reminders in a private chat only you can see.',
      icon: Icons.bookmark_border,
      accentColor: Color(0xFFFFD54F),
      buttonHint: 'Top right on Chats',
    ),
    const AppTutorialSlide(
      section: 'Chats toolbar',
      title: 'Create group',
      description:
          'Group icon — start a group chat, add members, and set a group name and photo.',
      icon: Icons.group_add_outlined,
      accentColor: Color(0xFF66BB6A),
      buttonHint: 'Top right on Chats',
    ),
    const AppTutorialSlide(
      section: 'Chats toolbar',
      title: 'Notifications',
      description:
          'Bell icon — alerts for mentions, requests, and system messages. The orange badge is unread count.',
      icon: Icons.notifications_none_rounded,
      accentColor: Color(0xFFFF6B35),
      buttonHint: 'Top right on Chats',
    ),
    const AppTutorialSlide(
      section: 'Chats toolbar',
      title: 'Search users',
      description:
          'Search icon — find people by username or email and start a new private chat.',
      icon: Icons.search,
      accentColor: Color(0xFF29B6F6),
      buttonHint: 'Top right on Chats',
    ),
    const AppTutorialSlide(
      section: 'Chats list',
      title: 'Search & filters',
      description:
          'Search bar filters chats by name or message. Chips below switch All, Unread, Favorites, and Groups.',
      icon: Icons.tune,
      accentColor: Color(0xFF8E8E93),
    ),
    const AppTutorialSlide(
      section: 'Chats list',
      title: 'Locked & archived',
      description:
          'Locked Chats need biometric unlock. Archived Chats hide old threads — long-press a chat to archive.',
      icon: Icons.lock_outline,
      accentColor: Color(0xFFB0BEC5),
    ),
    const AppTutorialSlide(
      section: 'Chat room',
      title: 'Inside a conversation',
      description:
          'Type messages, tap + for photos/files, hold mic for voice notes, and use the call buttons for voice/video.',
      icon: Icons.forum_outlined,
      accentColor: Color(0xFF00E676),
    ),
    const AppTutorialSlide(
      section: 'Status',
      title: 'Post a status',
      description:
          'On Status, tap My status or the green + badge to add text, gallery/camera photo, video, or voice status.',
      icon: Icons.add_circle_outline,
      accentColor: Color(0xFF00FFB2),
      buttonHint: 'Status → My status (+)',
    ),
    const AppTutorialSlide(
      section: 'Status',
      title: 'View statuses',
      description:
          'Tap a contact\'s ring to watch their updates. Long-press to mute someone\'s statuses.',
      icon: Icons.remove_red_eye_outlined,
      accentColor: Color(0xFF42A5F5),
    ),
    const AppTutorialSlide(
      section: 'Profile',
      title: 'QR & linked devices',
      description:
          'Show QR to link another device, Link Profile for multi-account, and Link Web Client for desktop pairing.',
      icon: Icons.qr_code,
      accentColor: Color(0xFFEF5350),
      buttonHint: 'Profile screen',
    ),
    const AppTutorialSlide(
      section: 'Settings',
      title: 'Themes & appearance',
      description:
          'Profile → Chat settings → App theme. Pick Midnight, OLED, Light, Forest Green, Ocean, Purple, Sunset, or Rose — plus Light/Dark/System mode.',
      icon: Icons.palette_outlined,
      accentColor: Color(0xFF7E57C2),
      buttonHint: 'Settings → Chats → App theme',
    ),
    const AppTutorialSlide(
      section: 'Safety',
      title: 'Emergency & privacy',
      description:
          'Shake for SOS (if enabled), app lock passcode in privacy settings, and blocked contacts under Profile settings.',
      icon: Icons.shield_outlined,
      accentColor: Color(0xFFFF5252),
    ),
    const AppTutorialSlide(
      section: 'Status Privacy',
      title: 'Choose who sees your updates',
      description:
          'Tap the privacy icon in the Status editor toolbar to select My Contacts, Share Only With, or Exclude Contacts.',
      icon: Icons.security_outlined,
      accentColor: Color(0xFF64FFDA),
    ),
    const AppTutorialSlide(
      section: 'Collage Layout',
      title: 'Multi-image Collage Grid',
      description:
          'When sending 2, 3, or 4+ images at once, A-Chatz automatically packages them into a clean, WhatsApp-style grid layout.',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFFFF4081),
    ),
    const AppTutorialSlide(
      section: 'Checkout Portals',
      title: 'Secure Payments Store',
      description:
          'Purchase premium themes or verification badges using the integrated Paystack and Flutterwave card checkout gateways.',
      icon: Icons.credit_card_rounded,
      accentColor: Color(0xFF00E676),
    ),
    const AppTutorialSlide(
      section: 'Privacy settings',
      title: 'Read Receipts & Visibility',
      description:
          'Disable Read Receipts under Privacy Settings to prevent blue ticks. Disabling receipts also disables status viewer lists.',
      icon: Icons.visibility_off_outlined,
      accentColor: Color(0xFFE040FB),
    ),
    const AppTutorialSlide(
      section: 'Done',
      title: 'You\'re all set!',
      description:
          'Replay this guide anytime from Profile → Help → App tutorial. Enjoy A-Chatz!',
      icon: Icons.check_circle_outline,
      accentColor: Color(0xFF00FFB2),
    ),
  ];

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AppTutorialDialog(slides: slides),
  );
}

class _AppTutorialDialog extends StatefulWidget {
  const _AppTutorialDialog({required this.slides});

  final List<AppTutorialSlide> slides;

  @override
  State<_AppTutorialDialog> createState() => _AppTutorialDialogState();
}

class _AppTutorialDialogState extends State<_AppTutorialDialog> {
  final _pageController = PageController();
  int _activePage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slides[_activePage];
    final isLast = _activePage == widget.slides.length - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: const Color(0xFF121214),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App tutorial • ${slide.section}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_activePage + 1} of ${widget.slides.length}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.slides.length,
                onPageChanged: (i) => setState(() => _activePage = i),
                itemBuilder: (_, i) {
                  final s = widget.slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: s.accentColor.withOpacity(0.15),
                          child: Icon(s.icon, color: s.accentColor, size: 44),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.white70,
                          ),
                        ),
                        if (s.buttonHint != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: s.accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: s.accentColor.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 16,
                                  color: s.accentColor,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    s.buttonHint!,
                                    style: TextStyle(
                                      color: s.accentColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(
                        widget.slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 4),
                          height: 6,
                          width: _activePage == i ? 18 : 6,
                          decoration: BoxDecoration(
                            color: _activePage == i
                                ? Colors.white
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (isLast) {
                        Navigator.pop(context);
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Text(isLast ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
