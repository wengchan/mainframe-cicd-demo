#!/usr/bin/env python3
"""
mvs_submit.py — Submit JCL to TK4- via the Hercules 3505 card reader socket
and retrieve job output from the JES2 printer spool files.

The 3505 sockdev is a Hercules device that acts as a JES2 internal reader.
Any text sent to the port is treated as punched cards and submitted as a job.

Usage:
  python3 mvs_submit.py submit  <host> <port> <local_jcl>
  python3 mvs_submit.py upload  <host> <port> <jcl_template> <source_file>
  python3 mvs_submit.py getlog  <container_name> <jobname> <output_file>
  python3 mvs_submit.py checkrc <container_name> <jobname>

Exit codes: 0 = success, 1 = failure
"""

import sys
import socket
import subprocess
import os
import re
import time

PRINTER_FILES = [
    "prt/prt00e.txt",   # standard JES output (CLASS=A default)
    "prt/prt002.txt",   # alternate printer
    "log/hardcopy.log", # hardcopy console log
]
HERCULES_ROOT = "/opt/hercules/tk4"

def upload_source(host, port, jcl_template, source_file):
    """
    Merge a COBOL source file into an IEBUPDTE JCL template and submit it.
    The template must contain the literal @@COBOL_SOURCE@@ as a placeholder.
    IEBUPDTE is a standard IBM utility that populates PDS members.
    """
    print(f"Uploading {source_file} via IEBUPDTE JCL...")
    with open(jcl_template) as f:
        template = f.read()
    with open(source_file) as f:
        source_lines = f.readlines()

    # Strip trailing whitespace but preserve column 72 — COBOL fixed format
    cobol_cards = [line.rstrip('\n').rstrip()[:72] for line in source_lines]
    source_block = '\n'.join(cobol_cards)

    merged_jcl = template.replace('@@COBOL_SOURCE@@', source_block)

    # Write to a temp file so submit_jcl can handle it
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.jcl',
                                     delete=False) as tmp:
        tmp.write(merged_jcl)
        tmp_path = tmp.name

    submit_jcl(host, port, tmp_path)
    os.unlink(tmp_path)
    print("Source upload submitted.")

def submit_jcl(host, port, jcl_file):
    """Send JCL to the Hercules 3505 card reader socket."""
    print(f"Submitting {jcl_file} -> {host}:{port}")
    with open(jcl_file, 'r') as f:
        jcl_text = f.read()

    # Pad each card to 80 bytes, add newline — standard card image format
    cards = []
    for line in jcl_text.splitlines():
        card = line.rstrip('\n').ljust(80)[:80]
        cards.append(card + '\n')
    payload = ''.join(cards).encode('ascii')

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(15)
    s.connect((host, int(port)))
    s.sendall(payload)
    s.close()
    print(f"Submitted {len(cards)} cards to JES2 card reader.")

def get_log_via_docker(container, jobname, output_file):
    """
    Retrieve job output from TK4- printer spool files via docker exec.
    TK4- writes SYSOUT to text files in the Hercules working directory.
    """
    print(f"Searching printer files for job: {jobname}")
    jobname_upper = jobname.upper()

    for rel_path in PRINTER_FILES:
        full_path = f"{HERCULES_ROOT}/{rel_path}"
        result = subprocess.run(
            ["docker", "exec", container, "cat", full_path],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            continue

        content = result.stdout
        if jobname_upper in content.upper():
            # Extract the section of the file belonging to this job
            # Job output is delimited by JES2 job separators
            lines = content.splitlines()
            job_lines = []
            in_job = False
            for line in lines:
                if jobname_upper in line.upper() and not in_job:
                    in_job = True
                if in_job:
                    job_lines.append(line)
                # Stop at the next job separator (blank page or next JOB header)
                if in_job and len(job_lines) > 5 and '1' == line[:1] and jobname_upper not in line.upper():
                    break

            with open(output_file, 'w') as f:
                f.write('\n'.join(job_lines if job_lines else lines))
            print(f"Output saved to: {output_file}")
            return True

    print(f"Job {jobname} not yet in printer output — may still be running.")
    return False

def check_rc_via_docker(container, jobname):
    """
    Check job return code from printer spool files.
    Returns the MAXCC as an integer, or -1 if not found.
    """
    output_file = f"/tmp/{jobname}_out.txt"
    found = get_log_via_docker(container, jobname, output_file)
    if not found:
        return -1

    with open(output_file) as f:
        content = f.read()

    # Check for ABEND first
    abend_match = re.search(r'(ABEND|S0C[0-9A-F]|S806|S013)', content, re.IGNORECASE)
    if abend_match:
        print(f"ABEND detected: {abend_match.group()}")
        return 999

    # Look for MAXCC or step-level RC
    maxcc_match = re.search(r'MAXCC=(\d+)', content)
    if maxcc_match:
        return int(maxcc_match.group(1))

    rc_match = re.search(r'\bRC=\s*(\d+)', content)
    if rc_match:
        return int(rc_match.group(1))

    return 0  # No explicit RC found — assume success

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == 'upload' and len(sys.argv) == 6:
        upload_source(sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5])

    elif cmd == 'submit' and len(sys.argv) == 5:
        submit_jcl(sys.argv[2], int(sys.argv[3]), sys.argv[4])

    elif cmd == 'getlog' and len(sys.argv) == 5:
        ok = get_log_via_docker(sys.argv[2], sys.argv[3], sys.argv[4])
        sys.exit(0 if ok else 1)

    elif cmd == 'checkrc' and len(sys.argv) == 4:
        rc = check_rc_via_docker(sys.argv[2], sys.argv[3])
        print(f"MAXCC: {rc}")
        if rc < 0:
            print("Job output not found — still running or not submitted.")
            sys.exit(1)
        elif rc <= 4:
            print("BUILD SUCCESS")
            sys.exit(0)
        else:
            print("BUILD FAILED")
            sys.exit(1)
    else:
        print(__doc__)
        sys.exit(1)
