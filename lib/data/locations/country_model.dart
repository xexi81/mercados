class CountryModel {
  final String code;
  final String name;

  CountryModel({required this.code, required this.name});

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    return CountryModel(code: json['code'], name: json['name']);
  }

  Map<String, dynamic> toJson() => {'code': code, 'name': name};

  @override
  String toString() => 'CountryModel(code: $code, name: $name)';
}
