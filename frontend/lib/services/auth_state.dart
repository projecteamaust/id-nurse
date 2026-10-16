import 'package:flutter/foundation.dart';

import '../models/login_response.dart';
import '../models/user.dart';

/// Who is signed in. Kept in memory only (rule: the JWT is never saved to disk).
/// Screens listen to this with `provider` and redraw when it changes.
class AuthState extends ChangeNotifier {
  User? _user;
  String? _token;

  User? get user => _user;
  String? get token => _token;
  bool get isSignedIn => _user != null;

  void signIn(LoginResponse response) {
    _user = response.user;
    _token = response.accessToken;
    notifyListeners();
  }

  void signOut() {
    _user = null;
    _token = null;
    notifyListeners();
  }
}
