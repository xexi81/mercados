import 'package:supabase_flutter/supabase_flutter.dart';
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
    // Note: In a production app, this should be a DB function/transaction
    // to ensure atomicity and handle money deduction securely.

    await _client
        .from('contracts')
        .update({
          'assignee_id': bidderId,
          'status': 'ACCEPTED',
          'accepted_at': DateTime.now().toIso8601String(),
          'accepted_price': price,
        })
        .eq('id', contractId);

    // Other bids are usually deleted by cascade or manually
    await _client.from('contract_bids').delete().eq('contract_id', contractId);
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
    final response = await _client
        .from('contracts')
        .select('pending_stock, status')
        .eq('id', contractId)
        .single();

    final int currentPending = response['pending_stock'] ?? 0;
    final String status = response['status'];

    await _client
        .from('contracts')
        .update({'pending_stock': currentPending - quantity})
        .eq('id', contractId);

    // If fulfilled and stock is cleared, we could delete it,
    // but the requirement says "when moving ALL stock for a FINISHED contract"
    if (status == 'FULFILLED' && (currentPending - quantity) <= 0) {
      await _client.from('contracts').delete().eq('id', contractId);
    }
  }
}
