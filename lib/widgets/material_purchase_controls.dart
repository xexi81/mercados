import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/widgets/error_dialog.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';

class MaterialPurchaseControls extends StatefulWidget {
  final Map<String, dynamic> selectedMaterial;
  final double userMoney;
  final TextEditingController quantityController;
  final VoidCallback onCancel;
  final Future<void> Function(int) onPurchase;
  final Future<void> Function(int) onPurchaseMax;
  final int Function(Map<String, dynamic>) calculateMaxQuantity;
  final int Function(Map<String, dynamic>) calculateMaxAffordableQuantity;
  final double Function(Map<String, dynamic>, int) calculateTotalPrice;

  const MaterialPurchaseControls({
    super.key,
    required this.selectedMaterial,
    required this.userMoney,
    required this.quantityController,
    required this.onCancel,
    required this.onPurchase,
    required this.onPurchaseMax,
    required this.calculateMaxQuantity,
    required this.calculateMaxAffordableQuantity,
    required this.calculateTotalPrice,
  });

  @override
  State<MaterialPurchaseControls> createState() =>
      _MaterialPurchaseControlsState();
}

class _MaterialPurchaseControlsState extends State<MaterialPurchaseControls> {
  int purchaseQuantity = 1;
  double totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    widget.quantityController.text = '1';
    totalPrice = widget.calculateTotalPrice(widget.selectedMaterial, 1);
    widget.quantityController.addListener(_onQuantityChanged);
  }

  @override
  void dispose() {
    widget.quantityController.removeListener(_onQuantityChanged);
    super.dispose();
  }

  void _onQuantityChanged() {
    final qty = int.tryParse(widget.quantityController.text);
    int displayQty = (qty == null || qty < 1) ? 1 : qty;
    setState(() {
      purchaseQuantity = displayQty;
      totalPrice = widget.calculateTotalPrice(
        widget.selectedMaterial,
        purchaseQuantity,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(0, 0, 0, 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Cantidad:', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  controller: widget.quantityController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Total: ' +
                      ((widget.userMoney % 1 == 0)
                          ? totalPrice.toInt().toString()
                          : totalPrice.toStringAsFixed(2)),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: IndustrialButton(
                      label: 'Cancelar',
                      onPressed: widget.onCancel,
                      gradientTop: const Color(0xFF757575),
                      gradientBottom: const Color(0xFF424242),
                      borderColor: const Color(0xFF212121),
                      height: 50,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: IndustrialButton(
                      label: 'Comprar',
                      onPressed: () async {
                        final maxQty = widget.calculateMaxQuantity(
                          widget.selectedMaterial,
                        );
                        final maxAffordable = widget
                            .calculateMaxAffordableQuantity(
                              widget.selectedMaterial,
                            );
                        int maxAllowed = maxQty < maxAffordable
                            ? maxQty
                            : maxAffordable;
                        print(
                          'DEBUG: maxQty = $maxQty, maxAffordable = $maxAffordable, maxAllowed = $maxAllowed',
                        );
                        int qty =
                            int.tryParse(widget.quantityController.text) ?? 1;
                        print(
                          'DEBUG: Controller text = "${widget.quantityController.text}"',
                        );
                        print('DEBUG: Parsed qty = $qty');
                        if (qty == 0) qty = 1;
                        if (qty < 0) qty = 1;

                        // Verificar si la cantidad excede el máximo permitido
                        if (qty > maxAllowed) {
                          print(
                            'DEBUG: qty ($qty) > maxAllowed ($maxAllowed), showing error',
                          );
                          String errorMessage;
                          if (maxAllowed == 0) {
                            if (maxAffordable == 0) {
                              errorMessage =
                                  'No tienes suficiente dinero para comprar este material.';
                            } else if (maxQty == 0) {
                              errorMessage =
                                  'No hay espacio suficiente en el contenedor.';
                            } else {
                              errorMessage =
                                  'No puedes comprar este material en este momento.';
                            }
                          } else {
                            if (maxAffordable < maxQty) {
                              errorMessage =
                                  'Solo puedes comprar hasta $maxAllowed unidades con tu dinero disponible.';
                            } else {
                              errorMessage =
                                  'Solo puedes comprar hasta $maxAllowed unidades por capacidad del contenedor.';
                            }
                          }

                          await showDialog(
                            context: context,
                            builder: (context) => ErrorDialog(
                              title: 'Error de Compra',
                              description: errorMessage,
                            ),
                          );
                          return;
                        }

                        print('DEBUG: Final qty = $qty');
                        final double dialogTotal = widget.calculateTotalPrice(
                          widget.selectedMaterial,
                          qty,
                        );
                        print('DEBUG: Dialog total = $dialogTotal');
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => GenericPurchaseDialog(
                            title: 'COMPRAR MATERIAL',
                            description:
                                '¿Confirmar compra de $qty unidades de ${widget.selectedMaterial['name']}?',
                            price: dialogTotal.toInt(),
                            priceType: UnlockCostType.money,
                            onConfirm: () async => true,
                          ),
                        );
                        if (confirmed == true) {
                          await widget.onPurchase(qty);
                        }
                      },
                      gradientTop: const Color(0xFF4CAF50),
                      gradientBottom: const Color(0xFF2E7D32),
                      borderColor: const Color(0xFF1B5E20),
                      height: 50,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: IndustrialButton(
                      label: 'Comprar Máximo',
                      onPressed: () async {
                        final maxQty = widget.calculateMaxQuantity(
                          widget.selectedMaterial,
                        );
                        final maxAffordable = widget
                            .calculateMaxAffordableQuantity(
                              widget.selectedMaterial,
                            );
                        int maxAllowed = maxQty < maxAffordable
                            ? maxQty
                            : maxAffordable;
                        if (maxAllowed <= 0) {
                          await showDialog(
                            context: context,
                            builder: (context) => ErrorDialog(
                              title: 'Error de Compra',
                              description:
                                  'No puedes comprar más unidades de este material.',
                            ),
                          );
                          return;
                        }
                        final double dialogTotal = widget.calculateTotalPrice(
                          widget.selectedMaterial,
                          maxAllowed,
                        );
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => GenericPurchaseDialog(
                            title: 'COMPRAR MÁXIMO',
                            description:
                                '¿Comprar $maxAllowed unidades de ${widget.selectedMaterial['name']}? (Llenar contenedor o agotar dinero)',
                            price: dialogTotal.toInt(),
                            priceType: UnlockCostType.money,
                            onConfirm: () async => true,
                          ),
                        );
                        if (confirmed == true) {
                          await widget.onPurchaseMax(maxAllowed);
                        }
                      },
                      gradientTop: const Color(0xFFFF9800),
                      gradientBottom: const Color(0xFFF57C00),
                      borderColor: const Color(0xFFE65100),
                      height: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
