import 'package:flutter/material.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'industrial_button.dart';

class GenericPurchaseDialog extends StatefulWidget {
  final String title;
  final String description;
  final int price;
  final UnlockCostType priceType;
  final Future<void> Function() onConfirm;

  const GenericPurchaseDialog({
    super.key,
    required this.title,
    required this.description,
    required this.price,
    required this.priceType,
    required this.onConfirm,
  });

  @override
  State<GenericPurchaseDialog> createState() => _GenericPurchaseDialogState();
}

class _GenericPurchaseDialogState extends State<GenericPurchaseDialog> {
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);
    try {
      await widget.onConfirm();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // Error handling is expected to be done by the caller or we can show it here?
      // The implementation plan said: "If the callback throws, show error."
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
    final bool isFree = widget.priceType == UnlockCostType.free;

    final String currencyIcon =
        (isFree || widget.priceType == UnlockCostType.money)
        ? 'assets/images/billete.png'
        : 'assets/images/gemas.png';
    final String amount = isFree ? '0' : '${widget.price}';

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
        child: SingleChildScrollView(
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
                    Text(
                      widget.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                              onPressed: _handleConfirm,
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
      ),
    );
  }
}
