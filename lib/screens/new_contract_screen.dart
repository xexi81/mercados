import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/materials/material_model.dart';
import '../data/materials/materials_repository.dart';
import '../data/contracts/contract_model.dart';
import '../services/contracts_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_game_appbar.dart';
import '../widgets/industrial_button.dart';

class NewContractScreen extends StatefulWidget {
  const NewContractScreen({super.key});

  @override
  State<NewContractScreen> createState() => _NewContractScreenState();
}

class _NewContractScreenState extends State<NewContractScreen> {
  List<MaterialModel> _allMaterials = [];
  String? _selectedCategory;
  MaterialModel? _selectedMaterial;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final materials = await MaterialsRepository.loadMaterials();
    setState(() {
      _allMaterials = materials;
      _isLoading = false;
    });
  }

  List<String> get _categories =>
      _allMaterials.map((m) => m.category).toSet().toList();

  List<MaterialModel> get _filteredMaterials =>
      _allMaterials.where((m) => m.category == _selectedCategory).toList();

  Future<void> _createContract() async {
    if (_selectedMaterial == null ||
        _quantityController.text.isEmpty ||
        _deadlineController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final contract = ContractModel(
        id: '', // Supabase uses uuid_generate_v4()
        creatorId: user.uid,
        materialId: _selectedMaterial!.id,
        quantity: int.parse(_quantityController.text),
        deadlineDays: int.parse(_deadlineController.text),
        locationId: 'Sede Principal', // Placeholder or get from user profile
        createdAt: DateTime.now(),
      );

      await ContractsService.createContract(contract);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al crear contrato: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(title: 'Nuevo Contrato'),
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categoría',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      dropdownColor: AppColors.surface,
                      value: _selectedCategory,
                      hint: const Text(
                        'Selecciona una categoría',
                        style: TextStyle(color: Colors.white54),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(
                            cat,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val;
                          _selectedMaterial = null;
                        });
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_selectedCategory != null) ...[
                      const Text(
                        'Selecciona un Material',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: _filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final mat = _filteredMaterials[index];
                          final isSelected = _selectedMaterial?.id == mat.id;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedMaterial = mat),
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              foregroundDecoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white24,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.asset(
                                      mat.imagePath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.inventory,
                                        size: 40,
                                        color: Colors.white24,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                      ),
                                      child: Text(
                                        mat.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cantidad',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  hintText: 'Ej: 500',
                                  hintStyle: const TextStyle(
                                    color: Colors.white38,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Días Límite',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _deadlineController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  hintText: 'Ej: 7',
                                  hintStyle: const TextStyle(
                                    color: Colors.white38,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: IndustrialButton(
                        label: 'Generar Contrato',
                        onPressed: _createContract,
                        gradientTop: AppColors.secondary,
                        gradientBottom: const Color(0xFF2E7D32),
                        borderColor: const Color(0xFF1B5E20),
                        width: double.infinity,
                        height: 60,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
