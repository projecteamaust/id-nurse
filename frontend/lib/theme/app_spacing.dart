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
  static const double twoColGap = 36; // .two-col-entry
  static const double patientCardPadding = 24; // .patient-card
  static const double patientCardGap = 22;
  static const double avatarSize = 44; // .avatar
  static const double stepDotSize = 12; // .step i

  // Below this card width the Patient screen stacks its two columns
  static const double twoColBreakpoint = 760;
  // Below this width the patient card puts room and diagnosis on a second row
  static const double patientCardBreakpoint = 560;

  // Screen width below which we use compact paddings
  static const double compactBreakpoint = 720;

  // Keypad: buttons share the free height, up to this (minimum: AppScale.minTouchHeight)
  static const double keypadButtonMaxHeight = 96;
  static const double fieldPaddingY = 14;
  static const double scanPanelPadding = 28; // .scan-panel

  // Supplies screen (.supply-layout and friends)
  static const double categoryPanelWidth = 230;
  static const double cartPanelWidth = 320;
  static const double categoryPanelWidthNarrow = 210; // @media (max-width: 1250px)
  static const double cartPanelWidthNarrow = 290;
  static const double supplyLayoutBreakpoint = 1000; // below this window width: narrow panels
  static const double sidePanelPaddingX = 20; // .category-panel, .cart-panel
  static const double sidePanelPaddingY = 24;
  static const double supplyCenterPadding = 24; // .supply-center
  static const double supplyGridGap = 14; // .supply-grid
  static const double supplyCardMinColumnWidth = 240;
  static const double supplyCardMinHeight = 258; // .supply-card
  static const double supplyCardPadding = 18;
  static const double searchFieldHeight = 50; // .search input
  static const double categoryButtonHeight = 52; // .category-panel nav button
  static const double stepperButtonWidth = 56; // .stepper
  static const double stepperButtonHeight = 52;
  static const double cartEmptyIconSize = 50; // .cart-empty span

  // Review screen
  static const double reviewLinePaddingX = 20; // .review-list > div
  static const double reviewLinePaddingY = 10; // prototype 16; compact one-row lines so 5 fit
  static const double reviewUnitsWidth = 90; // right column with "n units" (times the text factor)
  static const double reviewSlotGap = 24; // between "Slot n" and the quantity column
  static const double reviewSlotGapMin = 16;
  // Prepare screen
  static const double stageDotSize = 28; // .working-steps i
  static const double cabinetPadding = 24; // .cabinet-wrap
  static const double cabinetInnerPadding = 8; // .cabinet
  static const double drawerGap = 6;
  static const double drawerHeight = 54; // .drawer
  static const double drawerRadius = 5;
  static const double currentActionPadding = 22; // .current-action
  static const double pulseDotSize = 14; // .pulse-dot
  static const double faultIconSize = 70; // .fault-icon
  static const double robotContentGap = 24; // .robot-content
  static const double lineStatusWidth = 120; // status chip column on the Prepare result (times the text factor)
  static const double summaryTotalGap = 30; // .summary-total
  // Collect and Complete screens
  static const double readyIconSize = 64; // .ready-icon, .complete-head > span
  static const double pickupBoxWidth = 290; // .door
  static const double pickupBoxHeight = 120;
  static const double pickupBoxBorderWidth = 5;
  static const double pickupBoxRadius = 14;
  static const double completeHeadGap = 18; // .complete-head
  static const double receiptCellPaddingX = 20; // .receipt-grid > div
  static const double receiptCellPaddingY = 16;
}
