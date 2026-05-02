//UPLOADSRC JOB (0000),'UPLOAD SOURCE',
//             CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//             USER=HERC01,PASSWORD=CUL8TR,
//             NOTIFY=HERC01
//*
//* ============================================================
//* LOAD COBOL SOURCE INTO HERC01.CICD.COBOL PDS USING IEBUPDTE
//*
//* IEBUPDTE is a standard IBM utility that updates PDS members.
//* The ./ ADD control statement creates/replaces a member.
//* Source lines follow immediately after the control statement.
//* ============================================================
//IEBUPDTE EXEC PGM=IEBUPDTE,PARM=NEW
//SYSPRINT DD  SYSOUT=*
//SYSUT2   DD  DSN=HERC01.CICD.COBOL,DISP=SHR
//SYSIN    DD  DATA,DLM=$$
./ ADD NAME=MYPROG,LIST=ALL
@@COBOL_SOURCE@@
$$
