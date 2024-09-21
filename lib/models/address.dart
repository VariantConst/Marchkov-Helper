class Address {
  final String campusName;
  final String buildName;
  final String detailedAddress;

  Address({
    required this.campusName,
    required this.buildName,
    required this.detailedAddress,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      campusName: json['campus_name'] ?? '',
      buildName: json['build_name'] ?? '',
      detailedAddress: json['detailed_address'] ?? '',
    );
  }
}
