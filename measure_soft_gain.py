"""Measures real frame error rate for hard-decision vs soft-decision decoding
of the SAME channel realizations at matched Eb/N0, to get an actual number
for the soft-decision coding gain rather than citing the textbook ~2dB figure
unverified.
"""
import random
from golden_reference import conv_encode, viterbi_decode, soft_viterbi_decode, bpsk_awgn_soft

FRAME_LEN = 500
TRIALS = 200


def hard_bits_from_soft(soft_vals):
    return [1 if s >= 4 else 0 for s in soft_vals]


def measure(ebn0_db):
    hard_errors = 0
    soft_errors = 0
    for trial in range(TRIALS):
        rng = random.Random(trial * 7919 + int(ebn0_db * 1000))
        msg = [rng.randint(0, 1) for _ in range(FRAME_LEN)]
        coded = conv_encode(msg)
        soft = bpsk_awgn_soft(coded, ebn0_db, rng=rng)

        hard_bits = hard_bits_from_soft(soft)
        hard_decoded = viterbi_decode(hard_bits, msg_len=FRAME_LEN)
        if hard_decoded != msg:
            hard_errors += 1

        soft_decoded = soft_viterbi_decode(soft, msg_len=FRAME_LEN)
        if soft_decoded != msg:
            soft_errors += 1

    return hard_errors / TRIALS, soft_errors / TRIALS


if __name__ == "__main__":
    print(f"{'Eb/N0 (dB)':>10} {'hard FER':>10} {'soft FER':>10}")
    for ebn0_db in [0, 1, 2, 3, 4, 5, 6]:
        hard_fer, soft_fer = measure(ebn0_db)
        print(f"{ebn0_db:>10} {hard_fer:>10.3f} {soft_fer:>10.3f}")
