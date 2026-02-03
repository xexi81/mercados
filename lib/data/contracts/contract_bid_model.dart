class ContractBidModel {
  final String id;
  final String contractId;
  final String bidderId;
  final int pricePerUnit;
  final DateTime createdAt;

  // Optional: Add username/avatar if we want to display who is bidding without extra queries
  final String? bidderName;

  ContractBidModel({
    required this.id,
    required this.contractId,
    required this.bidderId,
    required this.pricePerUnit,
    required this.createdAt,
    this.bidderName,
  });

  factory ContractBidModel.fromJson(Map<String, dynamic> json) {
    return ContractBidModel(
      id: json['id'],
      contractId: json['contract_id'],
      bidderId: json['bidder_id'],
      pricePerUnit: json['price_per_unit'],
      createdAt: DateTime.parse(json['created_at']),
      bidderName: json['bidder_name'], // If we use a view or join
    );
  }

  Map<String, dynamic> toJson() => {
    'contract_id': contractId,
    'bidder_id': bidderId,
    'price_per_unit': pricePerUnit,
  };
}
