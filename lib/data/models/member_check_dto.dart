class MemberCheckDto {
  final bool available;

  const MemberCheckDto({required this.available});

  factory MemberCheckDto.fromJson(Map<String, dynamic> json) {
    return MemberCheckDto(
      available: json['available'] as bool? ?? false,
    );
  }
}
