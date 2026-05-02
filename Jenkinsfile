pipeline {
    agent any

    // Credentials stored in Jenkins > Manage Jenkins > Credentials > Global
    //   mvs-host → host.docker.internal  (TK4- reachable from Jenkins container)
    //   mvs-port → 3505                  (Hercules JES2 card reader socket)
    //   mvs-user → HERC01                (kept for reference / future FTP use)
    //   mvs-pass → CUL8TR                (kept for reference / future FTP use)
    environment {
        MVS_HOST      = credentials('mvs-host')
        MVS_PORT      = credentials('mvs-port')
        MVS_USER      = credentials('mvs-user')
        MVS_PASS      = credentials('mvs-pass')
        MVS_CONTAINER = 'mvs-tk4'
        JOB_NAME      = 'CICDDEMO'
    }

    stages {

        // -------------------------------------------------------
        stage('Checkout') {
        // -------------------------------------------------------
            steps {
                checkout scm
                echo "Source: ${env.GIT_COMMIT?.take(7) ?: 'local'}"
            }
        }

        // -------------------------------------------------------
        stage('Upload COBOL Source to MVS') {
        // -------------------------------------------------------
        // Uses IEBUPDTE (standard IBM utility) to load MYPROG.cbl
        // into the PDS HERC01.CICD.COBOL(MYPROG) via inline JCL.
        // Source is embedded in the JCL submission — no FTP needed.
        // -------------------------------------------------------
            steps {
                sh '''
                    python3 scripts/mvs_submit.py upload \
                        "$MVS_HOST" "$MVS_PORT" \
                        jcl/upload_src.jcl cobol/MYPROG.cbl
                '''
                sh 'sleep 15'
            }
        }

        // -------------------------------------------------------
        stage('Submit Compile JCL') {
        // -------------------------------------------------------
        // Sends JCL to the Hercules 3505 card reader socket.
        // The sockdev acts as a JES2 internal reader — any text
        // sent to the port is submitted as a batch job immediately.
        // -------------------------------------------------------
            steps {
                sh '''
                    python3 scripts/mvs_submit.py submit \
                        "$MVS_HOST" "$MVS_PORT" \
                        jcl/compile.jcl
                '''
            }
        }

        // -------------------------------------------------------
        stage('Wait and Check Job Result') {
        // -------------------------------------------------------
        // Polls the TK4- printer spool files via docker exec.
        // TK4- writes SYSOUT to text files on the Hercules host.
        // Checks MAXCC — anything >= 8 is a build failure.
        // -------------------------------------------------------
            steps {
                sh 'chmod +x scripts/check_job_rc.sh'
                sh '''
                    scripts/check_job_rc.sh \
                        "$MVS_CONTAINER" "$JOB_NAME"
                '''
            }
        }

        // -------------------------------------------------------
        stage('Archive Job Output') {
        // -------------------------------------------------------
            steps {
                sh '''
                    python3 scripts/mvs_submit.py getlog \
                        "$MVS_CONTAINER" "$JOB_NAME" job_output.txt || true
                '''
                archiveArtifacts artifacts: 'job_output.txt',
                                 allowEmptyArchive: true
            }
        }
    }

    post {
        success {
            echo "SUCCESS — MYPROG compiled and executed on TK4-"
        }
        failure {
            echo "FAILED — check job_output.txt for MAXCC / ABEND details"
        }
    }
}
