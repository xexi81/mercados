import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:industrial_app/data/associations/association_level_model.dart';
import 'package:industrial_app/data/associations/association_model.dart';
import 'package:industrial_app/data/associations/association_member_model.dart';
import 'package:industrial_app/data/associations/association_request_model.dart';
import 'package:industrial_app/services/supabase_service.dart';

class AssociationRepository {
  /// Acceso al cliente Supabase
  static get client => SupabaseService.client;

  /// Cargar niveles desde el JSON
  static Future<List<AssociationLevelModel>> loadAssociationLevels() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/associations.json',
      );
      final data = json.decode(response);
      final List<dynamic> levels = data['associationLevels'];
      return levels
          .map((level) => AssociationLevelModel.fromJson(level))
          .toList();
    } catch (e) {
      debugPrint('Error loading association levels: $e');
      return [];
    }
  }

  /// Obtener un nivel específico
  static Future<AssociationLevelModel?> getLevelByNumber(int level) async {
    final levels = await loadAssociationLevels();
    try {
      return levels.firstWhere((l) => l.level == level);
    } catch (e) {
      return null;
    }
  }

  /// Crear una nueva asociación en Supabase
  static Future<AssociationModel> createAssociation({
    required String name,
    required String creatorId,
    required String language,
    String? description,
  }) async {
    final response = await SupabaseService.client
        .from('associations')
        .insert({
          'name': name,
          'creator_id': creatorId,
          'language': language,
          'description': description,
          'level': 1,
          'money_pool': 0,
          'gems_pool': 0,
          'experience_pool': 0,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return AssociationModel.fromJson(response);
  }

  /// Obtener asociación por ID
  static Future<AssociationModel?> getAssociationById(String id) async {
    try {
      final response = await SupabaseService.client
          .from('associations')
          .select()
          .eq('id', id)
          .single();
      return AssociationModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching association: $e');
      return null;
    }
  }

  /// Obtener asociación del usuario
  static Future<AssociationModel?> getUserAssociation(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('association_members')
          .select('association_id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;

      final assocId = response['association_id'] as String;
      return getAssociationById(assocId);
    } catch (e) {
      debugPrint('Error fetching user association: $e');
      return null;
    }
  }

  /// Buscar asociaciones por idioma
  static Future<List<AssociationModel>> searchAssociations({
    required String language,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('associations')
          .select()
          .eq('language', language)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((a) => AssociationModel.fromJson(a))
          .toList();
    } catch (e) {
      debugPrint('Error searching associations: $e');
      return [];
    }
  }

  /// Actualizar asociación
  static Future<void> updateAssociation(AssociationModel association) async {
    await SupabaseService.client
        .from('associations')
        .update(association.toJson())
        .eq('id', association.id);
  }

  /// Obtener miembros de una asociación
  static Future<List<AssociationMemberModel>> getAssociationMembers(
    String associationId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('association_members')
          .select()
          .eq('association_id', associationId)
          .eq('status', 'active');

      return (response as List)
          .map((m) => AssociationMemberModel.fromJson(m))
          .toList();
    } catch (e) {
      debugPrint('Error fetching association members: $e');
      return [];
    }
  }

  /// Obtener solicitudes pendientes
  static Future<List<AssociationRequestModel>> getPendingRequests(
    String associationId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('association_requests')
          .select()
          .eq('association_id', associationId)
          .eq('status', 'pending');

      return (response as List)
          .map((r) => AssociationRequestModel.fromJson(r))
          .toList();
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
      return [];
    }
  }

  /// Crear solicitud de asociación
  static Future<AssociationRequestModel> createRequest({
    required String associationId,
    required String userId,
  }) async {
    final response = await SupabaseService.client
        .from('association_requests')
        .insert({
          'association_id': associationId,
          'user_id': userId,
          'status': 'pending',
          'requested_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return AssociationRequestModel.fromJson(response);
  }

  /// Aceptar solicitud y agregar miembro
  static Future<void> acceptRequest({
    required String requestId,
    required String userId,
    required String associationId,
    required String? resolvedBy,
  }) async {
    // Actualizar solicitud
    await SupabaseService.client
        .from('association_requests')
        .update({
          'status': 'accepted',
          'resolved_at': DateTime.now().toIso8601String(),
          'resolved_by': resolvedBy,
        })
        .eq('id', requestId);

    // Agregar como miembro
    await SupabaseService.client.from('association_members').insert({
      'association_id': associationId,
      'user_id': userId,
      'role': 'member',
      'status': 'active',
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  /// Rechazar solicitud
  static Future<void> rejectRequest({
    required String requestId,
    required String? resolvedBy,
  }) async {
    await SupabaseService.client
        .from('association_requests')
        .update({
          'status': 'rejected',
          'resolved_at': DateTime.now().toIso8601String(),
          'resolved_by': resolvedBy,
        })
        .eq('id', requestId);
  }

  /// Echar miembro de la asociación
  static Future<void> kickMember({required String memberId}) async {
    await SupabaseService.client
        .from('association_members')
        .update({'status': 'kicked'})
        .eq('id', memberId);
  }

  /// Abandonar asociación
  static Future<void> leaveAssociation({required String memberId}) async {
    await SupabaseService.client
        .from('association_members')
        .update({'status': 'left'})
        .eq('id', memberId);
  }

  /// Contribuir recursos a la bolsa
  static Future<void> contributeToAssociation({
    required String associationId,
    required double money,
    required double gems,
  }) async {
    final assoc = await getAssociationById(associationId);
    if (assoc == null) return;

    await updateAssociation(
      assoc.copyWith(
        moneyPool: assoc.moneyPool + money,
        gemsPool: assoc.gemsPool + gems,
      ),
    );

    // Registrar contribución
    await SupabaseService.client.from('association_contributions').insert({
      'association_id': associationId,
      'money': money,
      'gems': gems,
      'contributed_at': DateTime.now().toIso8601String(),
    });
  }

  /// Subir nivel de asociación
  static Future<void> upgradeAssociationLevel({
    required String associationId,
    required int newLevel,
  }) async {
    final assoc = await getAssociationById(associationId);
    if (assoc == null) return;

    final levelData = await getLevelByNumber(newLevel);
    if (levelData == null) return;

    // Restar costos
    final newMoneyPool = assoc.moneyPool - levelData.upgradeCost.money;
    final newGemsPool = assoc.gemsPool - levelData.upgradeCost.gems;

    await updateAssociation(
      assoc.copyWith(
        level: newLevel,
        moneyPool: newMoneyPool,
        gemsPool: newGemsPool,
      ),
    );
  }

  /// Eliminar asociación
  static Future<void> deleteAssociation(String associationId) async {
    await SupabaseService.client
        .from('associations')
        .update({'is_active': false})
        .eq('id', associationId);
  }
}
