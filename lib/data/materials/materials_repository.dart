import 'dart:convert';
import 'package:flutter/services.dart';
import 'material_model.dart';

class MaterialsRepository {
  static Future<List<MaterialModel>> loadMaterials() async {
    final String jsonString = await rootBundle.loadString(
      'assets/data/materials.json',
    );

    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

    final List materialsJson = jsonMap['materials'];

    return materialsJson.map((m) => MaterialModel.fromJson(m)).toList();
  }
}
