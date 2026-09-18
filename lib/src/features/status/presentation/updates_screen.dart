import 'package:a_chatz/src/features/status/presentation/channels_screen.dart';
import 'package:a_chatz/src/features/status/presentation/status_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Premium tab header
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Updates',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFF00FFB2).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.4), width: 1),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(14),
                    labelColor: const Color(0xFF00FFB2),
                    unselectedLabelColor: Colors.white54,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                    unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.circle_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('Status'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hub_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('Channels'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                StatusScreen(),
                ChannelsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
