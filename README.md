# Crypto Battle Buddy
<p align="center">
  <img src="CBB%20%281024%20x%201024%20px%29.png" alt="Crypto Battle Buddy logo" width="320">
</p>


**An AI-powered crypto discipline mentor that helps users follow their own plans, resist emotional trading, and learn from the consequences of action or inaction.**

## The Problem

Crypto markets operate continuously and can move quickly. Fear, excitement, panic, and fear of missing out can cause investors to abandon plans they made when they were thinking clearly.

Most crypto tools provide more information—charts, prices, predictions, signals, and portfolio values—but more information does not automatically create better discipline.

## The Solution

Crypto Battle Buddy focuses on accountability rather than prediction.

The user defines:

- Which crypto assets matter to them
- Their threshold levels
- Their intended actions
- Their execution percentages
- Their personal operating plan

Crypto Battle Buddy then monitors fresh market information and compares current conditions with the user’s plan.

It does not make trades for the user or tell the user what trade to make next. It shows what happened, connects the event to the user’s stated plan, and leaves the final decision with the user.

## Core Capabilities

- User-defined crypto asset management
- Live market-price monitoring
- Threshold crossing detection
- Tiered action plans
- Per-asset ARM controls
- Execute and Mark Missed accountability actions
- Current-cycle and lifetime discipline tracking
- Historical execution-event preservation
- Feed-health and stale-data protection
- Fresh-data-only report and recommendation generation
- Mobile-first operator interface

## How It Works

1. The user selects an asset.
2. The user creates a plan with price thresholds and intended actions.
3. Crypto Battle Buddy monitors live market data.
4. When a threshold is crossed, the app identifies the relevant plan step.
5. The user remains responsible for recording whether the planned action was executed or missed.
6. The app updates the user’s discipline record and provides accountability feedback.

## AI Development

OpenAI tools were used as a coding, inspection, debugging, and reasoning partner throughout development.

I directed the product mission, architecture, user experience, behavioral rules, testing process, and phase-by-phase implementation. Every material change was inspected, tested, and validated before acceptance.

## Data Integrity

Crypto Battle Buddy does not present stored or stale market-derived information as current.

Current market reports, prices, snapshots, and recommendations may only be populated after a fresh successful market poll. User-created plans and historical execution records are preserved separately from live market information.

## Technology

- Flutter
- Dart
- Android
- Multiple crypto price-feed integrations
- Local persistent storage
- Automated unit and widget testing
- OpenAI-assisted development workflow

## Project Status

Crypto Battle Buddy is a functional working application under active development and validation.

The public repository is a project showcase. Production source code, credentials, signing material, and private configuration are intentionally excluded.

## Creator

Created and developed by **Eric Heffner**.

## Ownership and License

Copyright © 2026 Eric Heffner. All rights reserved.

This project is publicly viewable for demonstration and evaluation purposes only. No permission is granted to copy, modify, distribute, sublicense, or reuse the project, its design, documentation, branding, or source code without prior written authorization.
