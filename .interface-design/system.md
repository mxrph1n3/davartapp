# Davart Design System

## Direction
Personality: Calm retail / interior studio
Foundation: Neutral (white + near-black)
Depth: Borders + subtle muted surfaces (no heavy shadows)
Accent: Single yellow CTA

## Tokens
### Spacing
Base: 8px
Scale: 4, 8, 12, 16, 24, 32, 48

### Colors (AppColors)
- accent: `#FFDD2D` (pressed `#F5D420`)
- textPrimary: `#111111`
- textSecondary: `#111111` @ 55%
- background / surface: `#FFFFFF`
- surfaceMuted: `#F7F7F7`
- imagePlaceholder: `#F2F2F2`
- border / divider: `#111111` @ 8%
- error: `#E53935`
- brandDark / darkBackground: `#111111`

### Typography
Use theme text styles from `AppTheme`. Hierarchy via weight and color first, then size.

## Patterns
### Source of truth
Flutter widgets live in `apps/mobile/lib/core/widgets/ds/`:
PrimaryButton, SecondaryButton, GhostButton, AppInput, ProductCard, ProjectCard, StatusBadge, ScreenHeader, BottomNavigation, BottomActionBar, QuantityStepper, PriceBlock, FilterChip, AppSearchBar, etc.

### Navigation
5 tabs: Catalog, Projects, Chats, Cart, Profile. Bottom nav stays visible on tab roots. Product / checkout push on the root navigator above the shell.
Profile addresses = object addresses (адреса объектов), not delivery.

### Product surfaces
- Catalog cards: borderless, square image, flat yellow «В корзину» chip (`AddButton`)
- PDP: hero gallery + `DraggableScrollableSheet` (`AppRadius.sheet`); title → brand meta → `PriceBlock.large` → specs/description via `SectionTitle`; sticky `BottomActionBar` + `IconActionButton` + `PrimaryButton`; overlay nav circles = border-only (no elevation)
- Status: colored text / yellow badge — not loud multi-color chips

### PDP controls
- Expand specs: `GhostButton`
- Spec rows: label secondary / value primary weight 500, `AppColors.divider` hairlines
- Do not use raw `FilledButton` / Material elevation circles on PDP

## Do not
- Introduce a second accent color
- Card-wrap everything with shadows/radius stacks
- Bypass DS for one-off styled Material widgets in features
