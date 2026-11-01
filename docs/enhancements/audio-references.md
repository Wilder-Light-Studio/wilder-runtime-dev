# Audio References — Inspiration

> **Home:** this note belongs to the audio/UI project. It lives here, beside
> `ui-vision.md` and `audio-nl-ring-buffer.md`, until that project exists, then all
> three move there. Nothing in it is a Cosmos runtime requirement.

Places to learn from for building synths and instruments.

| Reference | Link | Why it's useful | Licence note |
|---|---|---|---|
| **Vital** (Matt Tytel) | Site: https://vital.audio · Source: https://github.com/mtytel/vital | Open-source wavetable synth. Study it for its DSP architecture, its modulation system and its UI: animated, visual and readable, with modulation you can see. | GPL-3.0. Fine to learn from. Copying its code makes our code GPL too, so reimplement ideas rather than copying code. |
| **Surge XT** (community-maintained) | Site: https://surge-synthesizer.github.io · Source: https://github.com/surge-synthesizer/surge | Open-source hybrid synth with many oscillator, filter and effect types, and well-organized DSP code. It also did serious accessibility work (screen-reader support and keyboard navigation), which makes it the best prior art for our accessibility goals. Its `sst-*` libraries split the DSP into reusable pieces. | GPL-3.0 for Surge itself. Check each `sst-*` library's licence separately before relying on it. |

## Texts

### Start here

| Text | Free or paid | Why |
|---|---|---|
| Will Pirkle — *Designing Software Synthesizer Plugins in C++* (2nd ed., Focal Press) | Paid | The most direct guide to building a synth: oscillators, filters, envelopes, voices and modulation. Uses C++, but the ideas translate to Nim. |
| Ross Bencina — "Real-time audio programming 101: time waits for nothing" (rossbencina.com) | Free | The essential rules for the audio kernel: no locks, no allocation, no waiting. |
| Vadim Zavalishin — *The Art of VA Filter Design* (Native Instruments) | Free PDF | How to build analog-sounding digital filters, such as the Moog ladder. |

### Foundations

| Text | Free or paid | Why |
|---|---|---|
| Steven W. Smith — *The Scientist and Engineer's Guide to Digital Signal Processing* (dspguide.com) | Free | A clear, gentle introduction to DSP. |
| Miller Puckette — *The Theory and Technique of Electronic Music* (msp.ucsd.edu) | Free | From the creator of Pure Data and Max. Synthesis theory, with patching in mind. |
| Julius O. Smith III — online books (ccrma.stanford.edu/~jos) | Free | Deep references on filters, spectral processing and physical modelling. |
| Curtis Roads — *The Computer Music Tutorial* (2nd ed., MIT Press) | Paid | The big reference for every synthesis technique. Look things up in it rather than reading it cover to cover. |

### Also useful

| Text | Free or paid | Why |
|---|---|---|
| Will Pirkle — *Designing Audio Effect Plugins in C++* | Paid | The companion book for effects: reverb, delay, dynamics. |
| Richard Boulanger and Victor Lazzarini (eds.) — *The Audio Programming Book* (MIT Press) | Paid | Broad, hands-on audio programming in C. |
| Fred Welsh — *Welsh's Synthesizer Cookbook* | Paid | Sound design: how classic sounds are built from patches. |
| Hal Chamberlin — *Musical Applications of Microprocessors* | Paid (out of print) | A classic. Elegant thinking under tight constraints, relevant to small boards. |

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
