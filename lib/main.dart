import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_number/mobile_number.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

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
  List<SimCard> _simCards = [];

  @override
  void initState() {
    super.initState();
    _getSimInfo();
  }

  Future<void> _getSimInfo() async {
    if (await Permission.phone.request().isGranted) {
      try {
        List<SimCard> sims = await MobileNumber.getSimCards ?? [];
        setState(() {
          _simCards = sims;
        });
      } catch (e) {
        _showError('Failed to get SIM data: $e');
      }
    } else {
      _showError('Phone permission is required to read SIM information.');
    }
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
      setState(() {
        _isLoading = false;
      });
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
                  if (_simCards.isEmpty)
                    const Text('No SIM cards detected or permission denied.')
                  else
                    ..._simCards.asMap().entries.map((entry) {
                      int idx = entry.key;
                      SimCard sim = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton(
                          onPressed: () => _selectSim(sim),
                          child: Text('Use SIM ${idx + 1} (${sim.carrierName ?? 'Unknown'})'),
                        ),
                      );
                    }).toList(),
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
