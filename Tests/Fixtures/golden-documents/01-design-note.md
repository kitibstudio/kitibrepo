---
title: Substation LV Distribution Design Note
project: Kitib Works Phase 2
author: S. Moo
date: 2026-08-11
status: issued
---

# Substation LV Distribution Design Note

## 1 Purpose

This note records the basis of design for the low-voltage distribution downstream of transformer TX-01 and the reasoning behind the switching arrangement selected at the main LV panel.

## 2 Basis of design

The installation is fed from a single oil-filled distribution transformer with the ratings given below. All equipment is type-tested and rated for the prospective fault level at the point of installation.

| Parameter | Value | Source |
| --- | --- | --- |
| Rated power | 1000 kVA | Nameplate |
| Voltage ratio | 11 kV / 415 V | Nameplate |
| Vector group | Dyn11 | Nameplate |
| Impedance | 5.75% at 75 C | Type test certificate |
| Cooling | ONAN | Nameplate |
| Ambient design temperature | 40 C | Site survey |

The transformer low-voltage winding is connected to the main LV panel by four single-core cables per phase, XLPE/SWA/PVC construction, sized on the cross-sectional area required for both continuous load and earth-fault loop impedance.

## 3 Motor starting

Direct-on-line starting was rejected for the 160 kW pump set on the grounds of voltage dip at the main busbar. A star-delta starter is specified instead, which limits starting current to approximately one third of the direct-on-line value.

> The 160 kW pump set is the only load on this board large enough to require reduced-voltage starting. Every other motor starts direct-on-line.

## 4 Redundancy

Cooling fans are provided on an N+1 basis. Loss of any single fan does not derate the transformer at the design ambient temperature.

- Fan control is automatic, initiated by winding temperature.
- Manual override is provided at the local control panel.
- Fan failure raises a common alarm at the BMS head end.

## 5 Verification

The following checks are to be completed before energisation.

1. Insulation resistance test on all outgoing circuits.
2. Earth-fault loop impedance measured at the furthest point of each final circuit.
3. Phase rotation confirmed at the main panel and at each motor terminal box.
4. Protection settings applied and recorded against the coordination study.

## 6 References

See Table 4-2 for the grouping rating factors applied to the outgoing circuits. Additional protection requirements are given in 411.3.3 and the supplementary bonding requirements in Regulation 415.2. The isolation requirements of clause 7.2 apply to all fixed equipment.
