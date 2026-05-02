//ALLOCDS  JOB (0000),'ALLOC DATASETS',
//             CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//             USER=HERC01,PASSWORD=CUL8TR,
//             NOTIFY=HERC01
//*
//* ============================================================
//* RUN THIS ONCE TO SET UP REQUIRED DATASETS ON TK4-
//* BEFORE RUNNING THE CI/CD PIPELINE
//* ============================================================
//*
//***********************************************************
//* DELETE OLD DATASETS IF THEY EXIST (IGNORE ERRORS)
//***********************************************************
//CLEANUP  EXEC PGM=IEFBR14
//DEL1     DD  DSN=HERC01.CICD.COBOL,
//             DISP=(MOD,DELETE,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,1)
//DEL2     DD  DSN=HERC01.CICD.LOAD,
//             DISP=(MOD,DELETE,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,1)
//DEL3     DD  DSN=HERC01.CICD.DATA,
//             DISP=(MOD,DELETE,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,1)
//*
//***********************************************************
//* ALLOCATE SOURCE PDS  (LRECL=80  RECFM=FB)
//***********************************************************
//ALLOC1   EXEC PGM=IEFBR14
//COBOL    DD  DSN=HERC01.CICD.COBOL,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,
//             SPACE=(TRK,(5,5,10)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=3120)
//*
//***********************************************************
//* ALLOCATE LOAD LIBRARY (RECFM=U - REQUIRED FOR LOAD MODS)
//***********************************************************
//ALLOC2   EXEC PGM=IEFBR14
//LOAD     DD  DSN=HERC01.CICD.LOAD,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,
//             SPACE=(TRK,(5,5,10)),
//             DCB=(RECFM=U,LRECL=0,BLKSIZE=6144)
//*
//***********************************************************
//* ALLOCATE DATA PDS    (LRECL=80  RECFM=FB)
//***********************************************************
//ALLOC3   EXEC PGM=IEFBR14
//DATA     DD  DSN=HERC01.CICD.DATA,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,
//             SPACE=(TRK,(2,2,5)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=3120)
