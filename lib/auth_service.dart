import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'school_data_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // --- Real Sign In with Google ---
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Enforce Local Persistence on Web across browser restarts
        await _auth.setPersistence(Persistence.LOCAL);
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        // Desktop / Native Fallback
        try {
          GoogleAuthProvider googleProvider = GoogleAuthProvider();
          UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
          return userCredential.user;
        } on FirebaseAuthException catch (e) {
          debugPrint("Desktop Google sign-in FirebaseAuthException: ${e.code} - ${e.message}");
          rethrow;
        } catch (e) {
          debugPrint("Desktop Google sign-in general exception: $e");
          rethrow;
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error Code: ${e.code}");
      debugPrint("Firebase Auth Error Message: ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("General Google Sign-In Error: $e");
      rethrow;
    }
  }

  // --- Email & Password Sign In ---
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
      }
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error Code: ${e.code}");
      debugPrint("Firebase Auth Error Message: ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("General Login Error: $e");
      rethrow;
    }
  }

  // --- Email & Password Sign Up ---
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
      }
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Sign Up Error: $e");
      rethrow;
    } catch (e) {
      debugPrint("General Sign Up Error: $e");
      rethrow;
    }
  }

  // --- Sign Out & Detach Multi-Tenant Database ---
  Future<void> signOut() async {
    await _auth.signOut();
    await SchoolDataService().detachUser();
  }

  // --- Check if School Profile Exists for UID (in Hive or Firestore) ---
  Future<Map<String, String>?> fetchSchoolProfile(String uid) async {
    // 1. Check local Hive box first
    try {
      if (!Hive.isBoxOpen('school_db_$uid')) {
        await Hive.openBox('school_db_$uid');
      }
      var box = Hive.box('school_db_$uid');
      var local = box.get('schoolSettings');
      if (local != null && local is Map) {
        String name = (local['schoolName'] ?? '').toString().trim();
        if (name.isNotEmpty && name != 'My School') {
          return Map<String, String>.from(local);
        }
      }
    } catch (e) {
      debugPrint("Local Hive check error: $e");
    }

    // 2. Check Cloud Firestore if not found locally (e.g. new browser/machine)
    try {
      var doc = await FirebaseFirestore.instance.collection('schools').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        var data = Map<String, String>.from(
          doc.data()!.map((k, v) => MapEntry(k, v.toString())),
        );
        // Cache to local box for instant offline access next time
        if (Hive.isBoxOpen('school_db_$uid')) {
          var box = Hive.box('school_db_$uid');
          await box.put('schoolSettings', data);
        }
        return data;
      }
    } catch (e) {
      debugPrint("Firestore fetchSchoolProfile notice: $e");
    }

    return null;
  }

  // --- Save New School Profile to Firestore and Hive ---
  Future<void> saveSchoolProfile(String uid, Map<String, String> profile) async {
    // 1. Save to Cloud Firestore
    try {
      await FirebaseFirestore.instance.collection('schools').doc(uid).set(profile, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore Sync Error in saveSchoolProfile: $e");
      rethrow;
    }

    // 2. Initialize SchoolDataService for this tenant
    await SchoolDataService().initForUser(uid, initialSettings: profile);
  }

  // --- Friendly Human-Readable Error Messages ---
  static String getReadableErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'popup-closed-by-user':
          return 'Sign-in cancelled by user.';
        case 'popup-blocked':
          return 'Sign-in popup was blocked by your browser. Please allow popups for this site.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-email':
          return 'Please provide a valid email address.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'operation-not-allowed':
          return 'Google sign-in is not enabled in Firebase Console. Please enable Google provider under Authentication.';
        case 'invalid-api-key':
        case 'api-key-not-valid':
          return 'Invalid Firebase API Key. Please verify firebase_options.dart.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        default:
          return error.message ?? 'Authentication error (${error.code}).';
      }
    }
    String str = error.toString().replaceAll('Exception:', '').trim();
    if (str.toLowerCase().contains('unsupported')) {
      return 'Google Sign-In on Windows Desktop requires Google OAuth Client ID setup. Please use Email/Password or run on Web.';
    }
    return str;
  }
}
