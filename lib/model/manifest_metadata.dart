import 'package:json_annotation/json_annotation.dart';

part 'manifest_metadata.g.dart';

@JsonSerializable(explicitToJson: true)
class ManifestMetadata {
  @JsonKey(name: 'old_version_directory')
  final String oldVersionDirectory;

  @JsonKey(name: 'new_version_directory')
  final String newVersionDirectory;

  @JsonKey(name: 'patch_output_directory')
  final String patchOutputDirectory;

  @JsonKey(name: 'generation_time')
  final String generationTime;

  @JsonKey(name: 'total_duration_seconds')
  final double totalDurationSeconds;

  @JsonKey(name: 'new_version_tag')
  final String newVersionTag;

  @JsonKey(name: 'patch_count')
  final int patchCount;

  @JsonKey(name: 'new_file_count')
  final int newFileCount;

  @JsonKey(name: 'deleted_file_count')
  final int deletedFileCount;

  @JsonKey(name: 'patch_algorithm', defaultValue: 'xdelta3')
  final String patchAlgorithm;

  final List<FileMetadata> files;

  ManifestMetadata({
    required this.oldVersionDirectory,
    required this.newVersionDirectory,
    required this.patchOutputDirectory,
    required this.generationTime,
    required this.totalDurationSeconds,
    required this.newVersionTag,
    required this.patchCount,
    required this.newFileCount,
    required this.deletedFileCount,
    this.patchAlgorithm = 'xdelta3',
    required this.files,
  });

  factory ManifestMetadata.fromJson(Map<String, dynamic> json) =>
      _$ManifestMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$ManifestMetadataToJson(this);
}

@JsonSerializable(includeIfNull: false)
class FileMetadata {
  @JsonKey(name: 'relative_path')
  final String relativePath;

  @JsonKey(name: 'new_file_sha256')
  final String newFileSha256;

  @JsonKey(name: 'patch_file_sha256')
  final String patchFileSha256;

  @JsonKey(name: 'old_file_size_bytes')
  final int? oldFileSizeBytes;

  @JsonKey(name: 'new_file_size_bytes')
  final int? newFileSizeBytes;

  @JsonKey(name: 'patch_file_size_bytes')
  final int? patchFileSizeBytes;

  @JsonKey(name: 'old_file_sha256')
  final String? oldFileSha256;

  @JsonKey(name: 'compression_ratio_percent')
  final double? compressionRatioPercent;

  @JsonKey(name: 'old_file_path')
  final String? oldFilePath;

  @JsonKey(name: 'new_file_path')
  final String? newFilePath;

  @JsonKey(name: 'patch_file_path')
  final String? patchFilePath;

  @JsonKey(name: 'generation_time')
  final String? generationTime;

  @JsonKey(name: 'new_file_only')
  final bool? newFileOnly;

  @JsonKey(name: 'deleted_file_only')
  final bool? deletedFileOnly;

  @JsonKey(name: 'error_message')
  final String? errorMessage;

  FileMetadata({
    required this.relativePath,
    required this.newFileSha256,
    required this.patchFileSha256,
    this.oldFileSizeBytes,
    this.newFileSizeBytes,
    this.patchFileSizeBytes,
    this.oldFileSha256,
    this.compressionRatioPercent,
    this.oldFilePath,
    this.newFilePath,
    this.patchFilePath,
    this.generationTime,
    this.newFileOnly,
    this.deletedFileOnly,
    this.errorMessage,
  });

  factory FileMetadata.fromJson(Map<String, dynamic> json) =>
      _$FileMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$FileMetadataToJson(this);
}
