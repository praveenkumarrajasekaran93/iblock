import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_number/mobile_number.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIM Auth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SimSelectionScreen(),
    );
  }
}

class SimSelectionScreen extends StatefulWidget {
  const SimSelectionScreen({super.key});

  @override
  _SimSelectionScreenState createState() => _SimSelectionScreenState();
}

class _SimSelectionScreenState extends State<SimSelectionScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _startSimAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    PermissionStatus status = await Permission.phone.status;
    if (status.isDenied || status.isRestricted) {
      status = await Permission.phone.request();
    }

    if (status.isGranted) {
      await _getSimInfo();
    } else if (status.isPermanentlyDenied) {
      _showError('Phone permission is permanently denied. Please enable it in app settings.');
      await openAppSettings();
    } else {
      _showError('Phone permission is required to read SIM information.');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getSimInfo() async {
    try {
      List<SimCard> sims = await MobileNumber.getSimCards ?? [];
      if (!mounted) return;
      if (sims.isEmpty) {
        _showError('No SIM cards detected. This can happen on an emulator or a device without a SIM card.');
      } else {
        _showSimSelectionSheet(sims);
      }
    } on PlatformException catch (e) {
      _showError('Failed to get SIM data: ${e.message}. Ensure the app has phone permissions and a SIM is present.');
    } catch (e) {
      _showError('An unexpected error occurred while reading SIM data: $e');
    }
  }

  void _showSimSelectionSheet(List<SimCard> sims) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: sims.asMap().entries.map((entry) {
              int idx = entry.key;
              SimCard sim = entry.value;
              String simDisplayName = 'SIM ${idx + 1} (${sim.carrierName ?? 'Unknown'}) - ${sim.number ?? 'No number'}';
              return ListTile(
                leading: const Icon(Icons.sim_card),
                title: Text(simDisplayName),
                onTap: () {
                  Navigator.of(context).pop();
                  _selectSim(sim);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _selectSim(SimCard sim) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (sim.number != null && sim.number!.isNotEmpty) {
        await _verifyPhoneNumber(sim.number!);
      } else {
        _showError('Could not retrieve phone number from the selected SIM.');
      }
    } catch (e) {
      _showError('Failed to process SIM selection: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    const String apiUrl = 'https://yourapi.endpoint/verify'; // Replace with your API endpoint

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['verified'] == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const VerifiedScreen(),
            ),
          );
        } else {
          _showError('Phone number not authorized, try with correct SIM slot');
        }
      } else {
        _showError('API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      _showError('API request failed: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select SIM for Authentication'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _startSimAuth,
                    child: const Text('Select SIM for Authentication'),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class VerifiedScreen extends StatelessWidget {
  const VerifiedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication Successful'),
      ),
      body: const Center(
        child: Text('Welcome! Your phone number has been verified.'),
      ),
    );
  }
}
