import 'package:a_chatz/src/core/supabase/supabase.dart';


bool isBusinessOpen(Map<String, dynamic>? businessHours, bool businessHoursEnabled) {
  if (!businessHoursEnabled || businessHours == null) return true;
  
  final now = DateTime.now();
  final daysOfWeek = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final currentDayStr = daysOfWeek[now.weekday - 1];
  
  final dayInfo = businessHours[currentDayStr];
  if (dayInfo == null) return true;
  
  final bool enabled = dayInfo['enabled'] ?? false;
  if (!enabled) return false;
  
  final startStr = dayInfo['start'] as String? ?? '00:00';
  final endStr = dayInfo['end'] as String? ?? '23:59';
  
  final startParts = startStr.split(':');
  final endParts = endStr.split(':');
  if (startParts.length < 2 || endParts.length < 2) return true;
  
  final startHour = int.tryParse(startParts[0]) ?? 0;
  final startMin = int.tryParse(startParts[1]) ?? 0;
  final endHour = int.tryParse(endParts[0]) ?? 23;
  final endMin = int.tryParse(endParts[1]) ?? 59;
  
  final currentHour = now.hour;
  final currentMin = now.minute;
  
  final currentTimeVal = currentHour * 60 + currentMin;
  final startTimeVal = startHour * 60 + startMin;
  final endTimeVal = endHour * 60 + endMin;
  
  return currentTimeVal >= startTimeVal && currentTimeVal <= endTimeVal;
}

String getBusinessHoursString(Map<String, dynamic>? businessHours, bool businessHoursEnabled) {
  if (!businessHoursEnabled || businessHours == null) return 'Open 24/7';
  
  final now = DateTime.now();
  final daysOfWeek = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final currentDayStr = daysOfWeek[now.weekday - 1];
  
  final dayInfo = businessHours[currentDayStr];
  if (dayInfo == null) return 'Open today';
  
  final bool enabled = dayInfo['enabled'] ?? false;
  if (!enabled) return 'Closed today';
  
  final start = dayInfo['start'] as String? ?? '09:00';
  final end = dayInfo['end'] as String? ?? '17:00';
  return 'Today: $start - $end';
}

String getCleanErrorMessage(dynamic e) {
  final message = e.toString();
  if (message.contains('email-already-in-use')) {
    return 'This email address is already registered.';
  }
  if (message.contains('invalid-email')) {
    return 'The email address is invalid.';
  }
  if (message.contains('user-disabled')) {
    return 'This account has been disabled.';
  }
  if (message.contains('user-not-found') || 
      message.contains('wrong-password') || 
      message.contains('invalid-credential')) {
    return 'Incorrect email or password.';
  }
  if (message.contains('weak-password')) {
    return 'The password is too weak.';
  }
  if (message.contains('network-request-failed') || message.contains('network_error')) {
    return 'Network error. Please check your internet connection.';
  }
  if (message.contains('permission-denied') || message.contains('PERMISSION_DENIED')) {
    return 'You do not have permission to perform this action.';
  }
  if (message.contains('unavailable') || message.contains('UNAVAILABLE')) {
    return 'The server is temporarily unavailable. Please try again.';
  }
  if (message.contains('SocketException') || message.contains('Connection failed')) {
    return 'Connection failed. Please check your internet connection.';
  }

  // Strip common exception prefixes to keep it clean and professional
  String cleanMsg = message;
  cleanMsg = cleanMsg.replaceAll(RegExp(r'\[.*?\]'), ''); // remove error codes etc.
  cleanMsg = cleanMsg.replaceAll('AppDatabaseException:', '');
  cleanMsg = cleanMsg.replaceAll('Exception:', '');
  cleanMsg = cleanMsg.trim();

  if (cleanMsg.isEmpty) {
    return 'An unexpected error occurred. Please try again.';
  }
  return cleanMsg;
}
