import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/locations/country_model.dart';
import '../data/locations/country_repository.dart';
import '../data/locations/location_model.dart';
import '../data/locations/location_repository.dart';
import 'industrial_button.dart';

class HeadquarterSelectionDialog extends StatefulWidget {
  const HeadquarterSelectionDialog({super.key});

  @override
  State<HeadquarterSelectionDialog> createState() =>
      _HeadquarterSelectionDialogState();
}

class _HeadquarterSelectionDialogState
    extends State<HeadquarterSelectionDialog> {
  final CountryRepository _countryRepo = CountryRepository();
  List<CountryModel> _countries = [];
  List<LocationModel> _locations = [];

  CountryModel? _selectedCountry;
  LocationModel? _selectedLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final countries = await _countryRepo.loadCountries();
    countries.sort((a, b) => a.name.compareTo(b.name));
    if (mounted) {
      setState(() {
        _countries = countries;
        _isLoading = false;
      });
    }
  }

  Future<void> _onCountryChanged(CountryModel? country) async {
    if (country == null) return;

    setState(() {
      _selectedCountry = country;
      _selectedLocation = null;
      _isLoading = true;
    });

    final locations =
        await LocationsRepository.loadHeadquarterLocationsByCountry(
          country.code,
        );
    locations.sort((a, b) => a.city.compareTo(b.city));

    if (mounted) {
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    }
  }

  void _handleSaveHeadquarter() {
    _saveHeadquarter();
  }

  Future<void> _saveHeadquarter() async {
    if (_selectedLocation == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({
              'headquarter': _selectedLocation!.city,
              'headquarter_id': _selectedLocation!.id,
              'fecha_modificacion': FieldValue.serverTimestamp(),
            });
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving headquarter: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar la sede: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // If back button is pressed, exit both dialog and ParkingScreen
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pop(); // Exit ParkingScreen
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.asset(
                  'assets/images/sede.png',
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'CHOOSE YOUR HEADQUARTER',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading && _countries.isEmpty)
                      const CircularProgressIndicator()
                    else ...[
                      DropdownButtonFormField<CountryModel>(
                        value: _selectedCountry,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'País',
                          border: OutlineInputBorder(),
                        ),
                        items: _countries
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _onCountryChanged,
                      ),
                      if (_selectedCountry != null) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<LocationModel>(
                          value: _selectedLocation,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ubicación',
                            border: OutlineInputBorder(),
                          ),
                          items: _locations
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(
                                    l.city,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedLocation = val),
                        ),
                      ],
                      const SizedBox(height: 24),
                      IndustrialButton(
                        label: 'ACEPTAR',
                        width: double.infinity,
                        height: 55,
                        gradientTop: _selectedLocation != null
                            ? Colors.green[600]!
                            : Colors.green[400]!,
                        gradientBottom: _selectedLocation != null
                            ? Colors.green[800]!
                            : Colors.green[900]!,
                        borderColor: _selectedLocation != null
                            ? Colors.green[700]!
                            : Colors.green[700]!,
                        onPressed: _selectedLocation != null && !_isLoading
                            ? _handleSaveHeadquarter
                            : null,
                      ),
                    ],
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
