import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:industrial_app/data/associations/association_member_model.dart';
import 'package:industrial_app/data/associations/association_model.dart';
import 'package:industrial_app/data/associations/association_repository.dart';

class AssociationService {
  /// Verificar si usuario tiene una asociación activa
  static Future<bool> hasAssociation(String userId) async {
    final assoc = await AssociationRepository.getUserAssociation(userId);
    return assoc != null;
  }

  /// Verificar si usuario es creador/admin
  static Future<bool> hasPermissionToManage(
    String userId,
    String associationId,
  ) async {
    final members = await AssociationRepository.getAssociationMembers(
      associationId,
    );
    try {
      final member = members.firstWhere((m) => m.userId == userId);
      return member.role == AssociationRole.creator ||
          member.role == AssociationRole.admin;
    } catch (e) {
      return false;
    }
  }

  /// Crear nueva asociación
  static Future<AssociationModel?> createAssociation({
    required String name,
    required String language,
    String? description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // Obtener costo del nivel 1 desde el JSON
      final level1 = await AssociationRepository.getLevelByNumber(1);
      if (level1 == null) {
        throw Exception('No se pudo cargar la configuración de niveles');
      }

      // Restar costos del usuario
      final userRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid);

      // Verificar que tiene suficientes recursos
      final userDoc = await userRef.get();
      final userData = userDoc.data();
      final currentMoney = (userData?['dinero'] as num?)?.toDouble() ?? 0;
      final currentGems = (userData?['gemas'] as num?)?.toInt() ?? 0;

      final baseCost = level1.upgradeCost.money;
      final baseCostGems = level1.upgradeCost.gems;

      debugPrint('Usuario dinero: $currentMoney, gemas: $currentGems');
      debugPrint('Costo requerido - dinero: $baseCost, gemas: $baseCostGems');

      if (currentMoney < baseCost || currentGems < baseCostGems) {
        throw Exception(
          'Recursos insuficientes (tienes: ${currentMoney}€, necesitas: ${baseCost}€; tienes: ${currentGems}💎, necesitas: ${baseCostGems}💎)',
        );
      }

      // Crear asociación
      final association = await AssociationRepository.createAssociation(
        name: name,
        creatorId: user.uid,
        language: language,
        description: description,
      );

      // Restar dinero y gemas
      await userRef.update({
        'dinero': currentMoney - baseCost,
        'gemas': currentGems - baseCostGems,
      });

      // Agregar usuario como creador
      await AssociationRepository.client.from('association_members').insert({
        'association_id': association.id,
        'user_id': user.uid,
        'role': 'creator',
        'status': 'active',
        'joined_at': DateTime.now().toIso8601String(),
      });

      return association;
    } catch (e) {
      debugPrint('Error creating association: $e');
      return null;
    }
  }

  /// Solicitar unirse a asociación
  static Future<bool> requestToJoinAssociation(String associationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Verificar si ya existe solicitud pendiente
      final existingRequests = await AssociationRepository.client
          .from('association_requests')
          .select()
          .eq('association_id', associationId)
          .eq('user_id', user.uid)
          .eq('status', 'pending');

      if ((existingRequests as List).isNotEmpty) {
        throw Exception('Ya tienes una solicitud pendiente');
      }

      await AssociationRepository.createRequest(
        associationId: associationId,
        userId: user.uid,
      );
      return true;
    } catch (e) {
      debugPrint('Error requesting to join: $e');
      return false;
    }
  }

  /// Validar si puede actualizar nivel
  static Future<Map<String, dynamic>> canUpgradeLevel(
    String associationId,
  ) async {
    final assoc = await AssociationRepository.getAssociationById(associationId);
    if (assoc == null) {
      return {'can': false, 'reason': 'Asociación no encontrada'};
    }

    // Obtener siguiente nivel
    final nextLevel = await AssociationRepository.getLevelByNumber(
      assoc.level + 1,
    );

    if (nextLevel == null) {
      return {'can': false, 'reason': 'Ya estás en el nivel máximo'};
    }

    // Validar experiencia
    if (assoc.experiencePool < nextLevel.requiredExperience) {
      return {
        'can': false,
        'reason':
            'Experiencia insuficiente (necesitas ${nextLevel.requiredExperience})',
        'missing_experience':
            nextLevel.requiredExperience - assoc.experiencePool,
      };
    }

    // Validar dinero
    if (assoc.moneyPool < nextLevel.upgradeCost.money) {
      return {
        'can': false,
        'reason':
            'Dinero insuficiente (necesitas ${nextLevel.upgradeCost.money}€)',
        'missing_money': nextLevel.upgradeCost.money - assoc.moneyPool,
      };
    }

    // Validar gemas
    if (assoc.gemsPool < nextLevel.upgradeCost.gems) {
      return {
        'can': false,
        'reason':
            'Gemas insuficientes (necesitas ${nextLevel.upgradeCost.gems})',
        'missing_gems': nextLevel.upgradeCost.gems - assoc.gemsPool,
      };
    }

    return {'can': true, 'nextLevel': nextLevel};
  }

  /// Subir nivel
  static Future<bool> upgradeLevel(String associationId) async {
    try {
      final assoc = await AssociationRepository.getAssociationById(
        associationId,
      );
      if (assoc == null) return false;

      final validation = await canUpgradeLevel(associationId);
      if (validation['can'] != true) return false;

      await AssociationRepository.upgradeAssociationLevel(
        associationId: associationId,
        newLevel: assoc.level + 1,
      );
      return true;
    } catch (e) {
      debugPrint('Error upgrading level: $e');
      return false;
    }
  }

  /// Abandonar asociación
  static Future<bool> leaveAssociation(String associationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final members = await AssociationRepository.getAssociationMembers(
        associationId,
      );
      try {
        final member = members.firstWhere((m) => m.userId == user.uid);
        if (member.role == AssociationRole.creator) {
          throw Exception('El creador no puede abandonar la asociación');
        }

        await AssociationRepository.leaveAssociation(memberId: member.id);

        // Actualizar Firebase
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({'association_id': FieldValue.delete()});

        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      debugPrint('Error leaving association: $e');
      return false;
    }
  }

  /// Echar miembro
  static Future<bool> kickMember(String associationId, String memberId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final hasPermission = await hasPermissionToManage(
        user.uid,
        associationId,
      );
      if (!hasPermission) return false;

      final members = await AssociationRepository.getAssociationMembers(
        associationId,
      );
      try {
        final memberToKick = members.firstWhere((m) => m.id == memberId);
        if (memberToKick.role == AssociationRole.creator) {
          throw Exception('No puedes echar al creador');
        }

        await AssociationRepository.kickMember(memberId: memberId);

        // Actualizar Firebase del miembro
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(memberToKick.userId)
            .update({'association_id': FieldValue.delete()});

        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      debugPrint('Error kicking member: $e');
      return false;
    }
  }

  /// Aceptar solicitud
  static Future<bool> acceptRequest(
    String requestId,
    String userId,
    String associationId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final hasPermission = await hasPermissionToManage(
        user.uid,
        associationId,
      );
      if (!hasPermission) return false;

      await AssociationRepository.acceptRequest(
        requestId: requestId,
        userId: userId,
        associationId: associationId,
        resolvedBy: user.uid,
      );

      // Actualizar Firebase
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .update({'association_id': associationId});

      return true;
    } catch (e) {
      debugPrint('Error accepting request: $e');
      return false;
    }
  }

  /// Rechazar solicitud
  static Future<bool> rejectRequest(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await AssociationRepository.rejectRequest(
        requestId: requestId,
        resolvedBy: user.uid,
      );
      return true;
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      return false;
    }
  }
}
