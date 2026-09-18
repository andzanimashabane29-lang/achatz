import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  TutorialService._();

  static const int tutorialVersion = 3;

  static String _key(String uid) => 'app_tutorial_v${tutorialVersion}_$uid';

  static Future<bool> shouldShow() async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_key(uid)) ?? false);
  }

  static Future<void> markCompleted() async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(uid), true);
  }

  static Future<void> resetForCurrentUser() async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }
}
