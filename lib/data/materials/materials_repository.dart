import 'dart:convert';
import 'package:flutter/services.dart';
import 'material_model.dart';

class MaterialsRepository {
  static List<MaterialModel>? _materials;

  static Future<List<MaterialModel>> loadMaterials() async {
    if (_materials != null) return _materials!;

    final String jsonString = await rootBundle.loadString(
      'assets/data/materials.json',
    );

    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

    final List materialsJson = jsonMap['materials'];

    _materials = materialsJson.map((m) => MaterialModel.fromJson(m)).toList();
    return _materials!;
  }

  static Future<MaterialModel?> getMaterialById(int id) async {
    final materials = await loadMaterials();
    return materials.where((m) => m.id == id).firstOrNull;
  }
}
