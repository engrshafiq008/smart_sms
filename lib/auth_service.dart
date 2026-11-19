import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Email & Password Login for Windows Desktop
 Future<User?> signInWithEmail(String email, String password) async {
  try {
    UserCredential result = await _auth.signInWithEmailAndPassword(
      email: email, 
      password: password,
    );
    return result.user;
  } on FirebaseAuthException catch (e) {
    print("Firebase Auth Error Code: ${e.code}");
    print("Firebase Auth Error Message: ${e.message}");
    return null;
  } catch (e) {
    print("General Login Error: $e");
    return null;
  }
}

  // Email & Password Sign Up (Agar naya account banana ho)
  Future signUpWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Sign Up Error: $e");
      return null;
    }
  }

  Future signOut() async {
    await _auth.signOut();
  }
}