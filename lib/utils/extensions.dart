/*
Copyright 2021 The dahliaOS Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:dahlia_shared/services/customization.dart';
import 'package:dahlia_shared/utils/resource.dart';
import 'package:flutter/material.dart';

extension ColorsX on Color {
  Color op(double opacity) {
    return withOpacity(opacity);
  }
}

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get mSize => mediaQuery.size;
  EdgeInsets get padding => mediaQuery.padding;
  EdgeInsets get viewInsets => mediaQuery.viewInsets;
  EdgeInsets get viewPadding => mediaQuery.viewPadding;
  EdgeInsetsDirectional get viewPaddingDirectional {
    switch (directionality) {
      case TextDirection.ltr:
        return EdgeInsetsDirectional.fromSTEB(
          viewPadding.left,
          viewPadding.top,
          viewPadding.right,
          viewPadding.bottom,
        );
      case TextDirection.rtl:
        return EdgeInsetsDirectional.fromSTEB(
          viewPadding.right,
          viewPadding.top,
          viewPadding.left,
          viewPadding.bottom,
        );
    }
  }

  TextDirection get directionality => Directionality.of(this);

  NavigatorState get navigator => Navigator.of(this);
  void pop<T extends Object?>([T? result]) => navigator.pop<T?>(result);
  Future<T?> push<T extends Object?>(Route<T> route) => navigator.push<T?>(route);

  ScaffoldMessengerState get scaffoldMessenger => ScaffoldMessenger.of(this);

  FocusScopeNode get focusScope => FocusScope.of(this);

  OverlayState? get overlay => Overlay.of(this);
}

mixin ThemeConstants {
  static EdgeInsets get buttonPadding => const EdgeInsets.symmetric(horizontal: 4, vertical: 10);
}

extension ResourcePointerUtils on String {
  Resource toResource() {
    return Resource.parse(this);
  }

  Color? toColor() {
    final Resource resource;

    try {
      resource = toResource();
    } catch (e) {
      return null;
    }

    if (resource is! ColorResource) return null;

    return resource.resolve();
  }
}

extension CustomizationServiceX on CustomizationService {
  void addRecentWallpaper(ImageResource wallpaper) {
    recentWallpapers = [...recentWallpapers, wallpaper];
  }

  void togglePinnedApp(String packageName) {
    if (pinnedApps.contains(packageName)) {
      pinnedApps = List.from(pinnedApps)..remove(packageName);
    } else {
      pinnedApps = List.from(pinnedApps)..add(packageName);
    }
  }
}
