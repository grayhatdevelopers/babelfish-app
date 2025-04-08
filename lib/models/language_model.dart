import 'package:flutter/material.dart';

LanguageModel currentLanguage = LanguageModel(
  name: "English",
  code: "en",
  downText: "Swipe down to translate to English",
  upText: "Swipe up to translate to English",
  flagOrientation: FlagOrientation.vertical,
  colors: [Colors.blue, Colors.red, Colors.blue],
);

class Languages {
  // list of all languages supported by omni
  static Map<String, LanguageModel> languages = {
    "en": LanguageModel(
      name: "English",
      code: "en",
      downText: "Swipe down to translate to English",
      upText: "Swipe up to translate to English",
      flagOrientation: FlagOrientation.vertical,
      colors: [Colors.blue, Colors.red, Colors.white],
    ),
    "es": LanguageModel(
      name: "Español",
      code: "es",
      downText: "Desliza hacia abajo para traducir Español",
      upText: "Desliza hacia arriba para traducir Español",
      flagOrientation: FlagOrientation.vertical,
      colors: [Colors.red, Colors.yellow, Colors.red],
    ),
    "fr": LanguageModel(
      name: "Français",
      code: "fr",
      downText: "Glissez vers le bas pour traduire en Français",
      upText: "Balayez vers le haut pour traduire en Français",
      flagOrientation: FlagOrientation.vertical,
      colors: [Colors.blue, Colors.white, Colors.white, Colors.red],
    ),
    "de": LanguageModel(
      name: "Deutsch",
      code: "de",
      downText: "Nach unten wischen, um auf Deutsch zu übersetzen",
      upText: "Nach oben wischen, um auf Deutsch zu übersetzen",
      flagOrientation: FlagOrientation.horizontal,
      colors: [Colors.grey, Colors.red, Colors.yellow],
    ),
    "it": LanguageModel(
      name: "Italiano",
      code: "it",
      downText: "Scorri verso il basso per tradurre in Italiano",
      upText: "Scorri verso l'alto per tradurre in Italiano",
      flagOrientation: FlagOrientation.horizontal,
      colors: [Colors.green, Colors.white, Colors.red],
    ),
    "pt": LanguageModel(
      name: "Português",
      code: "pt",
      downText: "Deslize para baixo para traduzir para Português",
      upText: "Deslize para cima para traduzir para Português",
      flagOrientation: FlagOrientation.vertical,
      colors: [Colors.green, Colors.green, Colors.green, Colors.red],
    ),
    "pl": LanguageModel(
      name: "Polski",
      code: "pl",
      downText: "Przesuń w dół, aby przetłumaczyć na Polski",
      upText: "Przesuń w górę, aby przetłumaczyć na Polski",
      flagOrientation: FlagOrientation.horizontal,
      colors: [Colors.white, Colors.red],
    ),
    "tr": LanguageModel(
      name: "Türkçe",
      code: "tr",
      downText: "Türkçeye çevirmek için aşağı kaydırın",
      upText: "Türkçeye çevirmek için yukarı kaydırın",
      flagOrientation: FlagOrientation.horizontal,
      colors: [Colors.red, Colors.white],
    ),
    "ru": LanguageModel(
      name: "Русский",
      code: "ru",
      downText: "Проведите вниз, чтобы перевести на Русский",
      upText: "Проведите вверх, чтобы перевести на Русский",
      flagOrientation: FlagOrientation.vertical,
      colors: [Colors.white, Colors.blue, Colors.red],
    ),
    "nl": LanguageModel(
      name: "Nederlands",
      code: "nl",
      downText: "Veeg omlaag om naar het Nederlands te vertalen",
      upText: "Veeg omhoog om naar het Nederlands te vertalen",
      flagOrientation: FlagOrientation.horizontal,
      colors: [Colors.red, Colors.white, Colors.blue],
    ),
    "cs": LanguageModel(
      name: "Čeština",
      code: "cs",
      downText: "Přejeďte dolů pro překlad do Češtiny",
      upText: "Přejeďte nahoru pro překlad do Češtiny",
      flagOrientation: FlagOrientation.vertical,
      colors: [Colors.white, Colors.red, Colors.blue],
    ),
    "ar": LanguageModel(
      name: "العربية",
      code: "ar",
      downText: "اسحب لأسفل للترجمة إلى العربية",
      upText: "اسحب لأعلى للترجمة إلى العربية",
      flagOrientation: FlagOrientation.horizontal,
      colors: [Colors.grey, Colors.white, Colors.green, Colors.red],
    ),
    "zh-cn": LanguageModel(
      name: "中文 (简体)",
      code: "zh-cn",
      downText: "下滑以翻译为中文（简体）",
      upText: "上滑以翻译为中文（简体）",
      flagOrientation: FlagOrientation.circle,
      colors: [Colors.red, Colors.yellow],
    ),
    "hu": LanguageModel(
      name: "Magyar",
      code: "hu",
      downText: "Húzza le a fordításhoz Magyarra",
      upText: "Húzza fel a fordításhoz Magyarra",
      flagOrientation: FlagOrientation.vertical,
      colors: [Colors.red, Colors.white, Colors.green],
    ),
    "ko": LanguageModel(
      name: "한국어",
      code: "ko",
      downText: "한국어로 번역하려면 아래로 스와이프하세요",
      upText: "한국어로 번역하려면 위로 스와이프하세요",
      flagOrientation: FlagOrientation.circle,
      colors: [Colors.red, Colors.blue, Colors.white],
    ),
    "ja": LanguageModel(
      name: "日本語",
      code: "ja",
      downText: "日本語に翻訳するには下にスワイプしてください",
      upText: "日本語に翻訳するには上にスワイプしてください",
      flagOrientation: FlagOrientation.circle,
      colors: [Colors.red, Colors.white],
    ),
  };
}

// a language
class LanguageModel {
  final String id = UniqueKey().toString();
  final String name;
  final String code;
  final String downText;
  final String upText;
  final FlagOrientation flagOrientation;
  final List<Color> colors;

  LanguageModel({
    required this.name,
    required this.code,
    required this.downText,
    required this.upText,
    required this.flagOrientation,
    required this.colors,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanguageModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum FlagOrientation { vertical, horizontal, circle }
