import re

# Read the input file
with open('test_inputs_difficult.txt', 'r') as infile:
    content = infile.read()

# Split the content into elements (comma or whitespace separated)
elements = re.split(r'[\s,]+', content.strip())

def float_to_q4_12_hex(val):
    # Clamp to Q4.12 range
    max_val = 7.999755859375  # (2^3 - 2^-12)
    min_val = -8.0
    val = max(min(float(val), max_val), min_val)
    # Convert to fixed-point
    scaled = int(round(val * (2**12)))
    # Handle two's complement for negative numbers
    if scaled < 0:
        scaled = (1 << 16) + scaled
    return f"{scaled:04X}"

# Write each element as Q4.12 hex to the output .mem file
with open('input_memory_difficult.mem', 'w') as outfile:
    for element in elements:
        if element:  # skip empty strings
            outfile.write(float_to_q4_12_hex(element) + '\n')