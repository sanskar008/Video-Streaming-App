import 'package:flutter/material.dart';
import 'host_screen.dart';
import 'viewer_screen.dart';
import '../services/database_service.dart';
import '../models/user.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  void _login() async {
    final user = await _dbService.authenticate(
      _usernameController.text,
      _passwordController.text,
    );
    if (user != null) {
      _showRoleDialog();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid credentials')));
    }
  }

  void _register() async {
    await _dbService.register(User(
      username: _usernameController.text,
      password: _passwordController.text,
    ));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Registered successfully')));
  }

  void _showRoleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Role'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => HostScreen()));
            },
            child: const Text('Host'),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ViewerScreen()));
            },
            child: const Text('Viewer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Streaming App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username')),
            TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text('Login')),
            ElevatedButton(onPressed: _register, child: const Text('Register')),
          ],
        ),
      ),
    );
  }
}
