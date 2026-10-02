import random
from golden_reference import conv_encode, soft_viterbi_decode, bpsk_awgn_soft


def main():
    lengths = [24, 100, 500, 1500]
    ebn0_values = [1, 2, 3, 4, 6, 10, 100]  # 100dB = effectively noiseless sanity check
    trials = 30

    cases = []
    for length in lengths:
        for ebn0_db in ebn0_values:
            for trial in range(trials):
                rng = random.Random(hash((length, ebn0_db, trial)) % 1000000)
                msg = [rng.randint(0, 1) for _ in range(length)]
                coded = conv_encode(msg)
                soft = bpsk_awgn_soft(coded, ebn0_db, rng=rng)
                erase = [False] * len(coded)
                decoded = soft_viterbi_decode(soft, erase=erase, msg_len=length)
                cases.append((length, soft, erase, decoded))

    # Erasure cases: sabotage every 10th symbol to the worst possible soft
    # value for its true bit, then mark it erased. Proven in isolation
    # (measure script) that erase=1 recovers the message from exactly this
    # sabotage while erase=0 does not -- so this exercises a scenario where
    # erasure actually changes the outcome, not one where it's a no-op.
    for length in lengths:
        for trial in range(20):
            rng = random.Random(hash(("erase", length, trial)) % 1000000)
            msg = [rng.randint(0, 1) for _ in range(length)]
            coded = conv_encode(msg)
            soft = bpsk_awgn_soft(coded, ebn0_db=8, rng=rng)
            erase = [False] * len(coded)
            for i in range(0, len(coded), 10):
                soft[i] = 7 if coded[i] == 0 else 0
                erase[i] = True
            decoded = soft_viterbi_decode(soft, erase=erase, msg_len=length)
            cases.append((length, soft, erase, decoded))

    lines = [str(len(cases))]
    for length, soft, erase, decoded in cases:
        sym_str = "".join(str(s) for s in soft)
        erase_str = "".join("1" if e else "0" for e in erase)
        dec_str = "".join(str(b) for b in decoded)
        lines.append(f"{length} {sym_str} {erase_str} {dec_str}")

    with open("vhdl/stimulus.txt", "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {len(cases)} soft-decision cases to vhdl/stimulus.txt")


if __name__ == "__main__":
    main()
