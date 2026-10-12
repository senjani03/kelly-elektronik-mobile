import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

class AuthProvider extends ChangeNotifier {
  Map? user;
  bool get loggedIn => Api.token != null && user != null;
  bool get isAdmin => user?['role'] == 'admin';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    Api.token = p.getString('token');
    if (Api.token != null) {
      try {
        user = (await Api.req('GET', '/me'))['data'];
      } catch (_) {
        await _clear();
      }
    }
    notifyListeners();
  }

  Future<void> _auth(String path, Map body) async {
    final r = await Api.req('POST', path, body: body);
    Api.token = r['token'];
    user = r['user'];
    await (await SharedPreferences.getInstance())
        .setString('token', Api.token!);
    notifyListeners();
  }

  Future<void> login(String email, String password) =>
      _auth('/login', {'email': email, 'password': password});

  Future<void> register(
          String name, String email, String phone, String password) =>
      _auth('/register', {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
      });

  Future<void> _clear() async {
    Api.token = null;
    user = null;
    await (await SharedPreferences.getInstance()).remove('token');
  }

  Future<void> logout() async {
    try {
      await Api.req('POST', '/logout');
    } catch (_) {}
    await _clear();
    notifyListeners();
  }
}
