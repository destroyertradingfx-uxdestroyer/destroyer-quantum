# DESTROYER QUANTUM — Strategy Library

Collected strategies from YouTube, podcasts, and trader interviews.
Each strategy is documented, analyzed for edge quality, and rated for
compatibility with DESTROYER QUANTUM.

## How to Use

1. Ryan sends YouTube link or voice message with strategy
2. I extract transcript (Whisper STT or YouTube API)
3. Parse the strategy rules
4. Rate edge quality (A/B/C/F)
5. Save to this folder
6. When ready to add strategies, pick from library

## Strategy Rating System

- **A-Tier:** Proven edge, simple rules, easy to code, EURUSD compatible
- **B-Tier:** Good edge but needs adaptation or has complex rules
- **C-Tier:** Untested or requires subjective judgment
- **F-Tier:** No edge, marketing hype, or impossible to automate

## Collected Strategies

| # | Strategy | Source | Edge | Codability | Status |
|---|----------|--------|------|------------|--------|
| 1 | [London Breakout](LONDON_BREAKOUT.md) | YouTube | B | Easy | Coded (in EA) |
| 2 | [Gartley Pattern](GARTLEY_PATTERN.md) | YouTube interview | B+ | Medium | Coded (library) |
| 3 | [Time-Based Manipulation](TIME_BASED_MANIPULATION.md) | YouTube (Umar Arpanjabi) | A | Easy | Coded (library) |
| 4 | [Power of 3 / AMD](POWER_OF_3_AMD.md) | YouTube (ICT/SMC) | A | Medium | Coded (library) |
| 5 | [Fractal Model](FRACTAL_MODEL.md) | YouTube (ICT/SMC) | A | Medium-Hard | Coded (library) |
| 6 | [A+ FVG Breakout](A_PLUS_FVG_BREAKOUT.md) | YouTube (9yr trader) | A | Easy | Coded (library) |
| 7 | [CRT Candle Range Theory](CRT_CANDLE_RANGE_THEORY.md) | PDFs (@Im-speculator) | A | Medium | Coded (library) |

## Pending

- More strategies needed from YouTube research
- Ryan to send additional video links
- Focus on traders from UAE, Dubai, South Africa

## Integration Checklist

When adding a strategy to the EA:
1. Unique magic number (check no collision)
2. V23_RegisterStrategy() call
3. g_perfData[] tracking entry
4. Default DISABLED
5. Hardcoded params (not just .set)
6. Backtest before enabling
