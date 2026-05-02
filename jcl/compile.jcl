//CICDDEMO JOB (0000),'CICD DEMO',
//             CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//             USER=HERC01,PASSWORD=CUL8TR,
//             NOTIFY=HERC01
//*
//* ============================================================
//* MAINFRAME CI/CD DEMO - COMPILE, LINK, AND RUN MYPROG
//*
//* STEP1 - COBOL COMPILE  (IKFCBL00)
//* STEP2 - LINK EDIT      (IEWL)
//* STEP3 - EXECUTE        (MYPROG) WITH INLINE TEST DATA
//*
//* PREREQ DATASETS (allocate once via ALLOCDS.jcl):
//*   HERC01.CICD.COBOL  - PDS LRECL=80  RECFM=FB (source)
//*   HERC01.CICD.LOAD   - PDS LRECL=0   RECFM=U  (load modules)
//*   HERC01.CICD.DATA   - PDS LRECL=80  RECFM=FB (test data)
//* ============================================================
//*
//***********************************************************
//* STEP 1: COMPILE COBOL SOURCE
//***********************************************************
//COMPILE  EXEC PGM=IKFCBL00,
//             PARM='APOST,LOAD,NOTRUNC,NOOPT'
//STEPLIB  DD  DSN=SYS1.COBLIB,DISP=SHR
//SYSPRINT DD  SYSOUT=*
//SYSPUNCH DD  DUMMY
//SYSIN    DD  DSN=HERC01.CICD.COBOL(MYPROG),DISP=SHR
//SYSLIN   DD  DSN=&&LOADSET,
//             DISP=(NEW,PASS),
//             UNIT=SYSDA,
//             SPACE=(TRK,(5,5))
//*
//***********************************************************
//* STEP 2: LINK-EDIT OBJECT INTO LOAD MODULE
//***********************************************************
//LKED     EXEC PGM=IEWL,
//             PARM='LIST,LET,MAP,NCAL',
//             COND=(8,LT,COMPILE)
//SYSLIN   DD  DSN=&&LOADSET,DISP=(OLD,DELETE)
//         DD  *
 ENTRY MYPROG
/*
//SYSLMOD  DD  DSN=HERC01.CICD.LOAD(MYPROG),DISP=SHR
//SYSPRINT DD  SYSOUT=*
//SYSUT1   DD  UNIT=SYSDA,SPACE=(TRK,(5,5))
//*
//***********************************************************
//* STEP 3: EXECUTE - INLINE TEST DATA IN SYSIN/EMPIN
//***********************************************************
//GO       EXEC PGM=MYPROG,
//             COND=(8,LT,LKED)
//STEPLIB  DD  DSN=HERC01.CICD.LOAD,DISP=SHR
//EMPIN    DD  *
JOHN SMITH          04000010050
JANE DOE            03750015000
BOB JOHNSON         04500012075
ALICE WILLIAMS      04000020000
CHARLIE BROWN       03500009050
/*
//EMPOUT   DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
