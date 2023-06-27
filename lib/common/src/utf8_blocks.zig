const utf8 = @import("utf8.zig");
const Codepoint = utf8.Codepoint;

pub const Utf8Block = enum {
    const Self = @This();

    const Error = error{InvalidUtf8};

    BasicLatin,
    Latin1Supplement,
    LatinExtendedA,
    LatinExtendedB,
    IpaExtensions,
    SpacingModifierLetters,
    CombiningDiacriticalMarks,
    GreekAndCoptic,
    Cyrillic,
    CyrillicSupplement,
    Armenian,
    Hebrew,
    Arabic,
    Syriac,
    ArabicSupplement,
    Thaana,
    Nko,
    Samaritan,
    Mandaic,
    SyriacSupplement,
    ArabicExtendedB,
    ArabicExtendedA,
    Devanagari,
    Bengali,
    Gurmukhi,
    Gujarati,
    Oriya,
    Tamil,
    Telugu,
    Kannada,
    Malayalam,
    Sinhala,
    Thai,
    Lao,
    Tibetan,
    Myanmar,
    Georgian,
    HangulJamo,
    Ethiopic,
    EthiopicSupplement,
    Cherokee,
    UnifiedCanadianAboriginalSyllabics,
    Ogham,
    Runic,
    Tagalog,
    Hanunoo,
    Buhid,
    Tagbanwa,
    Khmer,
    Mongolian,
    UnifiedCanadianAboriginalSyllabicsExtended,
    Limbu,
    TaiLe,
    NewTaiLue,
    KhmerSymbols,
    Buginese,
    TaiTham,
    CombiningDiacriticalMarksExtended,
    Balinese,
    Sundanese,
    Batak,
    Lepcha,
    OlChiki,
    CyrillicExtendedC,
    GeorgianExtended,
    SundaneseSupplement,
    VedicExtensions,
    PhoneticExtensions,
    PhoneticExtensionsSupplement,
    CombiningDiacriticalMarksSupplement,
    LatinExtendedAdditional,
    GreekExtended,
    GeneralPunctuation,
    SuperscriptsAndSubscripts,
    CurrencySymbols,
    CombiningDiacriticalMarksForSymbols,
    LetterlikeSymbols,
    NumberForms,
    Arrows,
    MathematicalOperators,
    MiscellaneousTechnical,
    ControlPictures,
    OpticalCharacterRecognition,
    EnclosedAlphanumerics,
    BoxDrawing,
    BlockElements,
    GeometricShapes,
    MiscellaneousSymbols,
    Dingbats,
    MiscellaneousMathematicalSymbolsA,
    SupplementalArrowsA,
    BraillePatterns,
    SupplementalArrowsB,
    MiscellaneousMathematicalSymbolsB,
    SupplementalMathematicalOperators,
    MiscellaneousSymbolsAndArrows,
    Glagolitic,
    LatinExtendedC,
    Coptic,
    GeorgianSupplement,
    Tifinagh,
    EthiopicExtended,
    CyrillicExtendedA,
    SupplementalPunctuation,
    CjkRadicalsSupplement,
    KangxiRadicals,
    IdeographicDescriptionCharacters,
    CjkSymbolsAndPunctuation,
    Hiragana,
    Katakana,
    Bopomofo,
    HangulCompatibilityJamo,
    Kanbun,
    BopomofoExtended,
    CjkStrokes,
    KatakanaPhoneticExtensions,
    EnclosedCjkLettersAndMonths,
    CjkCompatibility,
    CjkUnifiedIdeographsExtensionA,
    YijingHexagramSymbols,
    CjkUnifiedIdeographs,
    YiSyllables,
    YiRadicals,
    Lisu,
    Vai,
    CyrillicExtendedB,
    Bamum,
    ModifierToneLetters,
    LatinExtendedD,
    SylotiNagri,
    CommonIndicNumberForms,
    PhagsPa,
    Saurashtra,
    DevanagariExtended,
    KayahLi,
    Rejang,
    HangulJamoExtendedA,
    Javanese,
    MyanmarExtendedB,
    Cham,
    MyanmarExtendedA,
    TaiViet,
    MeeteiMayekExtensions,
    EthiopicExtendedA,
    LatinExtendedE,
    CherokeeSupplement,
    MeeteiMayek,
    HangulSyllables,
    HangulJamoExtendedB,
    HighSurrogates,
    HighPrivateUseSurrogates,
    LowSurrogates,
    PrivateUseArea,
    CjkCompatibilityIdeographs,
    AlphabeticPresentationForms,
    ArabicPresentationFormsA,
    VariationSelectors,
    VerticalForms,
    CombiningHalfMarks,
    CjkCompatibilityForms,
    SmallFormVariants,
    ArabicPresentationFormsB,
    HalfwidthAndFullwidthForms,
    Specials,
    LinearBSyllabary,
    LinearBIdeograms,
    AegeanNumbers,
    AncientGreekNumbers,
    AncientSymbols,
    PhaistosDisc,
    Lycian,
    Carian,
    CopticEpactNumbers,
    OldItalic,
    Gothic,
    OldPermic,
    Ugaritic,
    OldPersian,
    Deseret,
    Shavian,
    Osmanya,
    Osage,
    Elbasan,
    CaucasianAlbanian,
    Vithkuqi,
    LinearA,
    LatinExtendedF,
    CypriotSyllabary,
    ImperialAramaic,
    Palmyrene,
    Nabataean,
    Hatran,
    Phoenician,
    Lydian,
    MeroiticHieroglyphs,
    MeroiticCursive,
    Kharoshthi,
    OldSouthArabian,
    OldNorthArabian,
    Manichaean,
    Avestan,
    InscriptionalParthian,
    InscriptionalPahlavi,
    PsalterPahlavi,
    OldTurkic,
    OldHungarian,
    HanifiRohingya,
    RumiNumeralSymbols,
    Yezidi,
    ArabicExtendedC,
    OldSogdian,
    Sogdian,
    OldUyghur,
    Chorasmian,
    Elymaic,
    Brahmi,
    Kaithi,
    SoraSompeng,
    Chakma,
    Mahajani,
    Sharada,
    SinhalaArchaicNumbers,
    Khojki,
    Multani,
    Khudawadi,
    Grantha,
    Newa,
    Tirhuta,
    Siddham,
    Modi,
    MongolianSupplement,
    Takri,
    Ahom,
    Dogra,
    WarangCiti,
    DivesAkuru,
    Nandinagari,
    ZanabazarSquare,
    Soyombo,
    UnifiedCanadianAboriginalSyllabicsExtendedA,
    PauCinHau,
    DevanagariExtendedA,
    Bhaiksuki,
    Marchen,
    MasaramGondi,
    GunjalaGondi,
    Makasar,
    Kawi,
    LisuSupplement,
    TamilSupplement,
    Cuneiform,
    CuneiformNumbersAndPunctuation,
    EarlyDynasticCuneiform,
    CyproMinoan,
    EgyptianHieroglyphs,
    EgyptianHieroglyphFormatControls,
    AnatolianHieroglyphs,
    BamumSupplement,
    Mro,
    Tangsa,
    BassaVah,
    PahawhHmong,
    Medefaidrin,
    Miao,
    IdeographicSymbolsAndPunctuation,
    Tangut,
    TangutComponents,
    KhitanSmallScript,
    TangutSupplement,
    KanaExtendedB,
    KanaSupplement,
    KanaExtendedA,
    SmallKanaExtension,
    Nushu,
    Duployan,
    ShorthandFormatControls,
    ZnamennyMusicalNotation,
    ByzantineMusicalSymbols,
    MusicalSymbols,
    AncientGreekMusicalNotation,
    KaktovikNumerals,
    MayanNumerals,
    TaiXuanJingSymbols,
    CountingRodNumerals,
    MathematicalAlphanumericSymbols,
    SuttonSignwriting,
    LatinExtendedG,
    GlagoliticSupplement,
    CyrillicExtendedD,
    NyiakengPuachueHmong,
    Toto,
    Wancho,
    NagMundari,
    EthiopicExtendedB,
    MendeKikakui,
    Adlam,
    IndicSiyaqNumbers,
    OttomanSiyaqNumbers,
    ArabicMathematicalAlphabeticSymbols,
    MahjongTiles,
    DominoTiles,
    PlayingCards,
    EnclosedAlphanumericSupplement,
    EnclosedIdeographicSupplement,
    MiscellaneousSymbolsAndPictographs,
    Emoticons,
    OrnamentalDingbats,
    TransportAndMapSymbols,
    AlchemicalSymbols,
    GeometricShapesExtended,
    SupplementalArrowsC,
    SupplementalSymbolsAndPictographs,
    ChessSymbols,
    SymbolsAndPictographsExtendedA,
    SymbolsForLegacyComputing,
    CjkUnifiedIdeographsExtensionB,
    CjkUnifiedIdeographsExtensionC,
    CjkUnifiedIdeographsExtensionD,
    CjkUnifiedIdeographsExtensionE,
    CjkUnifiedIdeographsExtensionF,
    CjkCompatibilityIdeographsSupplement,
    CjkUnifiedIdeographsExtensionG,
    CjkUnifiedIdeographsExtensionH,
    Tags,
    VariationSelectorsSupplement,
    SupplementaryPrivateUseAreaA,
    SupplementaryPrivateUseAreaB,

    pub fn categorize(c: Codepoint) Error!Self {
        return switch (c.c) {
            0x0...0x7f => .BasicLatin,
            0x80...0xff => .Latin1Supplement,
            0x100...0x17f => .LatinExtendedA,
            0x180...0x24f => .LatinExtendedB,
            0x250...0x2af => .IpaExtensions,
            0x2b0...0x2ff => .SpacingModifierLetters,
            0x300...0x36f => .CombiningDiacriticalMarks,
            0x370...0x3ff => .GreekAndCoptic,
            0x400...0x4ff => .Cyrillic,
            0x500...0x52f => .CyrillicSupplement,
            0x530...0x58f => .Armenian,
            0x590...0x5ff => .Hebrew,
            0x600...0x6ff => .Arabic,
            0x700...0x74f => .Syriac,
            0x750...0x77f => .ArabicSupplement,
            0x780...0x7bf => .Thaana,
            0x7c0...0x7ff => .Nko,
            0x800...0x83f => .Samaritan,
            0x840...0x85f => .Mandaic,
            0x860...0x86f => .SyriacSupplement,
            0x870...0x89f => .ArabicExtendedB,
            0x8a0...0x8ff => .ArabicExtendedA,
            0x900...0x97f => .Devanagari,
            0x980...0x9ff => .Bengali,
            0xa00...0xa7f => .Gurmukhi,
            0xa80...0xaff => .Gujarati,
            0xb00...0xb7f => .Oriya,
            0xb80...0xbff => .Tamil,
            0xc00...0xc7f => .Telugu,
            0xc80...0xcff => .Kannada,
            0xd00...0xd7f => .Malayalam,
            0xd80...0xdff => .Sinhala,
            0xe00...0xe7f => .Thai,
            0xe80...0xeff => .Lao,
            0xf00...0xfff => .Tibetan,
            0x1000...0x109f => .Myanmar,
            0x10a0...0x10ff => .Georgian,
            0x1100...0x11ff => .HangulJamo,
            0x1200...0x137f => .Ethiopic,
            0x1380...0x139f => .EthiopicSupplement,
            0x13a0...0x13ff => .Cherokee,
            0x1400...0x167f => .UnifiedCanadianAboriginalSyllabics,
            0x1680...0x169f => .Ogham,
            0x16a0...0x16ff => .Runic,
            0x1700...0x171f => .Tagalog,
            0x1720...0x173f => .Hanunoo,
            0x1740...0x175f => .Buhid,
            0x1760...0x177f => .Tagbanwa,
            0x1780...0x17ff => .Khmer,
            0x1800...0x18af => .Mongolian,
            0x18b0...0x18ff => .UnifiedCanadianAboriginalSyllabicsExtended,
            0x1900...0x194f => .Limbu,
            0x1950...0x197f => .TaiLe,
            0x1980...0x19df => .NewTaiLue,
            0x19e0...0x19ff => .KhmerSymbols,
            0x1a00...0x1a1f => .Buginese,
            0x1a20...0x1aaf => .TaiTham,
            0x1ab0...0x1aff => .CombiningDiacriticalMarksExtended,
            0x1b00...0x1b7f => .Balinese,
            0x1b80...0x1bbf => .Sundanese,
            0x1bc0...0x1bff => .Batak,
            0x1c00...0x1c4f => .Lepcha,
            0x1c50...0x1c7f => .OlChiki,
            0x1c80...0x1c8f => .CyrillicExtendedC,
            0x1c90...0x1cbf => .GeorgianExtended,
            0x1cc0...0x1ccf => .SundaneseSupplement,
            0x1cd0...0x1cff => .VedicExtensions,
            0x1d00...0x1d7f => .PhoneticExtensions,
            0x1d80...0x1dbf => .PhoneticExtensionsSupplement,
            0x1dc0...0x1dff => .CombiningDiacriticalMarksSupplement,
            0x1e00...0x1eff => .LatinExtendedAdditional,
            0x1f00...0x1fff => .GreekExtended,
            0x2000...0x206f => .GeneralPunctuation,
            0x2070...0x209f => .SuperscriptsAndSubscripts,
            0x20a0...0x20cf => .CurrencySymbols,
            0x20d0...0x20ff => .CombiningDiacriticalMarksForSymbols,
            0x2100...0x214f => .LetterlikeSymbols,
            0x2150...0x218f => .NumberForms,
            0x2190...0x21ff => .Arrows,
            0x2200...0x22ff => .MathematicalOperators,
            0x2300...0x23ff => .MiscellaneousTechnical,
            0x2400...0x243f => .ControlPictures,
            0x2440...0x245f => .OpticalCharacterRecognition,
            0x2460...0x24ff => .EnclosedAlphanumerics,
            0x2500...0x257f => .BoxDrawing,
            0x2580...0x259f => .BlockElements,
            0x25a0...0x25ff => .GeometricShapes,
            0x2600...0x26ff => .MiscellaneousSymbols,
            0x2700...0x27bf => .Dingbats,
            0x27c0...0x27ef => .MiscellaneousMathematicalSymbolsA,
            0x27f0...0x27ff => .SupplementalArrowsA,
            0x2800...0x28ff => .BraillePatterns,
            0x2900...0x297f => .SupplementalArrowsB,
            0x2980...0x29ff => .MiscellaneousMathematicalSymbolsB,
            0x2a00...0x2aff => .SupplementalMathematicalOperators,
            0x2b00...0x2bff => .MiscellaneousSymbolsAndArrows,
            0x2c00...0x2c5f => .Glagolitic,
            0x2c60...0x2c7f => .LatinExtendedC,
            0x2c80...0x2cff => .Coptic,
            0x2d00...0x2d2f => .GeorgianSupplement,
            0x2d30...0x2d7f => .Tifinagh,
            0x2d80...0x2ddf => .EthiopicExtended,
            0x2de0...0x2dff => .CyrillicExtendedA,
            0x2e00...0x2e7f => .SupplementalPunctuation,
            0x2e80...0x2eff => .CjkRadicalsSupplement,
            0x2f00...0x2fdf => .KangxiRadicals,
            0x2ff0...0x2fff => .IdeographicDescriptionCharacters,
            0x3000...0x303f => .CjkSymbolsAndPunctuation,
            0x3040...0x309f => .Hiragana,
            0x30a0...0x30ff => .Katakana,
            0x3100...0x312f => .Bopomofo,
            0x3130...0x318f => .HangulCompatibilityJamo,
            0x3190...0x319f => .Kanbun,
            0x31a0...0x31bf => .BopomofoExtended,
            0x31c0...0x31ef => .CjkStrokes,
            0x31f0...0x31ff => .KatakanaPhoneticExtensions,
            0x3200...0x32ff => .EnclosedCjkLettersAndMonths,
            0x3300...0x33ff => .CjkCompatibility,
            0x3400...0x4dbf => .CjkUnifiedIdeographsExtensionA,
            0x4dc0...0x4dff => .YijingHexagramSymbols,
            0x4e00...0x9fff => .CjkUnifiedIdeographs,
            0xa000...0xa48f => .YiSyllables,
            0xa490...0xa4cf => .YiRadicals,
            0xa4d0...0xa4ff => .Lisu,
            0xa500...0xa63f => .Vai,
            0xa640...0xa69f => .CyrillicExtendedB,
            0xa6a0...0xa6ff => .Bamum,
            0xa700...0xa71f => .ModifierToneLetters,
            0xa720...0xa7ff => .LatinExtendedD,
            0xa800...0xa82f => .SylotiNagri,
            0xa830...0xa83f => .CommonIndicNumberForms,
            0xa840...0xa87f => .PhagsPa,
            0xa880...0xa8df => .Saurashtra,
            0xa8e0...0xa8ff => .DevanagariExtended,
            0xa900...0xa92f => .KayahLi,
            0xa930...0xa95f => .Rejang,
            0xa960...0xa97f => .HangulJamoExtendedA,
            0xa980...0xa9df => .Javanese,
            0xa9e0...0xa9ff => .MyanmarExtendedB,
            0xaa00...0xaa5f => .Cham,
            0xaa60...0xaa7f => .MyanmarExtendedA,
            0xaa80...0xaadf => .TaiViet,
            0xaae0...0xaaff => .MeeteiMayekExtensions,
            0xab00...0xab2f => .EthiopicExtendedA,
            0xab30...0xab6f => .LatinExtendedE,
            0xab70...0xabbf => .CherokeeSupplement,
            0xabc0...0xabff => .MeeteiMayek,
            0xac00...0xd7af => .HangulSyllables,
            0xd7b0...0xd7ff => .HangulJamoExtendedB,
            0xd800...0xdb7f => .HighSurrogates,
            0xdb80...0xdbff => .HighPrivateUseSurrogates,
            0xdc00...0xdfff => .LowSurrogates,
            0xe000...0xf8ff => .PrivateUseArea,
            0xf900...0xfaff => .CjkCompatibilityIdeographs,
            0xfb00...0xfb4f => .AlphabeticPresentationForms,
            0xfb50...0xfdff => .ArabicPresentationFormsA,
            0xfe00...0xfe0f => .VariationSelectors,
            0xfe10...0xfe1f => .VerticalForms,
            0xfe20...0xfe2f => .CombiningHalfMarks,
            0xfe30...0xfe4f => .CjkCompatibilityForms,
            0xfe50...0xfe6f => .SmallFormVariants,
            0xfe70...0xfeff => .ArabicPresentationFormsB,
            0xff00...0xffef => .HalfwidthAndFullwidthForms,
            0xfff0...0xffff => .Specials,
            0x10000...0x1007f => .LinearBSyllabary,
            0x10080...0x100ff => .LinearBIdeograms,
            0x10100...0x1013f => .AegeanNumbers,
            0x10140...0x1018f => .AncientGreekNumbers,
            0x10190...0x101cf => .AncientSymbols,
            0x101d0...0x101ff => .PhaistosDisc,
            0x10280...0x1029f => .Lycian,
            0x102a0...0x102df => .Carian,
            0x102e0...0x102ff => .CopticEpactNumbers,
            0x10300...0x1032f => .OldItalic,
            0x10330...0x1034f => .Gothic,
            0x10350...0x1037f => .OldPermic,
            0x10380...0x1039f => .Ugaritic,
            0x103a0...0x103df => .OldPersian,
            0x10400...0x1044f => .Deseret,
            0x10450...0x1047f => .Shavian,
            0x10480...0x104af => .Osmanya,
            0x104b0...0x104ff => .Osage,
            0x10500...0x1052f => .Elbasan,
            0x10530...0x1056f => .CaucasianAlbanian,
            0x10570...0x105bf => .Vithkuqi,
            0x10600...0x1077f => .LinearA,
            0x10780...0x107bf => .LatinExtendedF,
            0x10800...0x1083f => .CypriotSyllabary,
            0x10840...0x1085f => .ImperialAramaic,
            0x10860...0x1087f => .Palmyrene,
            0x10880...0x108af => .Nabataean,
            0x108e0...0x108ff => .Hatran,
            0x10900...0x1091f => .Phoenician,
            0x10920...0x1093f => .Lydian,
            0x10980...0x1099f => .MeroiticHieroglyphs,
            0x109a0...0x109ff => .MeroiticCursive,
            0x10a00...0x10a5f => .Kharoshthi,
            0x10a60...0x10a7f => .OldSouthArabian,
            0x10a80...0x10a9f => .OldNorthArabian,
            0x10ac0...0x10aff => .Manichaean,
            0x10b00...0x10b3f => .Avestan,
            0x10b40...0x10b5f => .InscriptionalParthian,
            0x10b60...0x10b7f => .InscriptionalPahlavi,
            0x10b80...0x10baf => .PsalterPahlavi,
            0x10c00...0x10c4f => .OldTurkic,
            0x10c80...0x10cff => .OldHungarian,
            0x10d00...0x10d3f => .HanifiRohingya,
            0x10e60...0x10e7f => .RumiNumeralSymbols,
            0x10e80...0x10ebf => .Yezidi,
            0x10ec0...0x10eff => .ArabicExtendedC,
            0x10f00...0x10f2f => .OldSogdian,
            0x10f30...0x10f6f => .Sogdian,
            0x10f70...0x10faf => .OldUyghur,
            0x10fb0...0x10fdf => .Chorasmian,
            0x10fe0...0x10fff => .Elymaic,
            0x11000...0x1107f => .Brahmi,
            0x11080...0x110cf => .Kaithi,
            0x110d0...0x110ff => .SoraSompeng,
            0x11100...0x1114f => .Chakma,
            0x11150...0x1117f => .Mahajani,
            0x11180...0x111df => .Sharada,
            0x111e0...0x111ff => .SinhalaArchaicNumbers,
            0x11200...0x1124f => .Khojki,
            0x11280...0x112af => .Multani,
            0x112b0...0x112ff => .Khudawadi,
            0x11300...0x1137f => .Grantha,
            0x11400...0x1147f => .Newa,
            0x11480...0x114df => .Tirhuta,
            0x11580...0x115ff => .Siddham,
            0x11600...0x1165f => .Modi,
            0x11660...0x1167f => .MongolianSupplement,
            0x11680...0x116cf => .Takri,
            0x11700...0x1174f => .Ahom,
            0x11800...0x1184f => .Dogra,
            0x118a0...0x118ff => .WarangCiti,
            0x11900...0x1195f => .DivesAkuru,
            0x119a0...0x119ff => .Nandinagari,
            0x11a00...0x11a4f => .ZanabazarSquare,
            0x11a50...0x11aaf => .Soyombo,
            0x11ab0...0x11abf => .UnifiedCanadianAboriginalSyllabicsExtendedA,
            0x11ac0...0x11aff => .PauCinHau,
            0x11b00...0x11b5f => .DevanagariExtendedA,
            0x11c00...0x11c6f => .Bhaiksuki,
            0x11c70...0x11cbf => .Marchen,
            0x11d00...0x11d5f => .MasaramGondi,
            0x11d60...0x11daf => .GunjalaGondi,
            0x11ee0...0x11eff => .Makasar,
            0x11f00...0x11f5f => .Kawi,
            0x11fb0...0x11fbf => .LisuSupplement,
            0x11fc0...0x11fff => .TamilSupplement,
            0x12000...0x123ff => .Cuneiform,
            0x12400...0x1247f => .CuneiformNumbersAndPunctuation,
            0x12480...0x1254f => .EarlyDynasticCuneiform,
            0x12f90...0x12fff => .CyproMinoan,
            0x13000...0x1342f => .EgyptianHieroglyphs,
            0x13430...0x1345f => .EgyptianHieroglyphFormatControls,
            0x14400...0x1467f => .AnatolianHieroglyphs,
            0x16800...0x16a3f => .BamumSupplement,
            0x16a40...0x16a6f => .Mro,
            0x16a70...0x16acf => .Tangsa,
            0x16ad0...0x16aff => .BassaVah,
            0x16b00...0x16b8f => .PahawhHmong,
            0x16e40...0x16e9f => .Medefaidrin,
            0x16f00...0x16f9f => .Miao,
            0x16fe0...0x16fff => .IdeographicSymbolsAndPunctuation,
            0x17000...0x187ff => .Tangut,
            0x18800...0x18aff => .TangutComponents,
            0x18b00...0x18cff => .KhitanSmallScript,
            0x18d00...0x18d7f => .TangutSupplement,
            0x1aff0...0x1afff => .KanaExtendedB,
            0x1b000...0x1b0ff => .KanaSupplement,
            0x1b100...0x1b12f => .KanaExtendedA,
            0x1b130...0x1b16f => .SmallKanaExtension,
            0x1b170...0x1b2ff => .Nushu,
            0x1bc00...0x1bc9f => .Duployan,
            0x1bca0...0x1bcaf => .ShorthandFormatControls,
            0x1cf00...0x1cfcf => .ZnamennyMusicalNotation,
            0x1d000...0x1d0ff => .ByzantineMusicalSymbols,
            0x1d100...0x1d1ff => .MusicalSymbols,
            0x1d200...0x1d24f => .AncientGreekMusicalNotation,
            0x1d2c0...0x1d2df => .KaktovikNumerals,
            0x1d2e0...0x1d2ff => .MayanNumerals,
            0x1d300...0x1d35f => .TaiXuanJingSymbols,
            0x1d360...0x1d37f => .CountingRodNumerals,
            0x1d400...0x1d7ff => .MathematicalAlphanumericSymbols,
            0x1d800...0x1daaf => .SuttonSignwriting,
            0x1df00...0x1dfff => .LatinExtendedG,
            0x1e000...0x1e02f => .GlagoliticSupplement,
            0x1e030...0x1e08f => .CyrillicExtendedD,
            0x1e100...0x1e14f => .NyiakengPuachueHmong,
            0x1e290...0x1e2bf => .Toto,
            0x1e2c0...0x1e2ff => .Wancho,
            0x1e4d0...0x1e4ff => .NagMundari,
            0x1e7e0...0x1e7ff => .EthiopicExtendedB,
            0x1e800...0x1e8df => .MendeKikakui,
            0x1e900...0x1e95f => .Adlam,
            0x1ec70...0x1ecbf => .IndicSiyaqNumbers,
            0x1ed00...0x1ed4f => .OttomanSiyaqNumbers,
            0x1ee00...0x1eeff => .ArabicMathematicalAlphabeticSymbols,
            0x1f000...0x1f02f => .MahjongTiles,
            0x1f030...0x1f09f => .DominoTiles,
            0x1f0a0...0x1f0ff => .PlayingCards,
            0x1f100...0x1f1ff => .EnclosedAlphanumericSupplement,
            0x1f200...0x1f2ff => .EnclosedIdeographicSupplement,
            0x1f300...0x1f5ff => .MiscellaneousSymbolsAndPictographs,
            0x1f600...0x1f64f => .Emoticons,
            0x1f650...0x1f67f => .OrnamentalDingbats,
            0x1f680...0x1f6ff => .TransportAndMapSymbols,
            0x1f700...0x1f77f => .AlchemicalSymbols,
            0x1f780...0x1f7ff => .GeometricShapesExtended,
            0x1f800...0x1f8ff => .SupplementalArrowsC,
            0x1f900...0x1f9ff => .SupplementalSymbolsAndPictographs,
            0x1fa00...0x1fa6f => .ChessSymbols,
            0x1fa70...0x1faff => .SymbolsAndPictographsExtendedA,
            0x1fb00...0x1fbff => .SymbolsForLegacyComputing,
            0x20000...0x2a6df => .CjkUnifiedIdeographsExtensionB,
            0x2a700...0x2b73f => .CjkUnifiedIdeographsExtensionC,
            0x2b740...0x2b81f => .CjkUnifiedIdeographsExtensionD,
            0x2b820...0x2ceaf => .CjkUnifiedIdeographsExtensionE,
            0x2ceb0...0x2ebef => .CjkUnifiedIdeographsExtensionF,
            0x2f800...0x2fa1f => .CjkCompatibilityIdeographsSupplement,
            0x30000...0x3134f => .CjkUnifiedIdeographsExtensionG,
            0x31350...0x323af => .CjkUnifiedIdeographsExtensionH,
            0xe0000...0xe007f => .Tags,
            0xe0100...0xe01ef => .VariationSelectorsSupplement,
            0xf0000...0xfffff => .SupplementaryPrivateUseAreaA,
            0x100000...0x10ffff => .SupplementaryPrivateUseAreaB,
            else => Error.InvalidUtf8,
        };
    }
};