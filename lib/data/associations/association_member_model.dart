enum AssociationRole { creator, admin, member }

enum MemberStatus { active, left, kicked }

extension AssociationRoleExt on AssociationRole {
  String toJson() => name;
  static AssociationRole fromJson(String? json) {
    return AssociationRole.values.firstWhere(
      (e) => e.name == json,
      orElse: () => AssociationRole.member,
    );
  }
}

extension MemberStatusExt on MemberStatus {
  String toJson() => name;
  static MemberStatus fromJson(String? json) {
    return MemberStatus.values.firstWhere(
      (e) => e.name == json,
      orElse: () => MemberStatus.active,
    );
  }
}

class AssociationMemberModel {
  final String id;
  final String associationId;
  final String userId;
  final AssociationRole role;
  final MemberStatus status;
  final DateTime joinedAt;
  final Map<String, bool> permissions;

  AssociationMemberModel({
    required this.id,
    required this.associationId,
    required this.userId,
    required this.role,
    this.status = MemberStatus.active,
    required this.joinedAt,
    this.permissions = const {},
  });

  factory AssociationMemberModel.fromJson(Map<String, dynamic> json) {
    return AssociationMemberModel(
      id: json['id'] as String,
      associationId: json['association_id'] as String,
      userId: json['user_id'] as String,
      role: AssociationRoleExt.fromJson(json['role'] as String?),
      status: MemberStatusExt.fromJson(json['status'] as String?),
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
      permissions: Map<String, bool>.from(json['permissions'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'association_id': associationId,
    'user_id': userId,
    'role': role.toJson(),
    'status': status.toJson(),
    'joined_at': joinedAt.toIso8601String(),
    'permissions': permissions,
  };

  AssociationMemberModel copyWith({
    String? id,
    String? associationId,
    String? userId,
    AssociationRole? role,
    MemberStatus? status,
    DateTime? joinedAt,
    Map<String, bool>? permissions,
  }) {
    return AssociationMemberModel(
      id: id ?? this.id,
      associationId: associationId ?? this.associationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      permissions: permissions ?? this.permissions,
    );
  }
}
