import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/contracts/contract_model.dart';
import 'package:industrial_app/data/contracts/contract_bid_model.dart';
import 'package:industrial_app/data/contracts/contract_enums.dart';
import 'package:industrial_app/services/contracts_service.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/data/locations/location_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/data/locations/distance_calculator.dart';
import 'new_contract_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  Map<int, MaterialModel> _materialCache = {};
  LocationModel? _currentUserHq;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final materials = await MaterialsRepository.loadMaterials();

    // Cargar HQ del usuario
    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUserId)
        .get();

    final hqId = userDoc.data()?['headquarter_id']?.toString();
    if (hqId != null) {
      final locations = await LocationsRepository.loadLocations();
      _currentUserHq = locations.cast<LocationModel?>().firstWhere(
        (l) => l?.id.toString() == hqId,
        orElse: () => null,
      );
    }

    setState(() {
      _materialCache = {for (var m in materials) m.id: m};
    });
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CustomGameAppBar(title: ''),
              Container(
                color: AppColors.surface,
                child: const TabBar(
                  isScrollable: true,
                  indicatorColor: Colors.amber,
                  labelColor: Colors.amber,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(text: 'Mis Contratos'),
                    Tab(text: 'Asignados'),
                    Tab(text: 'Mis Pujas'),
                    Tab(text: 'Buscar'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MyContractsTab(
              currentUserId: currentUserId,
              materialCache: _materialCache,
              onRefresh: _refresh,
              userHq: _currentUserHq,
            ),
            _AssignedContractsTab(
              currentUserId: currentUserId,
              materialCache: _materialCache,
              onRefresh: _refresh,
              userHq: _currentUserHq,
            ),
            _MyBidsTab(
              currentUserId: currentUserId,
              materialCache: _materialCache,
              onRefresh: _refresh,
              userHq: _currentUserHq,
            ),
            _SearchContractsTab(
              currentUserId: currentUserId,
              materialCache: _materialCache,
              onRefresh: _refresh,
              userHq: _currentUserHq,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.orangeAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white, width: 1),
          ),
          child: Icon(Icons.description, color: AppColors.surface, size: 32),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewContractScreen()),
            );
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }
}

class _MyContractsTab extends StatelessWidget {
  final String currentUserId;
  final Map<int, MaterialModel> materialCache;
  final VoidCallback onRefresh;
  final LocationModel? userHq;

  const _MyContractsTab({
    required this.currentUserId,
    required this.materialCache,
    required this.onRefresh,
    this.userHq,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContractModel>>(
      stream: ContractsService.getMyContractsStream(this.currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final contracts = snapshot.data!;
        if (contracts.isEmpty)
          return const Center(child: Text('No tienes contratos creados'));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: contracts.length,
          itemBuilder: (context, index) {
            final contract = contracts[index];
            final material = materialCache[contract.materialId];
            return _ContractCard(
              contract: contract,
              material: material,
              isCreator: true,
              currentUserId: currentUserId,
              onRefresh: onRefresh,
              userHq: userHq,
            );
          },
        );
      },
    );
  }
}

class _AssignedContractsTab extends StatelessWidget {
  final String currentUserId;
  final Map<int, MaterialModel> materialCache;
  final VoidCallback onRefresh;
  final LocationModel? userHq;

  const _AssignedContractsTab({
    required this.currentUserId,
    required this.materialCache,
    required this.onRefresh,
    this.userHq,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContractModel>>(
      stream: ContractsService.getAssignedToMeStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final contracts = snapshot.data!;
        if (contracts.isEmpty)
          return const Center(child: Text('No tienes contratos asignados'));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: contracts.length,
          itemBuilder: (context, index) {
            final contract = contracts[index];
            final material = materialCache[contract.materialId];
            return _ContractCard(
              contract: contract,
              material: material,
              isCreator: false,
              currentUserId: currentUserId,
              onRefresh: onRefresh,
              userHq: userHq,
            );
          },
        );
      },
    );
  }
}

class _SearchContractsTab extends StatefulWidget {
  final String currentUserId;
  final Map<int, MaterialModel> materialCache;
  final VoidCallback onRefresh;
  final LocationModel? userHq;

  const _SearchContractsTab({
    required this.currentUserId,
    required this.materialCache,
    required this.onRefresh,
    this.userHq,
  });

  @override
  State<_SearchContractsTab> createState() => _SearchContractsTabState();
}

class _SearchContractsTabState extends State<_SearchContractsTab> {
  String? _selectedCategory;
  MaterialModel? _selectedMaterial;
  List<MaterialModel> _allMaterials = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final materials = await MaterialsRepository.loadMaterials();
    if (mounted) {
      setState(() {
        _allMaterials = materials;
      });
    }
  }

  List<String> get _categories =>
      _allMaterials.map((m) => m.category).toSet().toList();

  List<MaterialModel> get _filteredMaterials =>
      _allMaterials.where((m) => m.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtros (Scrollable)
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FILTRAR POR:',
                style: GoogleFonts.orbitron(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                dropdownColor: AppColors.surface,
                value: _selectedCategory,
                hint: const Text(
                  'Selecciona una categoría',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(
                      cat.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
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
                  fillColor: Colors.black26,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              if (_selectedCategory != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filteredMaterials.length,
                    itemBuilder: (context, index) {
                      final mat = _filteredMaterials[index];
                      final isSelected = _selectedMaterial?.id == mat.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMaterial = mat),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white12,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset(
                                    mat.imagePath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.inventory,
                                      color: Colors.white10,
                                    ),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(6),
                                    ),
                                  ),
                                  child: Text(
                                    mat.name.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 8,
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
                ),
              ],
            ],
          ),
        ),
        // Resultados
        Expanded(
          child: StreamBuilder<List<ContractModel>>(
            stream: ContractsService.getAvailableContractsStream(
              widget.currentUserId,
              materialId: _selectedMaterial?.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final contracts = snapshot.data!;
              if (contracts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedMaterial != null
                            ? 'No hay contratos para ${_selectedMaterial!.name}'
                            : 'No hay contratos disponibles ahora',
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: contracts.length,
                itemBuilder: (context, index) {
                  final contract = contracts[index];
                  final material = widget.materialCache[contract.materialId];
                  return _ContractCard(
                    contract: contract,
                    material: material,
                    isSearch: true,
                    currentUserId: widget.currentUserId,
                    onRefresh: widget.onRefresh,
                    userHq: widget.userHq,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MyBidsTab extends StatelessWidget {
  final String currentUserId;
  final Map<int, MaterialModel> materialCache;
  final VoidCallback onRefresh;
  final LocationModel? userHq;

  const _MyBidsTab({
    required this.currentUserId,
    required this.materialCache,
    required this.onRefresh,
    this.userHq,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContractBidModel>>(
      stream: ContractsService.getMyBidsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bids = snapshot.data!;
        if (bids.isEmpty) {
          return const Center(child: Text('No has realizado ninguna puja aún'));
        }

        final contractIds = bids.map((b) => b.contractId).toList();

        return FutureBuilder<List<ContractModel>>(
          future: ContractsService.getContractsByIds(contractIds),
          builder: (context, contractsSnapshot) {
            if (contractsSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error al cargar contratos: ${contractsSnapshot.error}',
                ),
              );
            }
            if (!contractsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final contracts = contractsSnapshot.data!;
            if (contracts.isEmpty) {
              return const Center(
                child: Text(
                  'Los contratos de tus pujas ya no están disponibles',
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contracts.length,
              itemBuilder: (context, index) {
                final contract = contracts[index];
                final material = materialCache[contract.materialId];
                return _ContractCard(
                  contract: contract,
                  material: material,
                  isSearch: true, // Show bidding UI
                  currentUserId: currentUserId,
                  onRefresh: onRefresh,
                  userHq: userHq,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ContractCard extends StatelessWidget {
  final ContractModel contract;
  final MaterialModel? material;
  final bool isCreator;
  final bool isSearch;
  final String currentUserId;
  final VoidCallback onRefresh;
  final LocationModel? userHq;

  const _ContractCard({
    required this.contract,
    this.material,
    this.isCreator = false,
    this.isSearch = false,
    required this.currentUserId,
    required this.onRefresh,
    this.userHq,
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 12.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2),
        child: Stack(
          children: [
            // Subfondo industrial opcional
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Image.asset(
                  'assets/images/parking/no_info.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info del creador y Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Nombre y Sede del creador (Top-Left)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(
                              contract.status == ContractStatus.accepted ||
                                      contract.status ==
                                          ContractStatus.fulfilled
                                  ? contract.assigneeId
                                  : contract.creatorId,
                            )
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final userData =
                              snapshot.data?.data() as Map<String, dynamic>?;

                          // Jerarquía: Empresa > Nickname > Nombre
                          final name =
                              (userData?['empresa']?.toString().isNotEmpty ==
                                  true)
                              ? userData!['empresa']
                              : (userData?['nickname']?.toString().isNotEmpty ==
                                    true)
                              ? userData!['nickname']
                              : (userData?['nombre']?.toString().isNotEmpty ==
                                    true)
                              ? userData!['nombre']
                              : 'Usuario';

                          final hqId = userData?['headquarter_id'];

                          final bool isAssignee =
                              contract.status == ContractStatus.accepted ||
                              contract.status == ContractStatus.fulfilled;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (isAssignee
                                        ? 'ASIGNADO: $name'
                                        : name.toString())
                                    .toUpperCase(),
                                style: GoogleFonts.orbitron(
                                  color: isAssignee
                                      ? AppColors.secondary
                                      : Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (hqId != null)
                                _CityText(
                                  cityId: hqId.toString(),
                                  userHq:
                                      (isAssignee
                                              ? contract.assigneeId
                                              : contract.creatorId) !=
                                          currentUserId
                                      ? userHq
                                      : null,
                                ),
                            ],
                          );
                        },
                      ),
                      // Status (Top-Right)
                      _StatusBadge(status: contract.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Mini-card para el material
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: material != null
                              ? Image.asset(
                                  material!.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.inventory,
                                    color: Colors.white24,
                                    size: 24,
                                  ),
                                )
                              : const Icon(
                                  Icons.inventory,
                                  color: Colors.white24,
                                  size: 24,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              material?.name.toUpperCase() ??
                                  'MATERIAL DESCONOCIDO',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (material != null)
                              Text(
                                contract.status == ContractStatus.accepted ||
                                        contract.status ==
                                            ContractStatus.fulfilled
                                    ? 'P. ACORDADO: ${contract.acceptedPrice ?? 0} €'
                                    : 'P. BASE: ${material!.basePrice} €',
                                style: GoogleFonts.montserrat(
                                  color: AppColors.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Barra técnica de ancho completo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CANTIDAD: ${contract.quantity} UDs.',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (contract.status == ContractStatus.accepted)
                          Text(
                            'EXPIRA EN: ${contract.remainingTime}',
                            style: GoogleFonts.montserrat(
                              color: Colors.orangeAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        else
                          Text(
                            'PLAZO: ${contract.deadlineDays} DÍAS',
                            style: GoogleFonts.montserrat(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (contract.status == ContractStatus.accepted ||
                      contract.status == ContractStatus.fulfilled) ...[
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: contract.progress.clamp(0.0, 1.0),
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.secondary,
                                  Color(0xFF2E7D32),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PROGRESO: ${contract.fulfilledQuantity} / ${contract.quantity}',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  if (isCreator &&
                      contract.status == ContractStatus.pending) ...[
                    const Divider(color: Colors.white24, height: 32),
                    Text(
                      'PUJAS RECIBIDAS:',
                      style: GoogleFonts.orbitron(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BidsList(
                      key: ValueKey(contract.id),
                      contractId: contract.id,
                      onRefresh: onRefresh,
                      userHq: userHq,
                      currentUserId: currentUserId,
                    ),
                    const SizedBox(height: 12),
                    IndustrialButton(
                      label: 'CANCELAR CONTRATO',
                      onPressed: () => _showCancelConfirmation(context),
                      gradientTop: Colors.redAccent,
                      gradientBottom: const Color(0xFFB71C1C),
                      borderColor: const Color(0xFF7F0000),
                      fontSize: 12,
                      height: 40,
                    ),
                  ],
                  if (isSearch) ...[
                    const SizedBox(height: 16),
                    StreamBuilder<List<ContractBidModel>>(
                      stream: ContractsService.getBidsForContractStream(
                        contract.id,
                      ),
                      builder: (context, snapshot) {
                        final bids = snapshot.data ?? [];
                        final userBid = bids
                            .where((b) => b.bidderId == currentUserId)
                            .firstOrNull;

                        return Column(
                          children: [
                            if (userBid != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.secondary.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TU PUJA ACTUAL:',
                                      style: GoogleFonts.orbitron(
                                        color: AppColors.secondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${userBid.pricePerUnit} €/UD',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            IndustrialButton(
                              label: userBid != null
                                  ? 'MODIFICAR PUJA'
                                  : 'PUJAR POR ESTE CONTRATO',
                              onPressed: () => _showBidDialog(
                                context,
                                existingPrice: userBid?.pricePerUnit,
                              ),
                              gradientTop: userBid != null
                                  ? AppColors.secondary
                                  : AppColors.primary,
                              gradientBottom: userBid != null
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF1E3A8A),
                              borderColor: userBid != null
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFF172554),
                              fontSize: 14,
                              height: 50,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  if (isCreator && contract.pendingStock > 0) ...[
                    const SizedBox(height: 16),
                    IndustrialButton(
                      label: 'MOVER BOLSA (${contract.pendingStock})',
                      onPressed: () => _moveStockToWarehouse(context),
                      gradientTop: Colors.orange,
                      gradientBottom: const Color(0xFFE65100),
                      borderColor: const Color(0xFFBF360C),
                      fontSize: 12,
                      height: 45,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 2),
        ),
        title: Text(
          'CANCELAR CONTRATO',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas cancelar este contrato? Se eliminará permanentemente junto con todas las pujas recibidas.',
          style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          Row(
            children: [
              Expanded(
                child: IndustrialButton(
                  label: 'VOLVER',
                  onPressed: () => Navigator.pop(context),
                  gradientTop: Colors.grey,
                  gradientBottom: Colors.grey.shade800,
                  borderColor: Colors.white24,
                  height: 40,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IndustrialButton(
                  label: 'CONFIRMAR',
                  onPressed: () async {
                    await ContractsService.cancelContract(contract.id);
                    if (context.mounted) Navigator.pop(context);
                    onRefresh();
                  },
                  gradientTop: Colors.redAccent,
                  gradientBottom: const Color(0xFFB71C1C),
                  borderColor: const Color(0xFF7F0000),
                  height: 40,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBidDialog(BuildContext context, {int? existingPrice}) {
    final int defaultPrice =
        existingPrice ?? ((material?.basePrice ?? 100) * 1.5).toInt();

    showDialog(
      context: context,
      builder: (context) => _BidDialog(
        contract: contract,
        material: material,
        initialPrice: defaultPrice,
        onConfirm: (price) async {
          final bid = ContractBidModel(
            id: '', // Supabase uses uuid_generate_v4
            contractId: contract.id,
            bidderId: currentUserId,
            pricePerUnit: price,
            createdAt: DateTime.now(),
          );
          await ContractsService.placeBid(bid);
          onRefresh();
        },
      ),
    );
  }

  void _moveStockToWarehouse(BuildContext context) {
    // Implementation for moving stock
    ContractsService.moveStockToWarehouse(contract.id, contract.pendingStock);
  }
}

class _StatusBadge extends StatelessWidget {
  final ContractStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor(), width: 1.5),
        boxShadow: [
          BoxShadow(color: _getColor().withOpacity(0.1), blurRadius: 4),
        ],
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: GoogleFonts.orbitron(
          color: _getColor(),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case ContractStatus.pending:
        return Colors.orangeAccent;
      case ContractStatus.accepted:
        return Colors.lightBlueAccent;
      case ContractStatus.cancelled:
        return Colors.redAccent;
      case ContractStatus.fulfilled:
        return Colors.lightGreenAccent;
    }
  }
}

class _BidsList extends StatefulWidget {
  final String contractId;
  final VoidCallback onRefresh;
  final LocationModel? userHq;
  final String currentUserId;
  const _BidsList({
    super.key,
    required this.contractId,
    required this.onRefresh,
    this.userHq,
    required this.currentUserId,
  });

  @override
  State<_BidsList> createState() => _BidsListState();
}

class _BidsListState extends State<_BidsList> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContractBidModel>>(
      stream: ContractsService.getBidsForContractStream(widget.contractId),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Text(
            'Cargando pujas...',
            style: TextStyle(fontSize: 12),
          );
        final bids = snapshot.data!;
        if (bids.isEmpty)
          return const Text(
            'Sin pujas aún',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          );

        return Column(
          children: bids
              .map(
                (bid) => _BidderRow(
                  bid: bid,
                  contractId: widget.contractId,
                  onRefresh: () {
                    widget.onRefresh();
                    setState(() {});
                  },
                  userHq: widget.userHq,
                  currentUserId: widget.currentUserId,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _BidderRow extends StatelessWidget {
  final ContractBidModel bid;
  final String contractId;
  final VoidCallback onRefresh;
  final LocationModel? userHq;
  final String currentUserId;

  const _BidderRow({
    required this.bid,
    required this.contractId,
    required this.onRefresh,
    this.userHq,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(bid.bidderId)
          .get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;

        // Jerarquía: Empresa > Nickname > Nombre
        final name = (userData?['empresa']?.toString().isNotEmpty == true)
            ? userData!['empresa']
            : (userData?['nickname']?.toString().isNotEmpty == true)
            ? userData!['nickname']
            : (userData?['nombre']?.toString().isNotEmpty == true)
            ? userData!['nombre']
            : 'Usuario';

        final photo = userData?['foto_url'] ?? userData?['photoURL'];
        final hqId = userData?['headquarter_id'];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white12,
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null
                        ? const Icon(
                            Icons.person,
                            size: 24,
                            color: Colors.white54,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${bid.pricePerUnit} €/UD',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (hqId != null)
                          _CityText(
                            cityId: hqId.toString(),
                            userHq: bid.bidderId != currentUserId
                                ? userHq
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              IndustrialButton(
                label: 'ACEPTAR PUJA',
                onPressed: () async {
                  await ContractsService.acceptBid(
                    contractId,
                    bid.bidderId,
                    bid.pricePerUnit,
                  );
                  onRefresh();
                },
                gradientTop: AppColors.secondary,
                gradientBottom: const Color(0xFF2E7D32),
                borderColor: const Color(0xFF1B5E20),
                fontSize: 12,
                height: 40,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CityText extends StatelessWidget {
  final String cityId;
  final LocationModel? userHq;
  const _CityText({required this.cityId, this.userHq});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LocationModel>>(
      future: LocationsRepository.loadLocations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final locations = snapshot.data!;
        try {
          final city = locations.firstWhere((l) => l.id.toString() == cityId);
          String displayText = city.city.toUpperCase();

          if (userHq != null && userHq!.id != city.id) {
            final distance = DistanceCalculator.calculateDistance(
              userHq!.latitude,
              userHq!.longitude,
              city.latitude,
              city.longitude,
            );
            displayText += ' (${distance.toStringAsFixed(0)} KM)';
          }

          return Text(
            displayText,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          );
        } catch (_) {
          return const SizedBox.shrink();
        }
      },
    );
  }
}

class _BidDialog extends StatefulWidget {
  final ContractModel contract;
  final MaterialModel? material;
  final int initialPrice;
  final Function(int) onConfirm;

  const _BidDialog({
    required this.contract,
    this.material,
    required this.initialPrice,
    required this.onConfirm,
  });

  @override
  State<_BidDialog> createState() => _BidDialogState();
}

class _BidDialogState extends State<_BidDialog> {
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.initialPrice.toString(),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
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
            Text(
              'PUJAR POR CONTRATO',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Introduce tu oferta por unidad para ${widget.material?.name.toUpperCase() ?? 'el material'}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
              decoration: InputDecoration(
                suffixText: ' €/UD',
                suffixStyle: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 16,
                ),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.material != null)
              Text(
                'PRECIO BASE: ${widget.material!.basePrice} €',
                style: GoogleFonts.montserrat(
                  color: AppColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: IndustrialButton(
                    label: 'CANCELAR',
                    onPressed: () => Navigator.pop(context),
                    gradientTop: Colors.grey,
                    gradientBottom: Colors.grey.shade800,
                    borderColor: Colors.white24,
                    height: 50,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: IndustrialButton(
                    label: 'CONFIRMAR',
                    onPressed: () {
                      final price = int.tryParse(_priceController.text);
                      if (price != null && price > 0) {
                        widget.onConfirm(price);
                        Navigator.pop(context);
                      }
                    },
                    gradientTop: AppColors.secondary,
                    gradientBottom: const Color(0xFF2E7D32),
                    borderColor: const Color(0xFF1B5E20),
                    height: 50,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
