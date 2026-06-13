// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manifest_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ManifestMetadata _$ManifestMetadataFromJson(Map<String, dynamic> json) =>
    ManifestMetadata(
      oldVersionDirectory: json['old_version_directory'] as String,
      newVersionDirectory: json['new_version_directory'] as String,
      patchOutputDirectory: json['patch_output_directory'] as String,
      generationTime: json['generation_time'] as String,
      totalDurationSeconds: (json['total_duration_seconds'] as num).toDouble(),
      newVersionTag: json['new_version_tag'] as String,
      patchCount: (json['patch_count'] as num).toInt(),
      newFileCount: (json['new_file_count'] as num).toInt(),
      deletedFileCount: (json['deleted_file_count'] as num).toInt(),
      files: (json['files'] as List<dynamic>)
          .map((e) => FileMetadata.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ManifestMetadataToJson(ManifestMetadata instance) =>
    <String, dynamic>{
      'old_version_directory': instance.oldVersionDirectory,
      'new_version_directory': instance.newVersionDirectory,
      'patch_output_directory': instance.patchOutputDirectory,
      'generation_time': instance.generationTime,
      'total_duration_seconds': instance.totalDurationSeconds,
      'new_version_tag': instance.newVersionTag,
      'patch_count': instance.patchCount,
      'new_file_count': instance.newFileCount,
      'deleted_file_count': instance.deletedFileCount,
      'files': instance.files.map((e) => e.toJson()).toList(),
    };

FileMetadata _$FileMetadataFromJson(Map<String, dynamic> json) => FileMetadata(
  relativePath: json['relative_path'] as String,
  newFileSha256: json['new_file_sha256'] as String,
  patchFileSha256: json['patch_file_sha256'] as String,
  oldFileSizeBytes: (json['old_file_size_bytes'] as num?)?.toInt(),
  newFileSizeBytes: (json['new_file_size_bytes'] as num?)?.toInt(),
  patchFileSizeBytes: (json['patch_file_size_bytes'] as num?)?.toInt(),
  oldFileSha256: json['old_file_sha256'] as String?,
  compressionRatioPercent: (json['compression_ratio_percent'] as num?)
      ?.toDouble(),
  oldFilePath: json['old_file_path'] as String?,
  newFilePath: json['new_file_path'] as String?,
  patchFilePath: json['patch_file_path'] as String?,
  generationTime: json['generation_time'] as String?,
  newFileOnly: json['new_file_only'] as bool?,
  deletedFileOnly: json['deleted_file_only'] as bool?,
  errorMessage: json['error_message'] as String?,
);

Map<String, dynamic> _$FileMetadataToJson(FileMetadata instance) =>
    <String, dynamic>{
      'relative_path': instance.relativePath,
      'new_file_sha256': instance.newFileSha256,
      'patch_file_sha256': instance.patchFileSha256,
      'old_file_size_bytes': ?instance.oldFileSizeBytes,
      'new_file_size_bytes': ?instance.newFileSizeBytes,
      'patch_file_size_bytes': ?instance.patchFileSizeBytes,
      'old_file_sha256': ?instance.oldFileSha256,
      'compression_ratio_percent': ?instance.compressionRatioPercent,
      'old_file_path': ?instance.oldFilePath,
      'new_file_path': ?instance.newFilePath,
      'patch_file_path': ?instance.patchFilePath,
      'generation_time': ?instance.generationTime,
      'new_file_only': ?instance.newFileOnly,
      'deleted_file_only': ?instance.deletedFileOnly,
      'error_message': ?instance.errorMessage,
    };
