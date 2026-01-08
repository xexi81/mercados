import 'package:flutter/material.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/fleet/fleet_model.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/data/fleet/fleet_service.dart';
import 'industrial_button.dart';

class FleetPurchaseDialog extends StatefulWidget {
  final FleetModel fleet;

  const FleetPurchaseDialog({super.key, required this.fleet});

  @override
  State<FleetPurchaseDialog> createState() => _FleetPurchaseDialogState();
}

class _FleetPurchaseDialogState extends State<FleetPurchaseDialog> {
  bool _isLoading = false;

  Future<void> _onAccept() async {
    setState(() => _isLoading = true);
    try {
      await FleetService.purchaseFleet(widget.fleet);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Flota desbloqueada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cost = widget.fleet.unlockCost;
    final bool isFree = cost.type == UnlockCostType.free;

    final String currencyIcon = (isFree || cost.type == UnlockCostType.money)
        ? 'assets/images/billete.png'
        : 'assets/images/gemas.png';
    final String amount = isFree ? '0' : '${cost.amount}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with background style
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'COMPRA DE FLOTA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    '¿Estás seguro de que deseas desbloquear este slot para tu flota?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Cost display
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          amount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Image.asset(
                          currencyIcon,
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Buttons
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.green)
                  else
                    Row(
                      children: [
                        Expanded(
                          child: IndustrialButton(
                            label: 'CANCELAR',
                            height: 50,
                            gradientTop: Colors.grey[600]!,
                            gradientBottom: Colors.grey[800]!,
                            borderColor: Colors.grey[400]!,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: IndustrialButton(
                            label: 'ACEPTAR',
                            height: 50,
                            gradientTop: Colors.green[400]!,
                            gradientBottom: Colors.green[700]!,
                            borderColor: Colors.green[200]!,
                            onPressed: _onAccept,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
