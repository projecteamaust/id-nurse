/// Sizes, radii and spacing. Copied from design/prototype/src/index.css.
class AppSpacing {
  AppSpacing._();

  // Radii
  static const double radiusButton = 14; // .btn, inputs, alerts
  static const double radiusCard = 20; // .main-card, panels
  static const double radiusSmall = 12; // logo mark, ID card art

  // Heights
  static const double topBarHeight = 80;
  static const double buttonHeight = 56;
  static const double keypadButtonHeight = 64;
  static const double largeButtonHeight = 68;
  static const double largeButtonWidth = 300;
  static const double tabHeight = 56;
  static const double stepTrackerHeight = 48;
  static const double chipHeight = 28;

  // Widths
  static const double mainCardMaxWidth = 1184;
  static const double narrowCardMaxWidth = 720;
  static const double digitEntryMaxWidth = 430;

  // Padding and gaps
  static const double buttonPaddingX = 24;
  static const double cardPadding = 32; // .main-card
  static const double authCardPaddingX = 64; // .auth-card
  static const double authCardPaddingY = 36;
  static const double adminCardPadding = 22;
  static const double topBarPaddingX = 40;
  static const double pagePaddingX = 48; // .auth-wrap
  static const double pagePaddingY = 28;
  static const double mobileGutter = 16; // used on narrow screens (tablets)
  static const double gapXxs = 4;
  static const double gapXs = 6;
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 16;
  static const double gapXl = 20;
  static const double gapXxl = 24;
  static const double keypadGap = 10;

  // Screen width below which we use compact paddings
  static const double compactBreakpoint = 720;

  // Short screens (e.g. 1280x720 laptop, 1280x800 landscape tablet).
  // When the space below the top bar is less than this, we use the smaller sizes below
  // so the login keypad and its button fit without scrolling.
  static const double compactHeightBreakpoint = 800;
  static const double pagePaddingYShort = 8;
  static const double authCardPaddingYShort = 16;
  static const double tabHeightShort = 48;
  static const double keypadButtonHeightShort = 48; // Flutter's minimum touch target size
  static const double keypadGapShort = 6;
  static const double fieldPaddingY = 14;
  static const double fieldPaddingYShort = 8;
}
