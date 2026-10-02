"""Golden-reference model for the (171,133) octal, K=7, rate-1/2 convolutional
code (the IEEE 802.11a/g/n mandated code). Used to generate labeled test
vectors for viterbi_k7_decoder.vhd and to independently check its output.
"""
import math
import random

K = 7
POLYS = [0o171, 0o133]


def conv_encode(bits, polys=POLYS, k=K):
    # shift[i] taps the polynomial's bit i (LSB multiplies the NEWEST tap,
    # shift[0]). This combination -- original [171,133] poly order, this
    # bit direction -- is the only one of 8 plausible (poly order x shift
    # direction x poly bit direction) combinations that reproduces the real
    # trellis table with zero mismatches, found by exhaustive search after
    # single-hypothesis hand-checks gave false confidence in a wrong fix.
    shift = [0] * k
    out = []
    for b in bits:
        shift = [b] + shift[:-1]
        for p in polys:
            parity = 0
            for i in range(k):
                if (p >> i) & 1:
                    parity ^= shift[i]
            out.append(parity)
    return out


def branch_output(state, bit, polys=POLYS, k=K):
    # state bit0 = most recent previous input, bit(k-2) = oldest kept input
    # (forced by next_state's own packing: next_state = (bit|(state<<1))&mask
    # means new bit0 = incoming bit, new bit(i+1) = old biti). So the full
    # shift register, newest-first, is [bit, state_bit0, state_bit1, ...].
    shift_bits = [(state >> i) & 1 for i in range(0, k - 1)]
    shift = [bit] + shift_bits
    out = []
    for p in polys:
        parity = 0
        for i in range(k):
            if (p >> i) & 1:
                parity ^= shift[i]
        out.append(parity)
    next_state = (bit | (state << 1)) & ((1 << (k - 1)) - 1)
    return next_state, out


def viterbi_decode(coded, polys=POLYS, k=K, msg_len=None):
    n = len(polys)
    num_states = 1 << (k - 1)
    assert len(coded) % n == 0
    num_steps = len(coded) // n

    INF = float("inf")
    path_metric = [INF] * num_states
    path_metric[0] = 0
    survivors = []

    for t in range(num_steps):
        rbits = coded[t * n:(t + 1) * n]
        new_pm = [INF] * num_states
        new_surv = [0] * num_states
        for s in range(num_states):
            if path_metric[s] == INF:
                continue
            for bit in (0, 1):
                ns, out = branch_output(s, bit, polys, k)
                bm = sum(1 for a, b in zip(rbits, out) if a != b)
                cand = path_metric[s] + bm
                if cand < new_pm[ns]:
                    new_pm[ns] = cand
                    new_surv[ns] = (s, bit)
        path_metric = new_pm
        survivors.append(new_surv)

    best_state = min(range(num_states), key=lambda s: path_metric[s])
    decoded = []
    s = best_state
    for t in range(num_steps - 1, -1, -1):
        prev_s, bit = survivors[t][s]
        decoded.append(bit)
        s = prev_s
    decoded.reverse()

    if msg_len is not None:
        decoded = decoded[:msg_len]
    return decoded


def bpsk_awgn_soft(coded_bits, ebn0_db, rate=0.5, rng=None):
    """Real BPSK+AWGN channel model. bit 1 -> +1, bit 0 -> -1, unit symbol
    energy, noise variance sigma^2 = N0/2 derived from Eb/N0 (per information
    bit, the standard way coding gain is quoted) via Es/N0 = rate * Eb/N0.
    Returns 3-bit unsigned soft values (0..7): 0 = strongest '0', 7 =
    strongest '1', matching the convention openofdm's viterbi.v expects on
    sym0/sym1.
    """
    rng = rng or random.Random()
    esn0_db = ebn0_db + 10 * math.log10(rate)
    esn0_linear = 10 ** (esn0_db / 10)
    sigma = math.sqrt(1 / (2 * esn0_linear))
    soft_vals = []
    for b in coded_bits:
        bpsk = 1.0 if b == 1 else -1.0
        r = bpsk + rng.gauss(0, sigma)
        r_clipped = max(-2.0, min(2.0, r))
        sym = round((r_clipped + 2.0) / 4.0 * 7)
        soft_vals.append(sym)
    return soft_vals


def soft_branch_cost(sym, expected_bit, erased=False):
    if erased:
        return 0
    return sym if expected_bit == 0 else (7 - sym)


def soft_viterbi_decode(soft_vals, erase=None, polys=POLYS, k=K, msg_len=None):
    n = len(polys)
    num_states = 1 << (k - 1)
    assert len(soft_vals) % n == 0
    num_steps = len(soft_vals) // n
    if erase is None:
        erase = [False] * len(soft_vals)

    INF = float("inf")
    path_metric = [INF] * num_states
    path_metric[0] = 0
    survivors = []

    for t in range(num_steps):
        rsyms = soft_vals[t * n:(t + 1) * n]
        rerase = erase[t * n:(t + 1) * n]
        new_pm = [INF] * num_states
        new_surv = [0] * num_states
        for s in range(num_states):
            if path_metric[s] == INF:
                continue
            for bit in (0, 1):
                ns, out = branch_output(s, bit, polys, k)
                bm = sum(soft_branch_cost(sym, e, er) for sym, e, er in zip(rsyms, out, rerase))
                cand = path_metric[s] + bm
                if cand < new_pm[ns]:
                    new_pm[ns] = cand
                    new_surv[ns] = (s, bit)
        path_metric = new_pm
        survivors.append(new_surv)

    best_state = min(range(num_states), key=lambda s: path_metric[s])
    decoded = []
    s = best_state
    for t in range(num_steps - 1, -1, -1):
        prev_s, bit = survivors[t][s]
        decoded.append(bit)
        s = prev_s
    decoded.reverse()

    if msg_len is not None:
        decoded = decoded[:msg_len]
    return decoded


def self_check_thesis_toy_example():
    # KU Leuven thesis's own (7,5) octal K=3 worked example: msg 11011 -> decode back to 11011.
    toy_polys = [0o7, 0o5]
    toy_k = 3
    msg = [1, 1, 0, 1, 1]
    coded = conv_encode(msg, toy_polys, toy_k)
    decoded = viterbi_decode(coded, toy_polys, toy_k, msg_len=len(msg))
    assert decoded == msg, f"self-check FAILED: {decoded} != {msg}"
    print("self_check_thesis_toy_example: PASS")


def generate_test_suite(lengths=(24, 100, 500, 1500), bers=(0.0, 0.01, 0.03, 0.05, 0.08),
                         trials=50, seed_base=0):
    cases = []
    for length in lengths:
        for ber in bers:
            for trial in range(trials):
                rnd = random.Random(seed_base * 100000 + hash((length, ber, trial)) % 100000)
                msg = [rnd.randint(0, 1) for _ in range(length)]
                coded = conv_encode(msg)
                noisy = list(coded)
                for i in range(len(noisy)):
                    if rnd.random() < ber:
                        noisy[i] ^= 1
                decoded = viterbi_decode(noisy, msg_len=length)
                cases.append({
                    "length": length,
                    "ber": ber,
                    "coded": noisy,
                    "expected_decoded": decoded,
                    "clean_msg": msg,
                })
    return cases


if __name__ == "__main__":
    self_check_thesis_toy_example()
    suite = generate_test_suite()
    print(f"generated {len(suite)} test cases")
