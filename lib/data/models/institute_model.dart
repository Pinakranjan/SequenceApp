/// Institute model representing an educational institution
class Institute {
  final int id;
  final String instName;
  final String address;
  final String district;
  final String courseType;

  Institute({
    required this.id,
    required this.instName,
    required this.address,
    required this.district,
    required this.courseType,
  });

  /// Factory constructor to create Institute from JSON
  factory Institute.fromJson(Map<String, dynamic> json, String courseType) {
    final rawId = json['id'];
    return Institute(
      id: int.tryParse(rawId?.toString() ?? '') ?? 0,
      instName: json['inst_name'] ?? '',
      address: json['address'] ?? '',
      district: json['district'] ?? '',
      courseType: courseType,
    );
  }

  /// Convert Institute to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inst_name': instName,
      'address': address,
      'district': district,
      'course_type': courseType,
    };
  }
}

/// Course type enum for filtering institutes
enum CourseType {
  btech(
    'btech',
    'BTECH',
    'Bachelor of Technology',
    'assets/images/courses/btech.jpg',
  ),
  mtech(
    'mtech',
    'MTECH',
    'Master of Technology',
    'assets/images/courses/mtech.jpg',
  ),
  mba(
    'mba',
    'MBA',
    'Master of Business Administration',
    'assets/images/courses/mba.jpg',
  ),
  mca(
    'mca',
    'MCA',
    'Master of Computer Applications',
    'assets/images/courses/mca.jpg',
  ),
  bamsBhms(
    'bams-bhms',
    'BAMS-BHMS',
    'Ayurveda & Homeopathy',
    'assets/images/courses/bams_bhms.jpg',
  ),
  medical(
    'medical',
    'MEDICAL',
    'Medical Sciences',
    'assets/images/courses/medical.jpg',
  ),
  pharmacy(
    'pharmacy',
    'PHARMACY',
    'Pharmaceutical Sciences',
    'assets/images/courses/pharmacy.jpg',
  ),
  barch(
    'barch',
    'BARCH',
    'Bachelor of Architecture',
    'assets/images/courses/barch.jpg',
  );

  final String key;
  final String title;
  final String fullName;
  final String imagePath;

  const CourseType(this.key, this.title, this.fullName, this.imagePath);

  /// Get CourseType from string key
  static CourseType? fromKey(String key) {
    final normalized = key
        .trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll('/', '-')
        .replaceAll('.', '-')
        .replaceAll(' ', '-');

    // Also compare a compact form (remove separators) to be resilient to
    // variants like "m-tech" vs "mtech".
    final compact = normalized.replaceAll('-', '');

    for (final value in CourseType.values) {
      final valueKey = value.key.toLowerCase();
      final valueTitle = value.title.toLowerCase();

      final valueKeyCompact = valueKey
          .replaceAll('-', '')
          .replaceAll('.', '')
          .replaceAll(' ', '');
      final valueTitleCompact = valueTitle
          .replaceAll('-', '')
          .replaceAll('.', '')
          .replaceAll(' ', '');

      if (valueKey == normalized || valueTitle == normalized) {
        return value;
      }

      if (valueKeyCompact == compact || valueTitleCompact == compact) {
        return value;
      }

      // Handle common variants like BAMS/BHMS.
      final normalizedTitle = valueTitle
          .replaceAll('_', '-')
          .replaceAll('/', '-')
          .replaceAll('.', '-')
          .replaceAll(' ', '-');
      if (normalizedTitle == normalized) {
        return value;
      }
    }

    return null;
  }
}
