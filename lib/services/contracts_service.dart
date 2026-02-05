import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../data/contracts/contract_model.dart';
import '../data/contracts/contract_bid_model.dart';

class ContractsService {
  static final SupabaseClient _client = SupabaseClient(
    'https://ajmotxkilbvavcuwkfam.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFqbW90eGtpbGJ2YXZjdXdrZmFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxNDg1MDksImV4cCI6MjA4NTcyNDUwOX0.wCQa_LI4UlVWGQzQ9jJSMZzY8UBxHqbU0K9ql3fEmpo',
  );

  static SupabaseClient get client => _client;

  // --- Contracts ---

  /// Stream of pending contracts available for bidding (not created by current user)
  static Stream<List<ContractModel>> getAvailableContractsStream(
    String currentUserId, {
    int? materialId,
  }) {
    return _client
        .from('contracts')
        .stream(primaryKey: ['id'])
        .map(
          (data) => data
              .where(
                (json) =>
                    json['status'] == 'PENDING' &&
                    json['creator_id'] != currentUserId &&
                    (materialId == null || json['material_id'] == materialId),
              )
              .map((json) => ContractModel.fromJson(json))
              .toList(),
        );
  }

  /// Stream of contracts created by the current user
  static Stream<List<ContractModel>> getMyContractsStream(
    String currentUserId,
  ) {
    return _client
        .from('contracts')
        .stream(primaryKey: ['id'])
        .eq('creator_id', currentUserId)
        .order('created_at', ascending: false)
        .map(
          (data) => data.map((json) => ContractModel.fromJson(json)).toList(),
        );
  }

  /// Stream of contracts where the current user is the assignee (accepted)
  static Stream<List<ContractModel>> getAssignedToMeStream(
    String currentUserId,
  ) {
    return _client
        .from('contracts')
        .stream(primaryKey: ['id'])
        .map(
          (data) => data
              .where(
                (json) =>
                    json['assignee_id'] == currentUserId &&
                    json['status'] == 'ACCEPTED',
              )
              .map((json) => ContractModel.fromJson(json))
              .toList(),
        );
  }

  static Future<List<ContractModel>> getContractsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final data = await _client
        .from('contracts')
        .select()
        .filter('id', 'in', ids);
    return (data as List).map((json) => ContractModel.fromJson(json)).toList();
  }

  static Future<void> createContract(ContractModel contract) async {
    await _client.from('contracts').insert(contract.toJson());
  }

  static Future<void> cancelContract(String contractId) async {
    await _client.from('contracts').delete().eq('id', contractId);
  }

  // --- Bids ---

  static Stream<List<ContractBidModel>> getBidsForContractStream(
    String contractId,
  ) {
    return _client
        .from('contract_bids')
        .stream(primaryKey: ['id'])
        .map(
          (data) => data
              .where((json) => json['contract_id'] == contractId)
              .map((json) => ContractBidModel.fromJson(json))
              .toList(),
        );
  }

  /// Stream of bids placed by the current user
  static Stream<List<ContractBidModel>> getMyBidsStream(String currentUserId) {
    return _client
        .from('contract_bids')
        .stream(primaryKey: ['id'])
        .map(
          (data) => data
              .where((json) => json['bidder_id'] == currentUserId)
              .map((json) => ContractBidModel.fromJson(json))
              .toList(),
        );
  }

  static Future<void> placeBid(ContractBidModel bid) async {
    await _client.from('contract_bids').upsert(bid.toJson());
  }

  /// Accepts a bid, setting up the contract as accepted and deleting other bids
  static Future<void> acceptBid(
    String contractId,
    String bidderId,
    int price,
  ) async {
    print('💰 [ACCEPT BID] Starting acceptBid');
    print('💰 [ACCEPT BID] contractId: $contractId');
    print('💰 [ACCEPT BID] bidderId: $bidderId');
    print('💰 [ACCEPT BID] price per unit: $price');

    try {
      // Get the current user (the one accepting the bid = creator of contract)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user authenticated');
      }
      final creatorId = currentUser.uid;
      print('💰 [ACCEPT BID] creatorId (current user): $creatorId');

      // Note: In a production app, this should be a DB function/transaction
      // to ensure atomicity and handle money deduction securely.

      // First, get the contract to know the quantity
      print('💰 [ACCEPT BID] Fetching contract from Supabase...');
      final contractResponse = await _client
          .from('contracts')
          .select('quantity')
          .eq('id', contractId)
          .single();

      final int quantity = contractResponse['quantity'] ?? 0;
      final double totalCost = (quantity * price).toDouble();
      print('💰 [ACCEPT BID] quantity: $quantity, totalCost: $totalCost');

      // Update Supabase contract
      print('💰 [ACCEPT BID] Updating Supabase contract...');
      await _client
          .from('contracts')
          .update({
            'assignee_id': bidderId,
            'status': 'ACCEPTED',
            'accepted_at': DateTime.now().toIso8601String(),
            'accepted_price': price,
          })
          .eq('id', contractId);
      print('💰 [ACCEPT BID] Supabase contract updated');

      // Deduct money from creator (current user) in Firestore
      print('💰 [ACCEPT BID] Deducting money from creator in Firestore...');
      final userRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(creatorId);

      // First, get current money to log it
      final userDocBefore = await userRef.get();
      final currentMoneyBefore =
          (userDocBefore.data()?['dinero'] as num?)?.toDouble() ?? 0.0;
      print(
        '💰 [ACCEPT BID] Creator current money before: $currentMoneyBefore',
      );

      await userRef.update({'dinero': FieldValue.increment(-totalCost)});
      print('💰 [ACCEPT BID] Firestore money deducted: $totalCost');

      // Verify the update
      final userDocAfter = await userRef.get();
      final currentMoneyAfter =
          (userDocAfter.data()?['dinero'] as num?)?.toDouble() ?? 0.0;
      print('💰 [ACCEPT BID] Creator current money after: $currentMoneyAfter');

      // Other bids are usually deleted by cascade or manually
      print('💰 [ACCEPT BID] Deleting other bids...');
      await _client
          .from('contract_bids')
          .delete()
          .eq('contract_id', contractId);
      print('💰 [ACCEPT BID] acceptBid completed successfully');
    } catch (e, st) {
      print('💰 [ACCEPT BID] Error: $e');
      print('💰 [ACCEPT BID] Stack trace: $st');
      rethrow;
    }
  }

  // --- Fulfillment ---

  static Future<void> updateFulfillment(
    String contractId,
    int additionalQuantity,
  ) async {
    final response = await _client
        .from('contracts')
        .select('fulfilled_quantity, quantity, pending_stock')
        .eq('id', contractId)
        .single();

    final int currentFulfilled = response['fulfilled_quantity'] ?? 0;
    final int currentPending = response['pending_stock'] ?? 0;
    final int total = response['quantity'];

    final int newFulfilled = currentFulfilled + additionalQuantity;
    final int newPending = currentPending + additionalQuantity;

    final Map<String, dynamic> updates = {
      'fulfilled_quantity': newFulfilled,
      'pending_stock': newPending,
    };

    if (newFulfilled >= total) {
      updates['status'] = 'FULFILLED';
    }

    await _client.from('contracts').update(updates).eq('id', contractId);
  }

  static Future<void> moveStockToWarehouse(
    String contractId,
    int quantity,
  ) async {
    print(
      '💾 [MOVE TO WAREHOUSE] Starting - contractId: $contractId, quantity: $quantity',
    );

    try {
      // Get contract details from Supabase
      final response = await _client
          .from('contracts')
          .select(
            'pending_stock, status, material_id, location_id, accepted_price',
          )
          .eq('id', contractId)
          .single();

      final int currentPending = response['pending_stock'] ?? 0;
      final String status = response['status'];
      final int materialId = response['material_id'] ?? 0;
      final int acceptedPrice = response['accepted_price'] ?? 0;

      print(
        '💾 [MOVE TO WAREHOUSE] Contract found - pending: $currentPending, status: $status, material_id: $materialId, accepted_price: $acceptedPrice',
      );

      // Update Supabase: decrease pending_stock
      await _client
          .from('contracts')
          .update({'pending_stock': currentPending - quantity})
          .eq('id', contractId);

      print(
        '💾 [MOVE TO WAREHOUSE] Supabase updated - pending_stock decreased by $quantity',
      );

      // Now add stock to Firestore warehouse
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user authenticated for warehouse transfer');
      }

      print(
        '💾 [MOVE TO WAREHOUSE] Adding stock to Firestore warehouse for user: ${user.uid}',
      );

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final warehouseUserRef = FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('warehouse_users')
            .doc(user.uid);

        final warehouseDoc = await transaction.get(warehouseUserRef);

        if (!warehouseDoc.exists) {
          print('💾 [MOVE TO WAREHOUSE] Warehouse document does not exist!');
          throw Exception('Warehouse not found for user');
        }

        Map<String, dynamic> warehouseData = Map<String, dynamic>.from(
          warehouseDoc.data() as Map,
        );

        // Get material info to find its grade
        final materialsJson = await rootBundle.loadString(
          'assets/data/materials.json',
        );
        final materialsData = json.decode(materialsJson);
        final materials = materialsData['materials'] as List;
        final materialInfo = materials.firstWhere(
          (m) => m['id'] == materialId,
          orElse: () => null,
        );

        if (materialInfo == null) {
          throw Exception('Material $materialId not found');
        }

        final materialGrade = materialInfo['grade'] as int? ?? 1;
        final m3PerUnit =
            (materialInfo['unitVolumeM3'] as num?)?.toDouble() ?? 1.0;

        print(
          '💾 [MOVE TO WAREHOUSE] Material info - grade: $materialGrade, m3PerUnit: $m3PerUnit',
        );

        // Find or create warehouse slot for this grade
        List<Map<String, dynamic>> slots = List<Map<String, dynamic>>.from(
          warehouseData['slots'] ?? [],
        );

        Map<String, dynamic>? targetSlot = slots.firstWhere(
          (s) => s['warehouseId'] == materialGrade,
          orElse: () => <String, dynamic>{},
        );

        if (targetSlot.isEmpty) {
          print(
            '💾 [MOVE TO WAREHOUSE] Warehouse slot for grade $materialGrade not found - this should not happen after validation',
          );
          throw Exception('Warehouse grade $materialGrade not available');
        }

        // Update storage in the slot
        Map<String, dynamic> storage = Map<String, dynamic>.from(
          targetSlot['storage'] as Map? ?? {},
        );

        final materialIdStr = materialId.toString();
        final currentData = storage[materialIdStr] as Map? ?? {};
        final currentUnits = (currentData['units'] as num?)?.toInt() ?? 0;
        final currentAveragePrice =
            (currentData['averagePrice'] as num?)?.toDouble() ?? 0.0;

        print(
          '💾 [MOVE TO WAREHOUSE] Current storage for material $materialId - units: $currentUnits, averagePrice: $currentAveragePrice',
        );

        // Calculate new average price with weighted average
        double newAveragePrice;
        if (currentUnits > 0) {
          // Weighted average: (current units * current price + new units * new price) / total units
          newAveragePrice =
              (currentUnits * currentAveragePrice + quantity * acceptedPrice) /
              (currentUnits + quantity);
          print(
            '💾 [MOVE TO WAREHOUSE] Calculating weighted average - current: ($currentUnits × $currentAveragePrice) + new: ($quantity × $acceptedPrice) = $newAveragePrice',
          );
        } else {
          // First stock of this material, use accepted price directly
          newAveragePrice = acceptedPrice.toDouble();
          print(
            '💾 [MOVE TO WAREHOUSE] First stock entry - using accepted_price: $newAveragePrice',
          );
        }

        // Update the material storage
        storage[materialIdStr] = {
          'units': currentUnits + quantity,
          'm3PerUnit': m3PerUnit,
          'averagePrice': newAveragePrice,
        };

        print(
          '💾 [MOVE TO WAREHOUSE] Updated storage - units: ${currentUnits + quantity}, averagePrice: ${newAveragePrice.toStringAsFixed(2)}',
        );

        targetSlot['storage'] = storage;

        // Find and update the slot in the list
        final slotIndex = slots.indexWhere(
          (s) => s['warehouseId'] == materialGrade,
        );
        if (slotIndex != -1) {
          slots[slotIndex] = targetSlot;
        }

        warehouseData['slots'] = slots;
        transaction.set(warehouseUserRef, warehouseData);

        print(
          '💾 [MOVE TO WAREHOUSE] Firestore warehouse updated - added $quantity units to material $materialId',
        );
      });

      // Delete contract if it was FULFILLED and stock is fully cleared
      if (status == 'FULFILLED' && (currentPending - quantity) <= 0) {
        await _client.from('contracts').delete().eq('id', contractId);
        print(
          '💾 [MOVE TO WAREHOUSE] Contract deleted (was FULFILLED and fully cleared)',
        );
      }

      print(
        '💾 [MOVE TO WAREHOUSE] moveStockToWarehouse completed successfully',
      );
    } catch (e, st) {
      print('💾 [MOVE TO WAREHOUSE] Error: $e');
      print('💾 [MOVE TO WAREHOUSE] Stack trace: $st');
      rethrow;
    }
  }
}
