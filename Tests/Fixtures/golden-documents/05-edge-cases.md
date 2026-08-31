# Edge Cases

This document exists to hold the shapes that a healing pass must leave alone. Everything here is already correct. If any of it changes, the transform is wrong, not the document.

## Clause numbers that are already escaped

411\. Protection for safety

The clause number above is escaped so that it renders as a clause number rather than as the first item of an ordered list. It must survive a healing pass exactly as written.

## Clause numbers that need no escaping

411.3.3 Additional protection shall be provided.

§7.2 Isolation and switching.

Table 4-2 Rating factors for grouping.

Figure 3.1 Typical star-delta starter arrangement.

## A genuine ordered list

1. Isolate the supply.
2. Prove the circuit dead.
3. Apply the earth connection.
4. Verify the isolation at the point of work.

## A two-digit list marker

41. Protection against electric shock

## Hyphenated compounds that are not broken words

The three-phase supply feeds a short-circuit rated assembly. The high-voltage side is oil-filled and the earth-fault loop impedance was measured at the furthest point. Equipment is type-tested, self-contained, and cross-sectional areas were selected by calculation. Over-current protection is provided at the origin of every final circuit.

## Protected compounds

The low-voltage winding is connected in star-delta. Cable type is XLPE/SWA/PVC, the vector group is Dyn11, redundancy is N+1, and the supply is 11kV/415V.

## A valid table

| Circuit | Rating | Cable |
| --- | --- | --- |
| Pump set | 250 A | 240 mm² |
| Lighting | 32 A | 6 mm² |
| Small power | 63 A | 16 mm² |

## A fenced block that looks like content

```
411. Protection for safety
Rating      Value      Units
1000        5.75       percent
630         4.75       percent
```

Everything inside that fence is quoted verbatim. The aligned columns are not a table and the clause number is not a list item, because a fenced block is not markup.

## An indented block

    Rating      Value
    1000 kVA    5.75%
    630 kVA     4.75%

The block above is indented code. It is quoted exactly as it appears and must not become a table.

## A block quote

> Isolation devices shall be lockable in the open position. This requirement applies to every circuit without exception.

---

## Inline code

The starter type is `star-delta` and the cable specification is `XLPE/SWA/PVC`. Inline code is quoted content and is left as written.
