import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sweptie/models/user_model.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchUserModel(user.uid);
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    final model = UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      plan: 'free',
    );
    await _db.collection('users').doc(uid).set(model.toMap());
    await cred.user!.updateDisplayName(displayName);
    return model;
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _fetchUserModel(cred.user!.uid);
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserModel> _fetchUserModel(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      final fallback = UserModel(
        uid: uid,
        email: _auth.currentUser?.email ?? '',
        displayName: _auth.currentUser?.displayName ?? '',
        plan: 'free',
      );
      await _db.collection('users').doc(uid).set(fallback.toMap());
      return fallback;
    }
    return UserModel.fromMap(uid, doc.data()!);
  }

  Stream<UserModel?> userModelStream() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _fetchUserModel(user.uid);
    });
  }
}
