#!/usr/bin/env python3
"""
mvs_ftp.py — FTP helper for MVS/TK4- operations.
Replaces the `ftp` shell command which is not available on all systems.

Usage:
  python3 mvs_ftp.py upload  <host> <user> <pass> <local_file> <mvs_dataset>
  python3 mvs_ftp.py submit  <host> <user> <pass> <local_jcl>
  python3 mvs_ftp.py getlog  <host> <user> <pass> <jobname>    <output_file>
  python3 mvs_ftp.py listjob <host> <user> <pass> <jobname>

Exit codes: 0 = success, 1 = failure
"""

import sys
import ftplib
import os

# MVS_FTP_PORT env var lets callers override the port without changing scripts.
# Default 21 (standard FTP); set to 2121 when TK4- runs in Docker.
MVS_FTP_PORT = int(os.environ.get("MVS_FTP_PORT", "21"))

def ftp_connect(host, user, password):
    ftp = ftplib.FTP()
    ftp.connect(host, MVS_FTP_PORT, timeout=30)
    ftp.login(user, password)
    return ftp

def upload_source(host, user, password, local_file, mvs_dataset):
    """Upload a text file into a PDS member, setting DCB attributes via SITE."""
    print(f"Uploading {local_file} -> {mvs_dataset}")
    ftp = ftp_connect(host, user, password)
    # SITE sets MVS dataset attributes: RECFM=FB LRECL=80 BLKSIZE=3120
    ftp.sendcmd("SITE RECFM=FB LRECL=80 BLKSIZE=3120")
    with open(local_file, 'rb') as f:
        ftp.storlines(f"STOR {mvs_dataset}", f)
    ftp.quit()
    print("Upload complete.")

def submit_jcl(host, user, password, local_jcl):
    """Submit a JCL file to JES2 via FTP internal reader mode."""
    print(f"Submitting JCL: {local_jcl}")
    ftp = ftp_connect(host, user, password)
    # Switch to JES mode — STOR in this mode submits to JES internal reader
    ftp.sendcmd("SITE FILETYPE=JES")
    jcl_name = os.path.basename(local_jcl)
    with open(local_jcl, 'rb') as f:
        resp = ftp.storlines(f"STOR {jcl_name}", f)
    print(f"JES response: {resp}")
    ftp.quit()

def get_job_log(host, user, password, jobname, output_file):
    """Retrieve job spool output from JES2 to a local file."""
    print(f"Retrieving spool for job: {jobname}")
    ftp = ftp_connect(host, user, password)
    ftp.sendcmd("SITE FILETYPE=JES")
    lines = []
    def collect(line):
        lines.append(line)
    try:
        ftp.retrlines(f"RETR {jobname}", collect)
    except ftplib.error_perm as e:
        print(f"FTP error: {e}")
        ftp.quit()
        sys.exit(1)
    ftp.quit()
    with open(output_file, 'w') as f:
        f.write('\n'.join(lines))
    print(f"Spool saved to: {output_file}")

def list_job(host, user, password, jobname):
    """List jobs matching jobname in JES spool. Returns 0 if found."""
    ftp = ftp_connect(host, user, password)
    ftp.sendcmd("SITE FILETYPE=JES")
    results = []
    ftp.retrlines(f"LIST {jobname}*", results.append)
    ftp.quit()
    if results:
        for r in results:
            print(r)
        return 0
    else:
        print(f"No jobs found matching: {jobname}")
        return 1

if __name__ == '__main__':
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)

    cmd  = sys.argv[1]
    host = sys.argv[2]
    user = sys.argv[3]
    pw   = sys.argv[4]

    if cmd == 'upload' and len(sys.argv) == 7:
        upload_source(host, user, pw, sys.argv[5], sys.argv[6])
    elif cmd == 'submit' and len(sys.argv) == 6:
        submit_jcl(host, user, pw, sys.argv[5])
    elif cmd == 'getlog' and len(sys.argv) == 7:
        get_job_log(host, user, pw, sys.argv[5], sys.argv[6])
    elif cmd == 'listjob' and len(sys.argv) == 6:
        rc = list_job(host, user, pw, sys.argv[5])
        sys.exit(rc)
    else:
        print(__doc__)
        sys.exit(1)
