import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // role: 'driver' | 'owner'
  static Future<UserCredential> registerWithEmail({required String name, required String email, required String password, required String role}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return cred;
  }

  static Future<({UserCredential cred, String role})> signInWithEmailRoleChecked({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    final snap = await _db.collection('users').doc(uid).get();
    final role = (snap.data()?['role'] as String?) ?? '';
    return (cred: cred, role: role);
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // Android/iOS
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null; // user aborted
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final cred = await _auth.signInWithCredential(credential);
        // İlk girişte Firestore profilini oluştur
        final uid = cred.user!.uid;
        final doc = await _db.collection('users').doc(uid).get();
        if (!doc.exists) {
          await _db.collection('users').doc(uid).set({
            'name': cred.user!.displayName,
            'email': cred.user!.email,
            'role': null, // kullanıcı bir ekranda rol seçecek; ilk girişte atayacağız
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        return cred;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }

  static Future<void> ensureUserRole(String uid, String role) async {
    await _db.collection('users').doc(uid).set({'role': role}, SetOptions(merge: true));
  }

  static Future<String?> getUserRole(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data()?['role'] as String?);
  }
}
