from pypdf import PdfReader
import os

base = r"c:\Users\Asian Computers\Downloads\Project DSD"
out = r"c:\Users\Asian Computers\Downloads\Project DSD"

# Extract specification
path = os.path.join(base, "DSD8-Processor-Project-Specification.pdf")
reader = PdfReader(path)
with open(os.path.join(out, "spec_text.txt"), "w", encoding="utf-8") as f:
    for i, page in enumerate(reader.pages):
        text = page.extract_text()
        if text and text.strip():
            f.write(f"\n--- Page {i+1} ---\n")
            f.write(text)
print(f"Spec: {len(reader.pages)} pages extracted")

# Extract kickoff
path = os.path.join(base, "DSD-8 Processor Project Kickoff.pdf")
reader = PdfReader(path)
with open(os.path.join(out, "kickoff_text.txt"), "w", encoding="utf-8") as f:
    for i, page in enumerate(reader.pages):
        text = page.extract_text()
        if text and text.strip():
            f.write(f"\n--- Page {i+1} ---\n")
            f.write(text)
print(f"Kickoff: {len(reader.pages)} pages extracted")
