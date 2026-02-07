import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/services/supabase_service.dart';
import 'package:industrial_app/data/associations/association_repository.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/confirmation_dialog.dart';
import 'package:intl/intl.dart';

class AssociationDonationScreen extends StatefulWidget {
  final String associationId;

  const AssociationDonationScreen({super.key, required this.associationId});

  @override
  State<AssociationDonationScreen> createState() =>
      _AssociationDonationScreenState();
}

class _AssociationDonationScreenState extends State<AssociationDonationScreen> {
  final _moneyController = TextEditingController();
  final _gemsController = TextEditingController();
  List<Map<String, dynamic>> _contributions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // For now we get contributions from a hypothetical collection 'association_contributions'
      // Ordered by total amount (simplified for this task)
      final response = await SupabaseService.client
          .from('association_contributions')
          .select()
          .eq('association_id', widget.associationId)
          .order('money', ascending: false);

      if (mounted) {
        setState(() {
          _contributions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contributions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _donate(bool isMoney) async {
    final amountText = isMoney ? _moneyController.text : _gemsController.text;
    final double amount = double.tryParse(amountText) ?? 0;

    if (amount <= 0) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'CONFIRMAR DONACIÓN',
        message:
            '¿Estás seguro de que deseas donar ${NumberFormat('#,###').format(amount)} ${isMoney ? 'monedas' : 'gemas'} a la asociación?',
      ),
    );

    if (confirmed == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Perform donation logic (Subtract from user, add to association)
        // This should probably be a transaction in Supabase/Firestore
        await AssociationRepository.contributeToAssociation(
          associationId: widget.associationId,
          money: isMoney ? amount : 0,
          gems: isMoney ? 0 : amount,
        );

        _moneyController.clear();
        _gemsController.clear();
        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Donación enviada!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'DONACIONES',
          style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDonationInput(
                    'DINERO',
                    'assets/images/billete.png',
                    _moneyController,
                    () => _donate(true),
                  ),
                  const SizedBox(height: 24),
                  _buildDonationInput(
                    'GEMAS',
                    'assets/images/gemas.png',
                    _gemsController,
                    () => _donate(false),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'CONTRIBUIDORES TOP',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._contributions
                      .map((c) => _buildContributionRow(c))
                      .toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildDonationInput(
    String label,
    String iconPath,
    TextEditingController controller,
    VoidCallback onDonate,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(iconPath, width: 40, height: 40),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Cantidad...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          IndustrialButton(
            label: 'DONAR',
            height: 45,
            gradientTop: Colors.green[400]!,
            gradientBottom: Colors.green[700]!,
            borderColor: Colors.green[200]!,
            onPressed: onDonate,
          ),
        ],
      ),
    );
  }

  Widget _buildContributionRow(Map<String, dynamic> contrib) {
    // Ideally fetch user name from 'user_id' in contrib
    final String money = NumberFormat('#,###').format(contrib['money'] ?? 0);
    final String gems = NumberFormat('#,###').format(contrib['gems'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Contribución', // Should be user nickname
            style: GoogleFonts.inter(color: Colors.white70),
          ),
          Row(
            children: [
              if (contrib['money'] > 0) ...[
                Text(
                  money,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Image.asset('assets/images/billete.png', width: 20, height: 20),
              ],
              if (contrib['gems'] > 0) ...[
                const SizedBox(width: 12),
                Text(
                  gems,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Image.asset('assets/images/gemas.png', width: 20, height: 20),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
