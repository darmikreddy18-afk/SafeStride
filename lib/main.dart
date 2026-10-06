import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'firebase_options.dart';
import 'screens/guardian_dashboard.dart';

import 'screens/patient_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SafeStrideApp());
}

class SafeStrideApp extends StatelessWidget {
  const SafeStrideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeStride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserData(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          future: _getUserData(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (userSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to load your account.\n\n'
                      '${userSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final data = userSnapshot.data?.data();

            if (data == null) {
              return const RoleSelectionScreen();
            }

            final role = data['role'] as String?;

            // --------------------------------------------------
            // PATIENT
            // --------------------------------------------------

            if (role == 'patient') {
              final deviceId =
                  data['deviceId'] as String?;

              if (deviceId != null &&
                  deviceId.isNotEmpty) {
                return AutoReconnectScreen(
                  expectedDeviceId: deviceId,
                );
              }

              return const DeviceSelectionScreen();
            }

            // --------------------------------------------------
            // GUARDIAN
            //
            // IMPORTANT:
            // Guardians now open directly into the
            // GuardianDashboard.
            // --------------------------------------------------

            if (role == 'guardian') {
              return const GuardianDashboard();
            }

            return const RoleSelectionScreen();
          },
        );
      },
    );
  }
}

// ============================================================
// LOGIN
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email =
        _emailController.text.trim();
    final password =
        _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error =
            'Please enter your email and password.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            e.message ?? 'Login failed.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Something went wrong. Please try again.';
      });
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.health_and_safety,
                  size: 80,
                ),
                const SizedBox(height: 20),
                const Text(
                  'SafeStride',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Smart mobility. Safer independence.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(
                    labelText: 'Email',
                    prefixIcon:
                        Icon(Icons.email),
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(
                    labelText: 'Password',
                    prefixIcon:
                        Icon(Icons.lock),
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child:
                                CircularProgressIndicator(),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const SignupScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Create a SafeStride account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SIGN UP
// ============================================================

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() =>
      _SignupScreenState();
}

class _SignupScreenState
    extends State<SignupScreen> {
  final _nameController =
      TextEditingController();
  final _mobileController =
      TextEditingController();
  final _emailController =
      TextEditingController();
  final _passwordController =
      TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name =
        _nameController.text.trim();
    final mobile =
        _mobileController.text.trim();
    final email =
        _emailController.text.trim();
    final password =
        _passwordController.text.trim();

    if (name.isEmpty ||
        mobile.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      setState(() {
        _error =
            'Please fill in all fields.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _error =
            'Password must contain at least 6 characters.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception(
          'Account creation failed.',
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'name': name,
        'mobile': mobile,
        'email': email,
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const RoleSelectionScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            e.message ??
            'Unable to create account.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Something went wrong. Please try again.';
      });
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller:
                    _nameController,
                decoration:
                    const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon:
                      Icon(Icons.person),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller:
                    _mobileController,
                keyboardType:
                    TextInputType.phone,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Mobile Number',
                  prefixIcon:
                      Icon(Icons.phone),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller:
                    _emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration:
                    const InputDecoration(
                  labelText: 'Email',
                  prefixIcon:
                      Icon(Icons.email),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller:
                    _passwordController,
                obscureText: true,
                decoration:
                    const InputDecoration(
                  labelText: 'Password',
                  prefixIcon:
                      Icon(Icons.lock),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _loading ? null : _signup,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child:
                              CircularProgressIndicator(),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ROLE SELECTION
// ============================================================

class RoleSelectionScreen
    extends StatefulWidget {
  const RoleSelectionScreen({
    super.key,
  });

  @override
  State<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState
    extends State<RoleSelectionScreen> {
  bool _loading = false;

  String _generateFamilyId() {
    final timestamp =
        DateTime.now()
            .millisecondsSinceEpoch;

    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    var value = timestamp;
    var result = '';

    for (var i = 0; i < 6; i++) {
      result +=
          characters[value %
              characters.length];
      value = value ~/ characters.length;
    }

    return 'SS-${result.toUpperCase()}';
  }

  Future<void> _selectPatient() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      _loading = true;
    });

    final familyId =
        _generateFamilyId();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'role': 'patient',
      'familyId': familyId,
      'familyIdCreatedAt':
          FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FamilyIdScreen(
          familyId: familyId,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _selectGuardian() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      _loading = true;
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'role': 'guardian',
    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const GuardianDashboard(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:
            const Text('Choose Your Role'),
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              const Text(
                'How will you use SafeStride?',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose the option that best describes you.',
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Card(
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          onTap: _loading
                              ? null
                              : _selectPatient,
                          child:
                              const Padding(
                            padding:
                                EdgeInsets.all(
                              24,
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                Icon(
                                  Icons
                                      .directions_walk,
                                  size: 70,
                                ),
                                SizedBox(
                                  height: 16,
                                ),
                                Text(
                                  'Patient / Walker User',
                                  textAlign:
                                      TextAlign
                                          .center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  'I will use SafeStride with a smart walker.',
                                  textAlign:
                                      TextAlign
                                          .center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Expanded(
                      child: Card(
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          onTap: _loading
                              ? null
                              : _selectGuardian,
                          child:
                              const Padding(
                            padding:
                                EdgeInsets.all(
                              24,
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                Icon(
                                  Icons
                                      .family_restroom,
                                  size: 70,
                                ),
                                SizedBox(
                                  height: 16,
                                ),
                                Text(
                                  'Guardian / Caregiver',
                                  textAlign:
                                      TextAlign
                                          .center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  'I want to monitor and support a SafeStride user.',
                                  textAlign:
                                      TextAlign
                                          .center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FAMILY ID
// ============================================================

class FamilyIdScreen
    extends StatelessWidget {
  final String familyId;

  const FamilyIdScreen({
    super.key,
    required this.familyId,
  });

  Future<void> _continue(
    BuildContext context,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'role': 'patient',
      'familyId': familyId,
    }, SetOptions(merge: true));

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const DeviceSelectionScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:
            const Text('Your Family ID'),
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              const Icon(
                Icons.family_restroom,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Your SafeStride Family ID',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share this ID with your trusted caregiver or family member so they can request access.',
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(height: 35),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    24,
                  ),
                  child: Text(
                    familyId,
                    textAlign:
                        TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight:
                          FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Keep your Family ID private and share it only with people you trust.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      _continue(context),
                  child: const Text(
                    'Continue to Walker Setup',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DEVICE SELECTION
// ============================================================

class DeviceSelectionScreen
    extends StatelessWidget {
  const DeviceSelectionScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:
            const Text('Walker Setup'),
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              const Icon(
                Icons.bluetooth_searching,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Connect Your SafeStride Walker',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Turn on your SafeStride Walker and make sure it is nearby.',
                textAlign:
                    TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AutoReconnectScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.bluetooth,
                  ),
                  label: const Text(
                    'Find SafeStride Walker',
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AUTO RECONNECT / BLUETOOTH
// ============================================================

class AutoReconnectScreen
    extends StatefulWidget {
  final String? expectedDeviceId;

  const AutoReconnectScreen({
    super.key,
    this.expectedDeviceId,
  });

  @override
  State<AutoReconnectScreen> createState() =>
      _AutoReconnectScreenState();
}

class _AutoReconnectScreenState
    extends State<AutoReconnectScreen> {
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _scanAndConnect();
    });
  }

  Future<void> _scanAndConnect() async {
    if (_scanning) return;

    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      await FlutterBluePlus.stopScan();

      await FlutterBluePlus.startScan(
        timeout:
            const Duration(seconds: 8),
      );

      BluetoothDevice? foundDevice;

      await for (
        final results
            in FlutterBluePlus.scanResults
      ) {
        for (final result in results) {
          final device = result.device;
          final name =
              device.platformName.trim();

          if (name ==
              'SafeStride_ESP32') {
            foundDevice = device;
            break;
          }
        }

        if (foundDevice != null) {
          break;
        }
      }

      await FlutterBluePlus.stopScan();

      if (!mounted) return;

      if (foundDevice == null) {
        setState(() {
          _error =
              'SafeStride Walker not found. '
              'Make sure the walker is powered on and nearby.';
          _scanning = false;
        });
        return;
      }

      final device = foundDevice;

      await device.connect(
        license: License.nonprofit,
        timeout:
            const Duration(seconds: 10),
      );

      if (!mounted) return;

      final user =
          FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'deviceId':
              device.remoteId.str,
          'deviceName':
              'SafeStride Walker',
          'deviceBluetoothName':
              device.platformName.isNotEmpty
                  ? device.platformName
                  : 'SafeStride_ESP32',
          'deviceType':
              'smart_walker',
          'deviceRegisteredAt':
              FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PatientDashboard(
            device: device,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Unable to connect to the SafeStride Walker.';
        _scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:
            const Text('Connecting'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  _scanning
                      ? Icons
                          .bluetooth_searching
                      : Icons
                          .bluetooth_disabled,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  _scanning
                      ? 'Searching for SafeStride Walker...'
                      : 'Walker Connection',
                  textAlign:
                      TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_scanning)
                  const CircularProgressIndicator(),
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _error!,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed:
                        _scanAndConnect,
                    child: const Text(
                      'Try Again',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GUARDIAN HOME
//
// Kept for compatibility with any existing references.
// AuthGate no longer sends guardians here.
// ============================================================

class GuardianHomeScreen
    extends StatelessWidget {
  const GuardianHomeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const GuardianDashboard();
  }
}