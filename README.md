# # IronPipe — Mainframe CI/CD Pipeline 

A working CI/CD pipeline that automates COBOL source upload, compilation, link-edit, and execution on a z/OS (MVS) mainframe environment — built entirely with free tools.

**Stack:** TK4- (Hercules MVS 3.8j emulator) · Jenkins · Python · JES2 · OS/VS COBOL

---

## What This Project Demonstrates

Standard CI/CD tools assume a Unix filesystem. Mainframe CI/CD is fundamentally different and requires domain-specific knowledge to automate. This project solves every problem from source upload to job result checking without any paid tooling.

| Mainframe-Specific Problem | Why It Exists | How This Project Solves It |
|---|---|---|
| Source lives in PDS datasets, not files | MVS uses `HLQ.LIB(MEMBER)` partitioned datasets, not flat file paths | IEBUPDTE (IBM standard utility) loads source into the PDS via JCL submission |
| No shell commands to compile | Compilation is a multi-step batch job submitted to JES2, not a `javac`/`gcc` call | JCL job with COMPILE → LKED → GO steps submitted via Hercules 3505 card reader socket |
| No process exit codes | Jobs return MAXCC (max condition code across all steps), not Unix RC | `check_job_rc.sh` parses printer spool output for MAXCC and ABEND codes |
| ABEND ≠ non-zero RC | Program crashes (S0C7, S806, S013) appear as ABEND codes, not MAXCC | Script checks both ABEND patterns and MAXCC separately |
| RACF/RAKF security | Dataset access requires an authenticated user on the JOB card | `USER=HERC01,PASSWORD=CUL8TR` on every JCL JOB statement |
| Conditional step execution | JCL COND parameter logic is inverse: `COND=(8,LT,step)` means "skip if 8 < previous RC" | Documented in compile.jcl so the skip behaviour is visible and testable |
| DCB metadata required | Every dataset needs RECFM, LRECL, BLKSIZE declared at allocation time | allocds.jcl allocates all three PDS libraries with correct DCB before the pipeline runs |

---

## Architecture

```
Developer edits MYPROG.cbl → commits to Git
                │
                ▼
         Jenkins Pipeline
                │
    ┌───────────┼────────────────────────────┐
    │           │                            │
    ▼           ▼                            ▼
Stage 1     Stage 2                      Stage 3
Upload      Submit                       Poll &
Source      Compile JCL                  Check RC
    │           │                            │
    │    mvs_submit.py                 check_job_rc.sh
    │    → TCP socket → port 3505      → docker exec
    │    → JES2 internal reader        → reads prt/prt00e.txt
    │    → COMPILE (IKFCBL00)          → checks MAXCC / ABEND
    │    → LKED   (IEWL)                    │
    │    → GO     (MYPROG)                  ▼
    │                               Stage 4: Archive
    ▼                               job_output.txt
TK4- / MVS 3.8j
(Hercules emulator in Docker)
```

---

## Project Structure

```
mainframe-cicd-demo/
│
├── cobol/
│   └── MYPROG.cbl          OS/VS COBOL payroll batch program
│                           Fixed-format 80-byte records, COMPUTE gross pay,
│                           formatted report output — COBOL-74 compatible
│
├── jcl/
│   ├── allocds.jcl         One-time dataset setup (run before first pipeline)
│   │                       Allocates HERC01.CICD.COBOL / .LOAD / .DATA PDS
│   │                       with correct RECFM/LRECL/BLKSIZE per library type
│   │
│   ├── upload_src.jcl      IEBUPDTE job template — populates HERC01.CICD.COBOL(MYPROG)
│   │                       @@COBOL_SOURCE@@ placeholder replaced by mvs_submit.py
│   │                       at submission time with the actual source from Git
│   │
│   └── compile.jcl         3-step JCL job:
│                             STEP1 COMPILE  EXEC PGM=IKFCBL00  (OS/VS COBOL compiler)
│                             STEP2 LKED     EXEC PGM=IEWL      (linkage editor)
│                             STEP3 GO       EXEC PGM=MYPROG    (execute with test data)
│                           COND=(8,LT,prev) skips downstream steps on failure
│
├── scripts/
│   ├── mvs_submit.py       Python FTP/socket helper — no ftp shell command needed
│   │                       submit  → sends JCL to Hercules 3505 card reader socket
│   │                       upload  → merges source into IEBUPDTE template, submits
│   │                       getlog  → reads printer spool via docker exec
│   │                       checkrc → parses MAXCC and ABEND codes, exits 0 or 1
│   │
│   └── check_job_rc.sh     Polls spool every 15s (up to 5 min), calls mvs_submit.py
│                           checkrc, prints output, exits non-zero on failure
│
├── Jenkinsfile             Declarative pipeline — 4 stages
│                           Credentials: mvs-host, mvs-port, mvs-user, mvs-pass
│                           stored in Jenkins Secret Text, never hardcoded
│
└── README.md               This file
```

---

## COBOL Application: MYPROG

A batch payroll calculator — a realistic example of the kind of program found in production mainframe shops.

**What it does:** Reads employee records from EMPIN, calculates gross pay (HOURS × RATE), writes a formatted report to EMPOUT, prints record count and total payroll.

**Input record layout (80-byte fixed format):**

```
Columns  1–20   Employee name      PIC X(20)
Columns 21–25   Hours worked       PIC 999V99   e.g. 04000 = 40.00 hrs
Columns 26–32   Hourly rate        PIC 9999V99  e.g. 0010050 = $100.50
Columns 33–80   Filler
```

**Test data (inline in JCL EMPIN DD):**
```
JOHN SMITH          04000010050
JANE DOE            03750015000
BOB JOHNSON         04500012075
ALICE WILLIAMS      04000020000
CHARLIE BROWN       03500009050
```

**Expected report output (EMPOUT SYSOUT):**
```
 EMPLOYEE NAME           HOURS     RATE    GROSS PAY
 JOHN SMITH             40.00   $100.50   $4,020.00
 JANE DOE               37.50   $150.00   $5,625.00
 BOB JOHNSON            45.00   $120.75   $5,433.75
 ALICE WILLIAMS         40.00   $200.00   $8,000.00
 CHARLIE BROWN          35.00   $90.50    $3,167.50
 RECORDS READ:      5     TOTAL PAYROLL: $26,216.75
```

The program is written in **OS/VS COBOL** (COBOL-74) — the dialect supported by the IKFCBL00 compiler on MVS 3.8j. This is intentional: it demonstrates awareness of compiler version differences, which matters in shops still running legacy COBOL.

---

## Infrastructure Setup (Free Tools Only)

### TK4- — MVS 3.8j Emulator

TK4- is a pre-configured Hercules + MVS 3.8j system. No mainframe hardware or IBM license required.

```bash
# Run TK4- in Docker (port 3270 = TN3270 terminal, 3505 = JES card reader)
docker run -d \
  --name mvs-tk4 \
  -p 3270:3270 \
  -p 8038:8038 \
  -p 3505:3505 \
  maussner/mvs-tk4

# Wait ~10 minutes for MVS to IPL (boot)
# Check the Hercules web console at http://localhost:8038
```

Default TSO credentials: `HERC01 / CUL8TR`

**Ports:**
| Port | Purpose |
|---|---|
| 3270 | TN3270 terminal (c3270, x3270, IBM Personal Communications) |
| 8038 | Hercules web console — shows MVS system log |
| 3505 | JES2 internal reader — job submission via raw TCP socket |

### Jenkins

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts
```

**Required plugins:** Pipeline, Credentials Binding, Git

**Credentials to add** (Manage Jenkins → Credentials → Global → Secret Text):

| Credential ID | Value | Purpose |
|---|---|---|
| `mvs-host` | `host.docker.internal` | TK4- hostname reachable from Jenkins container |
| `mvs-port` | `3505` | JES2 card reader port |
| `mvs-user` | `HERC01` | MVS user for RAKF authentication |
| `mvs-pass` | `CUL8TR` | MVS password |

---

## Running the Pipeline

### Step 1 — Allocate MVS datasets (one time only)

```bash
python3 scripts/mvs_submit.py submit 127.0.0.1 3505 jcl/allocds.jcl
```

This creates three PDS libraries on the MVS system:
- `HERC01.CICD.COBOL` — RECFM=FB, LRECL=80 (COBOL source)
- `HERC01.CICD.LOAD`  — RECFM=U (load modules / executables)
- `HERC01.CICD.DATA`  — RECFM=FB, LRECL=80 (test data)

### Step 2 — Trigger the Jenkins pipeline

Push any change to `cobol/MYPROG.cbl`. Jenkins will run all 4 stages automatically:

```
Stage 1 — Upload Source     mvs_submit.py upload → IEBUPDTE JCL → HERC01.CICD.COBOL(MYPROG)
Stage 2 — Submit Compile    mvs_submit.py submit → JES2 card reader → CICDDEMO job
Stage 3 — Check Result      check_job_rc.sh → polls spool → checks MAXCC / ABEND
Stage 4 — Archive Output    job_output.txt saved as Jenkins build artifact
```

Build passes if `MAXCC <= 4`. Build fails on `MAXCC >= 8` or any ABEND code.

---

## Key MVS Concepts in This Project

**JES2 internal reader (port 3505)**
The Hercules 3505 sockdev is a virtual card reader connected to JES2. Any text sent to the port is treated as punched cards and submitted as a batch job immediately — no FTP, no ISPF needed. This is how automation tools submit work on systems without modern TCP/IP stacks.

**MAXCC vs ABEND**
MVS batch jobs report two distinct failure modes. MAXCC is the highest condition code (RC) returned by any step — non-zero doesn't always mean failure (RC=4 is warnings). ABEND is an abnormal end: the program crashed. Common ABENDs: S0C7 (bad numeric data), S806 (module not found), S013 (dataset DCB mismatch). An ABEND produces no MAXCC, so both must be checked independently.

**COND parameter (inverse logic)**
`COND=(8,LT,COMPILE)` does NOT mean "skip if COMPILE RC < 8". It means "skip this step if the condition 8 LT [previous RC] is true" — i.e., skip if 8 is less than the COMPILE RC, meaning skip if COMPILE RC > 8. The logic is inverted compared to every modern CI/CD tool. This is a classic source of JCL bugs in mainframe shops.

**IEBUPDTE**
IBM standard utility for adding or updating PDS members. Used here to load COBOL source from an inline JCL stream into `HERC01.CICD.COBOL(MYPROG)`. The `./ ADD NAME=MYPROG` control statement tells IEBUPDTE to create or replace the member.

**DCB attributes**
Every MVS dataset must have RECFM (record format), LRECL (logical record length), and BLKSIZE (block size) declared at allocation. PDS source libraries use RECFM=FB LRECL=80 (80-byte fixed blocks). Load module libraries use RECFM=U (undefined) because load modules are not fixed-length records. Wrong DCB causes S013 ABEND on OPEN.

**RAKF (Resource Access Key Facility)**
TK4-'s simplified RACF equivalent. Controls which users can allocate, read, or update datasets. Jobs run under the user specified on the JOB card `USER=` parameter. Without it, the jobname is used as the user identity, which typically has no dataset permissions.

---

## Actual MVS Output From This Project

The following messages appeared during testing — real JES2 output from the running MVS system:

```
03.03.24 JOB    7  IEFACTRT - Stepname  Procstep  Program   Retcode
03.03.24 JOB    7  CICDDEMO   COMPILE             IKFCBL00  RC= 0000
03.03.24 JOB    7  CICDDEMO   LKED                IEWL      RC= 0000
03.03.24 JOB    7  CICDDEMO   GO                  MYPROG    RC= 0000
```

```
IEF285I   HERC01.CICD.COBOL    KEPT     VOL SER NOS= MVSCAT.
IEF285I   HERC01.CICD.LOAD     KEPT     VOL SER NOS= WORK02.
IEF374I STEP /COMPILE / STOP  CPU 0MIN 00.05SEC  VIRT 44K SYS 168K
```

```
****A  END  JOB  7  CICDDEMO  CICD DEMO  3.03 AM 02 MAY 26  SYS TK4-  END  A****
```

RAKF security, S013 ABEND (DCB mismatch), and IEF message codes were all encountered and resolved during development — documented in the troubleshooting section above.

---

## Troubleshooting

| Symptom | MVS Message | Cause | Fix |
|---|---|---|---|
| Dataset not created | `RAKF0005 INVALID ATTEMPT` | JOB card missing `USER=` | Add `USER=HERC01,PASSWORD=CUL8TR` to JOB statement |
| Compile step skipped | `IEF212I SYSIN DATA SET NOT FOUND` | Source not in PDS | Run upload step first via `mvs_submit.py upload` |
| Compile ABEND | `S013` | DCB mismatch on SYSIN | Verify PDS allocated with RECFM=FB LRECL=80 |
| Link step flushed | `*FLUSH*` after compile failure | COND skipped LKED | Fix compile errors first — check SYSPRINT in spool |
| Program ABEND | `S0C7` | Bad numeric data in EMPIN | Check column alignment of input records |
| Module not found | `S806` | Link step produced no load module | Confirm LKED step RC=0 before running GO |
| Job not appearing | No output in printer file | MVS still booting | Wait for TK4- to fully IPL — check `http://localhost:8038` |
