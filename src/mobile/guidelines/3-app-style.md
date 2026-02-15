# 3. App Style Guide

> [!IMPORTANT]
> **Design Compliance**: All UI implementation must strictly follow the designs in `guidelines/0-screens-designs`.

## 1. Visual Identity

The app features a clean, modern, and friendly aesthetic, tailored for children but professional.

### Colors

- **Primary Color**: **Golden Yellow** (`#FFD700` approx)
  - Used for: Primary actions, active states, highlights, headers, and key accents.
- **Secondary Colors**:
  - **White** (`#FFFFFF`)
    - Used for: Main background and card backgrounds.
  - **Light Grey** (`#F5F5F5`)
    - Used for: App scaffolding background.
  - **Dark Grey/Black** (`#333333`)
    - Used for: Primary text.

### Typography

- **Font Family**: Sans-serif, rounded, friendly font (e.g., Poppins, Nunnito, or similar).
- **Characteristics**:
  - Rounded terminals to feel approachable.
  - High legibility.

### Iconography

- **Style**: Simple, rounded, outline icons.
- **Examples**:
  - Home (House)
  - Music (Note)
  - Cards (Deck)
  - Favorites (Heart)

### UI Elements

- **Cards**: The primary container. Rounded corners (approx 16px-24px) with soft, diffused shadows.
- **Progress Bars**: Rounded caps, yellow fill against a lighter background.
- **Buttons**:
  - **Primary**: Pill-shaped or circular, yellow background with black text/icon.
  - **Secondary/Ghost**: Transparent or light grey.

### Image Guidelines

- **Dashboard Cards**:
  - **Resolution**: Recommend **1200x600 px** (~2:1 aspect ratio) or **1280x720 px** (16:9).
  - **Constraints**:
    - **Height**: Fixed at `200` logical pixels.
    - **Width**: Responsive (screen width minus padding).
    - **Fit**: `BoxFit.cover` centers and crops the image to fill the container.
  - **Safe Zone**: Keep important content centered. Edges may be cropped on different devices.
  - **Optimization**:
    - Use **WebP** or optimized **JPEG** format to reduce file size.
    - Target file size: **< 150KB** per image to ensure fast loading and smooth scrolling.
