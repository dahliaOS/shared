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
import 'package:dahlia_shared/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:zenit_ui/zenit_ui.dart';

ThemeData get dahliaLightTheme {
  final CustomizationService customization = CustomizationService.current;
  final Color accentColor = customization.accentColor.resolve() ?? BuiltinColor.orange.value;
  return ThemeEngine.create(
    variant: ThemeVariant.light,
    primaryColor: accentColor,
    backgroundColor: const Color(0xFFFAFAFA),
    surfaceColor: const Color(0xFFE5E5E7),
    cardColor: const Color(0xFFFFFFFF),
    textColor: Colors.black,
  );
}

ThemeData get dahliaDarkTheme {
  final CustomizationService customization = CustomizationService.current;
  final Color accentColor = customization.accentColor.resolve() ?? BuiltinColor.orange.value;
  return ThemeEngine.create(
    variant: ThemeVariant.dark,
    primaryColor: accentColor,
    backgroundColor: const Color(0xFF1C1C1E),
    surfaceColor: const Color(0xFF353535),
    cardColor: const Color(0xFF252528),
    textColor: Colors.white,
  );
}
