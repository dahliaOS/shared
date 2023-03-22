import 'dart:ui' as ui show Color;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:dahlia_shared/utils/constants.dart';

sealed class Resource<T extends Enum, V> {
  static final RegExp _syntaxRegex =
      RegExp(r"^(?<type>[a-zA-Z]+):(?<subtype>[a-zA-Z]+)#(?<value>.+)$");

  final ResourceType type;
  final T subtype;
  final String value;

  const Resource._(this.type, this.subtype, this.value);

  static Resource? tryParse(String input) {
    final RegExpMatch? match = _syntaxRegex.firstMatch(input);

    if (match == null) return null;

    final String type = match.namedGroup("type")!;
    final String subtypeStr = match.namedGroup("subtype")!;
    final String value = match.namedGroup("value")!;

    switch (type) {
      case "image":
        final ImageResourceType? subtype = ImageResourceType.values
            .firstWhereOrNull((e) => e.name == subtypeStr);

        if (subtype != null) {
          return ImageResource(type: subtype, value: value);
        }

        break;
      case "icon":
        final IconResourceType? subtype = IconResourceType.values
            .firstWhereOrNull((e) => e.name == subtypeStr);

        if (subtype != null) {
          return IconResource(type: subtype, value: value);
        }

        break;
      case "color":
        final ColorResourceType? subtype = ColorResourceType.values
            .firstWhereOrNull((e) => e.name == subtypeStr);

        if (subtype != null) {
          return ColorResource(type: subtype, value: value);
        }

        break;
    }

    return null;
  }

  static Resource parse(String input) {
    final Resource? result = tryParse(input);

    if (result == null) {
      throw FormatException("Invalid format for resource pointer", input);
    }

    return result;
  }

  V resolve();

  @override
  String toString() {
    return "${type.name}:${subtype.name}#$value";
  }

  @override
  bool operator ==(Object? other) {
    if (other is Resource) {
      return type == other.type &&
          subtype == other.subtype &&
          value == other.value;
    }

    return false;
  }

  @override
  int get hashCode => Object.hash(type, subtype, value);
}

class ImageResource extends Resource<ImageResourceType, String> {
  const ImageResource({
    required ImageResourceType type,
    required String value,
  }) : super._(ResourceType.image, type, value);

  static ImageResource parse(String input) {
    final Resource? result = Resource.tryParse(input);

    if (result == null || result is! ImageResource) {
      throw FormatException("Invalid format for image resource pointer", input);
    }

    return result;
  }

  @override
  String resolve() {
    switch (subtype) {
      case ImageResourceType.dahlia:
        return "assets/$value";
      case ImageResourceType.file:
      case ImageResourceType.network:
        return value;
    }
  }
}

class IconResource extends Resource<IconResourceType, IconReference> {
  const IconResource({
    required IconResourceType type,
    required String value,
  }) : super._(ResourceType.icon, type, value);

  @override
  IconReference resolve({
    int? size,
    String? directory,
    String? fallback,
  }) {
    switch (subtype) {
      case IconResourceType.dahlia:
        return DahliaIconReference(value);
      case IconResourceType.xdg:
        if (value.startsWith("/")) return FileIconReference(value);

        if (directory != null && directory.isNotEmpty) {
          return XdgIconReference(
            value,
            directory: directory,
            fallback: fallback,
          );
        }

        return XdgIconReference(value, size: size, fallback: fallback);
    }
  }
}

sealed class IconReference {
  final String name;

  const IconReference(this.name);
}

class DahliaIconReference extends IconReference {
  const DahliaIconReference(super.name);
}

class FileIconReference extends IconReference {
  const FileIconReference(super.name);

  Uri get uri => Uri.file(name);
}

class XdgIconReference extends IconReference {
  final String? directory;
  final String? fallback;
  final int? size;

  const XdgIconReference(
    super.name, {
    this.directory,
    this.fallback,
    this.size,
  });
}

class ColorResource extends Resource<ColorResourceType, ui.Color?> {
  const ColorResource({
    required ColorResourceType type,
    required String value,
  }) : super._(ResourceType.color, type, value);

  @override
  ui.Color? resolve() {
    switch (subtype) {
      case ColorResourceType.dahlia:
        return BuiltinColor.getFromName(value)?.value;
      case ColorResourceType.material:
        final List<String> parts = value.split("/");
        if (value.isEmpty || parts.isEmpty || parts.length > 2) return null;

        final MaterialColor? basePalette =
            Constants.materialColors[parts.first];

        if (basePalette == null) return null;

        final int? shade = parts.length > 1 ? int.tryParse(parts[1]) : null;
        final Color? color = shade != null ? basePalette[shade] : basePalette;

        return color;
      case ColorResourceType.hex:
        if (value.length != 6 && value.length != 8) return null;

        int? parsed = int.tryParse(value, radix: 16);
        if (parsed == null) return null;

        if (value.length == 6) {
          parsed |= 0xff << 24;
        }

        return ui.Color(parsed);
    }
  }
}

enum ResourceType {
  image,
  icon,
  color,
}

enum ImageResourceType {
  dahlia,
  file,
  network,
}

enum IconResourceType {
  dahlia,
  xdg,
}

enum ColorResourceType {
  dahlia,
  material,
  hex,
}
