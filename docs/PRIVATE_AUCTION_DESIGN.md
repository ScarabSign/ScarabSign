# ScarabSign Private Auction — Design Exploration

Status: draft for discussion, no code implied or implemented by this document.

## 1. Why this document exists

The current `ScarabSign` contract (`src/scarab_sign.cairo`) runs a fully public auction: every
bid — bidder address, token, exact amount — is broadcast over the WebSocket relay and signed
in the clear, and `consume_auction` reads bid amounts straight off the calldata. There is no
sealing of any kind today. This document charts what it would take to make bids private, while
keeping the property that made the original design interesting: a single settlement transaction,
no trusted third party running the whole show, and (ideally) no separate "come back later and
reveal your bid" step for bidders.

Three requirements drove the exploration, in the user's own words:
1. **Sealed bids** — no one but the bidder should see the bid amount at submission time.
2. **Prove a bid exceeds a threshold without revealing it** (e.g. "my bid beats `min_bid`", or
   later "my bid beats the current leader") — a zero-knowledge range/comparison proof.
3. **Avoid the classic two-phase commit-reveal pattern** if at all possible — bidders should
   ideally interact once, not twice.

## 2. Primitives glossary

| Primitive | What it gives you | Starknet fit |
|---|---|---|
| **Pedersen commitment** `com = g^amount · h^blinding` | Hiding (amount unrecoverable without the blinding factor) + binding (can't be opened to a different amount) + **additively homomorphic** (`com1 · com2` opens to the sum) | Native. Starknet's STARK-friendly curve and `core::pedersen`/`core::ecdsa` are already used in this contract; no new curve or trusted setup needed for the commitment itself. |
| **ZK range/comparison proof** (e.g. Bulletproofs-style, or any SNARK circuit) | Proves a *committed* value lies in `[A, B]` (or `> x`) without opening the commitment | Not native to Cairo. Needs an external proving system whose verifier is deployed as a Starknet contract. |
| **Garaga** (`keep-starknet-strange/garaga`) | Compiles a **Noir** circuit (or raw Groth16 artifacts) into a generated Cairo verifier contract, deployable on Starknet, with no hand-written Cairo circuit code | This is the concrete, currently-maintained (StarkWare-backed) path to get #2 verified on-chain today. It's the piece that didn't exist in a usable form when this project started. |
| **Timed commitment** (Boehm–Naor style, used by Riggs) | A commitment that any party can *force-open* after a public delay `t`, without the committer's cooperation | Requires an RSA or class-group "hidden order" group for the sequential-squaring trapdoor. Awkward and expensive inside a Cairo circuit — this is the main blocker for a fully trustless single-phase design (see §5). |
| **Verifiable Delay Function (VDF)** | A function that is slow to compute but fast to verify, computed over a public input | Starknet-native alternative worth scouting for the same "force-open without a hidden-order group" goal — see §5.3, this is a speculative angle, not something I found already built for this use case. |

## 3. Tier 1 — Semi-trusted auctioneer/committee (buildable now)

### 3.1 Architecture

Replace the plaintext `Bid` struct's `amount: TokenAmount` with a Pedersen commitment to the
amount, and move winner determination from "loop through public bids on-chain" to "auctioneer
submits one settlement proof":

```
Bid {
  bidder: ContractAddress,
  token: ContractAddress,
  commitment: felt252,          // Pedersen commitment to (amount, blinding)
  collateral_locked: u256,      // publicly escrowed, upper-bounds the hidden amount
  nonce: u64,
}
```

1. **Bidding (single transaction per bidder, no reveal step from the bidder)**: bidder locks
   `collateral_locked` tokens in escrow (standard ERC-20 `approve`/contract pull) and publishes
   `commitment` plus a SNIP-12 signature over the whole bid — this is the same shape as today's
   flow, just with `amount` replaced by `commitment`. The bidder never has to come back.
2. **Off-chain**: the auctioneer (or a small rotating committee, see §3.3) is the party the
   bidder privately discloses `(amount, blinding)` to — e.g. encrypted to the auctioneer's public
   key inside the same signed payload, so it's still a single bidder-side action.
3. **Settlement (one transaction, by the auctioneer)**: the auctioneer produces a ZK proof,
   verified by a Garaga-generated Cairo verifier contract, attesting:
   - the claimed winning commitment opens to `amount* ≥ min_bid` (the "prove bid > x" requirement,
     directly reusable for any threshold — `min_bid` today, "beats the current leader" later), and
   - `amount* ≤ collateral_locked` for that bidder (so the auctioneer can't declare a winner who
     didn't actually escrow enough), and
   - optionally, that `amount*` is the maximum among all submitted commitments (a proof over the
     full set, not just the winner — more expensive but removes the "trust the auctioneer picked
     the real max" assumption).
   `consume_auction` verifies this proof instead of looping over plaintext bid amounts.

### 3.2 What this buys vs. today's plaintext design

- Losing bids **never appear on-chain or in the WebSocket relay in plaintext** — only
  commitments and, at settlement, the single winning amount.
- No bidder-driven reveal transaction — the two-phase pattern collapses to one bidder action
  (bid) + one auctioneer action (settle), and the auctioneer's settlement is itself the
  "reveal," but it's a proof, not a disclosure of the losing bids.
- The range-proof machinery is exactly reusable for "prove bid > x" against any threshold, not
  just `min_bid` — e.g. it's the same circuit shape used later for Tier 2's "beats the leader"
  proof.

### 3.3 What it costs / doesn't solve

- The auctioneer (or committee) **does** see every bid in plaintext off-chain — this is privacy
  *from other bidders*, not privacy from the auctioneer. That may be entirely acceptable (it's
  no worse than a traditional sealed-bid auction with a human auctioneer), but it's not
  "trustless" in the strict sense.
- If the auctioneer refuses to settle (equivalent to today's abandoned-bid problem), collateral
  is stuck until some timeout/slashing rule releases it — worth designing a simple timeout
  refund path regardless of which tier is chosen.
- A rotating committee (threshold-decrypt the bid ciphertexts, `k`-of-`n`) reduces "trust one
  party" to "trust that fewer than `k` of `n` collude," at the cost of needing a
  threshold-encryption scheme and committee-selection logic — a reasonable dial to turn later,
  not needed for a first version.

## 4. Tier 2 — Fully trustless, no privileged party (aspirational)

The requirement here is that **no party ever learns a losing bid**, not even the auctioneer.
That means something other than a trusted party has to determine and prove the winner, which is
the actual hard problem sealed-bid auction research has circled for decades.

### 4.1 Riggs (Tyagi, Arun, Freitag, Wahby, Bonneau, Mazières — IACR 2023/1336)

The closest prior art to "avoid the 2-step commit-reveal" without a trusted auctioneer. Its
core move: instead of a bidder-driven reveal phase, every commitment is a **timed commitment** —
*anyone* can force it open after a public delay `t`, via a verifiable sequential-squaring
computation, whether or not the bidder cooperates. Composed with an efficient Bulletproofs-style
range proof (checked at bid time against the timed commitment, not re-derived at open time), this
gives: single bidder action, no reveal transaction required from the bidder, and liveness even if
bidders vanish or collude to grief.

The catch for Starknet: the timed-commitment trapdoor is built over an **RSA group of unknown
order** (or a class group) — the security of "force-opening takes exactly `t` sequential steps"
relies on nobody knowing the group order. Cairo's field arithmetic is native to a single STARK
prime field; doing RSA-modulus big-integer sequential squaring (and a matching proof of
exponentiation) inside a Cairo circuit is the kind of thing that's possible but was called out
in the paper itself as one to two orders of magnitude more expensive than their optimized
approach even in their native (non-Cairo) implementation. This is the single biggest open
question for a trustless design here.

### 4.2 Lighter alternatives worth scouting (not deeply researched, flagged for follow-up)

- **Threshold MPC among bidders**: bidders jointly compute "who has the max" via a
  garbled-circuit or secret-sharing protocol, with no single party ever seeing plaintext bids.
  Removes the RSA-group problem but trades it for an interactive multi-round off-chain protocol
  among bidders, which reintroduces liveness/collusion issues Riggs specifically set out to
  avoid (an idle or malicious bidder can stall the protocol). Worth a closer look, but likely a
  worse fit than Tier 1's committee model for a first version.
- **FHE-based comparison**: encrypt bids under a fully-homomorphic scheme and compute the max
  homomorphically on-chain or via a coprocessor. Emerging (multiple FHE-on-EVM projects exist)
  but still too immature/expensive for a settlement-critical primitive today, and there's no
  Starknet-native FHE tooling comparable to Garaga's ZK path yet. Track, don't build against.

### 4.3 A Starknet-native angle worth exploring (speculative, my own inference, not from prior art)

Starknet is, at its core, a STARK-proving system — cheap on-chain verification of expensive
off-chain computation is exactly what it's built for. A **verifiable delay function evaluated
and proven with a STARK** (rather than an RSA proof of exponentiation) could plausibly serve
the same "force-open without needing a hidden-order group" role that Riggs's RSA construction
serves, using a genuinely sequential Cairo-friendly computation (e.g. a MinRoot/Sloth-style VDF
over the STARK prime, which several STARK-based VDF proposals from 2020–2021 already targeted)
verified via recursive STARK proving instead of an RSA proof of exponentiation. This sidesteps
needing an RSA/class group entirely. I have **not** validated that a STARK-native VDF with the
right sequentiality guarantees is production-ready, or that it composes cleanly with a Pedersen
timed-commitment the way Riggs's RSA construction does — this is a research thread, not a
recommendation, and would need its own literature check before being taken seriously.

## 5. Comparison

| | Today (plaintext) | Tier 1 (semi-trusted) | Tier 2 (trustless) |
|---|---|---|---|
| Bidder actions | 1 (sign bid) | 1 (sign + commit) | 1 (sign + timed-commit) |
| Who sees losing bids | Everyone | Auctioneer/committee | No one |
| New on-chain component | None | Garaga-generated ZK verifier | ZK verifier + timed-commitment force-open logic |
| Buildable with today's Starknet tooling | Yes (already exists) | Yes | Not without significant new crypto engineering |
| Trust assumption | None needed (nothing private) | Auctioneer/committee honest-but-unable-to-lie-about-winner (proof-enforced) | None |

## 6. Recommendation

Build **Tier 1** first. It directly satisfies both concrete asks (sealed bids, prove-bid->x) with
primitives and tooling (Pedersen commitments, Garaga-verified Noir circuits) that exist and are
maintained today, it collapses the bidder-facing flow to a single action, and the range-proof
circuit built for it is the same one Tier 2 would eventually reuse. Treat Tier 2 as a tracked
research thread (§4), not a near-term build target — the RSA-group cost problem is real and
unsolved for Cairo specifically.

### Suggested next step (after this doc is reviewed, not started yet)

A narrow proof-of-concept, scoped to just the new primitive rather than the whole auction flow:
- A Noir circuit taking `(amount, blinding)` as private inputs and `(commitment, threshold)` as
  public inputs, proving `commitment == Pedersen(amount, blinding) ∧ amount ≥ threshold`.
- Compile it with Garaga to a Cairo verifier, deploy to a local Katana devnet, and call it
  directly (no auction logic yet) to confirm proof size/gas/latency are acceptable before
  touching `scarab_sign.cairo` at all.

## 7. Open questions

- Collateral/timeout policy if the auctioneer never settles (applies to Tier 1 regardless of
  which cryptographic path is chosen).
- Committee selection and threshold-decryption scheme for the "committee" variant of Tier 1, if
  a single auctioneer is judged too centralized.
- Whether "prove `amount*` is the maximum among all commitments" (full-set proof) is worth the
  extra circuit cost over just proving the winner's commitment beats `min_bid` and trusting the
  auctioneer's selection (cheaper, weaker guarantee).
- Whether the STARK-native VDF angle (§4.3) is worth a dedicated literature pass before writing
  off Tier 2 as impractical.

## 8. References

- SNIP-12: `https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-12.md`
- Garaga: `https://github.com/keep-starknet-strange/garaga`, `https://garaga.gitbook.io/garaga`
- Riggs: Decentralized Sealed-Bid Auctions — Tyagi, Arun, Freitag, Wahby, Bonneau, Mazières.
  IACR ePrint 2023/1336. `https://eprint.iacr.org/2023/1336.pdf`
- Pedersen commitments: Pedersen 1991 (as cited in Riggs §2).
- Bulletproofs range proofs: Bünz, Bootle, Boneh, Poelstra, Wuille, Maxwell (BBB+18), as used by
  both Riggs and standard confidential-transaction designs.
