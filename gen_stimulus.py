from golden_reference import generate_test_suite

def bits_to_str(bits):
    return "".join(str(b) for b in bits)

def main():
    suite = generate_test_suite()
    lines = [str(len(suite))]
    for case in suite:
        lines.append(f"{case['length']} {bits_to_str(case['coded'])} {bits_to_str(case['expected_decoded'])}")
    with open("vhdl/stimulus.txt", "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {len(suite)} cases to vhdl/stimulus.txt")

if __name__ == "__main__":
    main()
