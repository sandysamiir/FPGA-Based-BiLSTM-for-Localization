import os

def float_to_fixed(value, q_format=(4, 12)):
    """Convert a floating-point number to fixed-point Qm.n format."""
    m, n = q_format
    scale_factor = 2 ** n
    fixed_value = int(round(value * scale_factor))
    return fixed_value

def process_file(input_file, output_file, q_format=(4, 12)):
    """Convert the contents of a file to fixed-point format and save to a new file in hexadecimal."""
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            try:
                # Convert each line to a float, then to fixed-point
                float_value = float(line.strip())
                fixed_value = float_to_fixed(float_value, q_format)
                # Convert the fixed-point value to hexadecimal
                hex_value = f"{fixed_value & 0xFFFF:04X}"  # Ensure 16-bit representation
                outfile.write(f"{hex_value}\n")
            except ValueError:
                # Skip lines that cannot be converted to float
                print(f"Skipping invalid line in {input_file}: {line.strip()}")

def process_bilstm_files(directory):
    """Process *_hh_bilstm*.mem files by concatenating every two rows, and *_ih_bilstm*.mem files without concatenation."""
    for filename in os.listdir(directory):
        if filename.endswith(".mem"):
            file_path = os.path.join(directory, filename)
            if "_hh_bilstm" in filename:
                with open(file_path, 'r') as infile:
                    lines = infile.readlines()
                concatenated_lines = []
                for i in range(0, len(lines), 2):
                    concatenated_line = ''.join(line.strip() for line in lines[i:i + 2])
                    concatenated_lines.append(concatenated_line)
                with open(file_path, 'w') as outfile:
                    outfile.write("\n".join(concatenated_lines) + "\n")
                print(f"Processed and reduced {file_path} (_hh_bilstm 2-row concat)")
            elif "_ih_bilstm" in filename:
                # Just print info, do not concatenate, but you can still clean lines if needed
                with open(file_path, 'r') as infile:
                    lines = [line.strip() for line in infile if line.strip()]
                with open(file_path, 'w') as outfile:
                    outfile.write("\n".join(lines) + "\n")
                print(f"Processed {file_path} (_ih_bilstm, no concat)")

def process_bilstm_weight_files(directory):
    """Process all bilstm_weight_hh_*.mem and bilstm_weight_ih_*.mem files by concatenating every four consecutive rows."""
    for filename in os.listdir(directory):
        if (
            filename.endswith(".mem")
            and (filename.startswith("bilstm_weight_hh_") or filename.startswith("bilstm_weight_ih_"))
        ):
            file_path = os.path.join(directory, filename)
            with open(file_path, 'r') as infile:
                lines = infile.readlines()
            
            # Concatenate every two consecutive rows
            concatenated_lines = []
            for i in range(0, len(lines), 2):
                concatenated_line = ''.join(line.strip() for line in lines[i:i + 2])
                concatenated_lines.append(concatenated_line)
            
            # Write the concatenated lines back to the same file
            with open(file_path, 'w') as outfile:
                outfile.write("\n".join(concatenated_lines) + "\n")
            
            print(f"Processed and reduced {file_path} (2-row concat)")

def process_gate_biases(directory, q_format=(4, 12)):
    """Process each gate bias .txt file and save as .mem file."""
    gate_names = ["input_gate", "forget_gate", "output_gate", "cell_gate"]
    for gate in gate_names:
        txt_file = os.path.join(directory, f"{gate}_bias.txt")
        mem_file = os.path.join(directory, f"{gate}_bias.mem")
        if os.path.exists(txt_file):
            process_file(txt_file, mem_file, q_format)
            print(f"Processed {txt_file} -> {mem_file}")

def main():
    directory = os.path.dirname(__file__)
    for filename in os.listdir(directory):
        if filename.endswith('.txt'):
            input_path = os.path.join(directory, filename)
            output_path = os.path.join(directory, filename.replace('.txt', '.mem'))
            process_file(input_path, output_path, q_format=(4, 12))
            print(f"Processed {input_path} -> {output_path}")
    
    # Process bilstm_weight_hh_*.mem files
    process_bilstm_files(directory)
    process_bilstm_weight_files(directory)

    # Process gate bias files
    process_gate_biases(directory, q_format=(4, 12))

if __name__ == "__main__":
    main()
