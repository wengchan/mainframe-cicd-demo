      ******************************************************************
      * PROGRAM:    MYPROG
      * PURPOSE:    PAYROLL BATCH CALCULATOR
      *             READS EMPLOYEE RECORDS FROM EMPIN
      *             CALCULATES GROSS PAY (HOURS * RATE)
      *             WRITES FORMATTED REPORT TO EMPOUT
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MYPROG.
       AUTHOR. CICD-DEMO.
       DATE-WRITTEN. 2026-05-01.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EMP-FILE ASSIGN TO EMPIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.
           SELECT RPT-FILE ASSIGN TO EMPOUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.

      * INPUT: 80-byte fixed employee record
       FD  EMP-FILE
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 80 CHARACTERS.
       01  EMP-RECORD.
           05  EMP-NAME          PIC X(20).
           05  EMP-HOURS         PIC 999V99.
           05  EMP-RATE          PIC 9999V99.
           05  FILLER            PIC X(49).

      * OUTPUT: 133-byte print line (standard mainframe print width)
       FD  RPT-FILE
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 133 CHARACTERS.
       01  RPT-LINE              PIC X(133).

       WORKING-STORAGE SECTION.
       01  WS-EOF-FLAG           PIC X(1)    VALUE 'N'.
           88  END-OF-FILE                   VALUE 'Y'.

       01  WS-GROSS-PAY          PIC 9(6)V99 VALUE ZEROS.
       01  WS-TOTAL-PAY          PIC 9(8)V99 VALUE ZEROS.
       01  WS-REC-COUNT          PIC 9(5)    VALUE ZEROS.
       01  WS-RETURN-CODE        PIC 9(4)    VALUE ZEROS.

      * Report header line
       01  WS-HEADER.
           05  FILLER  PIC X(1)  VALUE ' '.
           05  FILLER  PIC X(20) VALUE 'EMPLOYEE NAME'.
           05  FILLER  PIC X(8)  VALUE '  HOURS'.
           05  FILLER  PIC X(10) VALUE '     RATE'.
           05  FILLER  PIC X(12) VALUE '  GROSS PAY'.
           05  FILLER  PIC X(82) VALUE SPACES.

      * Detail line per employee
       01  WS-DETAIL.
           05  FILLER          PIC X(1)   VALUE ' '.
           05  WS-DET-NAME     PIC X(20).
           05  WS-DET-HOURS    PIC ZZZ.99.
           05  FILLER          PIC X(2)   VALUE SPACES.
           05  WS-DET-RATE     PIC $Z,ZZZ.99.
           05  FILLER          PIC X(2)   VALUE SPACES.
           05  WS-DET-GROSS    PIC $ZZ,ZZZ.99.
           05  FILLER          PIC X(81)  VALUE SPACES.

      * Totals line
       01  WS-TOTALS.
           05  FILLER          PIC X(1)   VALUE ' '.
           05  FILLER          PIC X(16)  VALUE 'RECORDS READ:'.
           05  WS-TOT-COUNT    PIC ZZ,ZZ9.
           05  FILLER          PIC X(5)   VALUE SPACES.
           05  FILLER          PIC X(14)  VALUE 'TOTAL PAYROLL:'.
           05  WS-TOT-PAY      PIC $ZZZ,ZZZ.99.
           05  FILLER          PIC X(84)  VALUE SPACES.

       01  WS-ERROR-MSG.
           05  FILLER          PIC X(20) VALUE 'FILE STATUS ERROR - '.
           05  WS-ERR-STATUS   PIC X(2).
           05  FILLER          PIC X(111) VALUE SPACES.

       PROCEDURE DIVISION.
       0000-MAIN.
           OPEN INPUT  EMP-FILE
                OUTPUT RPT-FILE.
           WRITE RPT-LINE FROM WS-HEADER.
           PERFORM 1000-READ-LOOP UNTIL END-OF-FILE.
           PERFORM 9000-TOTALS.
           CLOSE EMP-FILE
                 RPT-FILE.
           MOVE WS-RETURN-CODE TO RETURN-CODE.
           STOP RUN.

       1000-READ-LOOP.
           READ EMP-FILE INTO EMP-RECORD
               AT END MOVE 'Y' TO WS-EOF-FLAG.
           IF NOT END-OF-FILE
               PERFORM 2000-PROCESS-RECORD.

       2000-PROCESS-RECORD.
           COMPUTE WS-GROSS-PAY = EMP-HOURS * EMP-RATE.
           ADD WS-GROSS-PAY TO WS-TOTAL-PAY.
           ADD 1            TO WS-REC-COUNT.
           MOVE EMP-NAME    TO WS-DET-NAME.
           MOVE EMP-HOURS   TO WS-DET-HOURS.
           MOVE EMP-RATE    TO WS-DET-RATE.
           MOVE WS-GROSS-PAY TO WS-DET-GROSS.
           WRITE RPT-LINE FROM WS-DETAIL.

       9000-TOTALS.
           MOVE WS-REC-COUNT  TO WS-TOT-COUNT.
           MOVE WS-TOTAL-PAY  TO WS-TOT-PAY.
           WRITE RPT-LINE FROM WS-TOTALS.
