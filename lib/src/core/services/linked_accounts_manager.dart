import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
class LinkedAccount {
  final String uid;
  final String email;
  final String password;
  final String username;
  final String? photoUrl;

  const LinkedAccount({
    required this.uid,
    required this.email,
    required this.password,
    required this.username,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'password': password,
      'username': username,
      'photoUrl': photoUrl,
    };
  }

  factory LinkedAccount.fromMap(Map<String, dynamic> map) {
    return LinkedAccount(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      username: map['username'] ?? '',
      photoUrl: map['photoUrl'],
    );
  }
}

class LinkedAccountsManager {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'a_chatz_linked_accounts';

  static Future<List<LinkedAccount>> getLinkedAccounts() async {
    try {
      final jsonStr = await _storage.read(key: _storageKey);
      if (jsonStr == null) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => LinkedAccount.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> addAccount({
    required String email,
    required String password,
    required String uid,
    required String username,
    String? photoUrl,
  }) async {
    final list = await getLinkedAccounts();
    
    // Check if already linked
    final existsIndex = list.indexWhere((e) => e.uid == uid || e.email == email);
    
    final newAccount = LinkedAccount(
      uid: uid,
      email: email,
      password: password,
      username: username,
      photoUrl: photoUrl,
    );

    if (existsIndex != -1) {
      list[existsIndex] = newAccount;
    } else {
      if (list.length >= 6) {
        return false; // Limit to 6 accounts reached
      }
      list.add(newAccount);
    }

    final jsonStr = jsonEncode(list.map((e) => e.toMap()).toList());
    await _storage.write(key: _storageKey, value: jsonStr);
    return true;
  }

  static Future<void> removeAccount(String uid) async {
    final list = await getLinkedAccounts();
    list.removeWhere((e) => e.uid == uid);
    final jsonStr = jsonEncode(list.map((e) => e.toMap()).toList());
    await _storage.write(key: _storageKey, value: jsonStr);
  }

  static Future<void> clearAllAccountsExceptOfficial() async {
    try {
      final list = await getLinkedAccounts();
      list.removeWhere((e) => e.email.trim().toLowerCase() != 'official@a-chatz.com');
      final jsonStr = jsonEncode(list.map((e) => e.toMap()).toList());
      await _storage.write(key: _storageKey, value: jsonStr);
    } catch (_) {}
  }

  static Future<bool> switchAccount(BuildContext context, LinkedAccount account) async {
    try {
      // Sign in to target session directly. 
      // If it fails, the previous user remains signed in.
      await AppAuth.instance.signInWithEmailAndPassword(
        email: account.email,
        password: account.password,
      );
      
      return true;
    } catch (_) {
      return false;
    }
  }
}
