pipeline {
    agent { label "slave:${distribution}" }
    stages {
        stage("Initialization") {
            steps {
                buildName "#${BUILD_NUMBER} ${distribution}:${architecture}"
            }
        }
        stage('clean workspace') {
            steps {
                deleteDir()
            }
        }
        stage('copy artifacts') {
            steps {
                copyArtifacts filter: '*.gz,*.bz2,*.xz,*.dsc,*.changes', fingerprintArtifacts: true, projectName: '{{ name }}-source', selector: buildParameter('BUILD_SELECTOR')
            }
        }
{%- if debian_profiles is defined %}
        stage('debian profile') {
            steps {
                script {
                    def profile = sh(returnStdout: true, script: '{{ debian_profiles }}')
                    env.DEB_BUILD_PROFILES=profile.trim()
                }
            }
        }
{%- endif %}
        stage('Build') {
            steps {
                sh '/home/admin/kamailio-deb-jenkins/scripts/jdg-build-package'
            }
            post {
                success {
                    sh 'mkdir -p report'
                    sh '/usr/bin/lintian-junit-report --skip-lintian --filename *.lintian.txt *.lintian.txt > report/lintian.xml'
                    sh 'mkdir -p report adt'
                    sh 'touch adt/summary # do not fail if no autopkgtest run took place'
                    sh '/usr/bin/adtsummary_tap adt/summary > report/autopkgtest.tap'
                }
            }
        }
        stage('store artifacts') {
            steps {
                archiveArtifacts artifacts: '**/*.gz,**/*.bz2,**/*.xz,**/*.deb,**/*.ddeb,**/*.dsc,**/*.changes,**/*.buildinfo,**/*lintian.txt', fingerprint: true, followSymlinks: false
            }
        }
        stage('trigger repos') {
            steps {
                build wait: false, propagate: false, job: '{{ name }}-repos', parameters: [string(name: 'distribution', value: "${distribution}"), string(name: 'architecture', value: "${architecture}")]
            }
        }
    }
    post {
        failure {
            emailext body: '{{ email_body }}',
                    to: '{{ email }}',
                    subject: 'Build failed in Jenkins: $PROJECT_NAME - #$BUILD_NUMBER'
        }
    }
}
