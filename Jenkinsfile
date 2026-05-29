pipeline {
    agent any

    triggers {
        githubPush()
    }

    environment {
        APP_DIR  = '/home/kajiyamavk/src/BetelSAS'
        ENV_FILE = "${APP_DIR}/src/s3-ui/.env.production"
    }

    stages {
        stage('Update Source') {
            // Only run on main — prevents other branches from deploying with prod credentials.
            // GIT_BRANCH is set by the Git plugin in regular pipeline jobs (unlike
            // BRANCH_NAME which only exists in Multibranch Pipelines).
            when { expression { env.GIT_BRANCH == 'origin/main' } }
            steps {
                // Sync Jenkins workspace to the host APP_DIR.
                // .env* and .ci are host-managed secrets — never overwrite them.
                // node_modules and .next are rebuilt by Docker, not synced.
                sh '''
                    set -e
                    rsync -a --delete \
                        --exclude='.env*' \
                        --exclude='.ci' \
                        --exclude='node_modules' \
                        --exclude='.next' \
                        --exclude='.prisma' \
                        "$WORKSPACE/" "$APP_DIR/"
                '''
            }
        }

        stage('Build & Deploy') {
            when { expression { env.GIT_BRANCH == 'origin/main' } }
            steps {
                sh '''
                    set -e
                    cd "$APP_DIR/src/s3-ui"
                    docker compose --env-file "$ENV_FILE" -f docker-compose.prod.yml up -d --build --wait --wait-timeout 180
                '''
            }
        }

        stage('Migrate') {
            when { expression { env.GIT_BRANCH == 'origin/main' } }
            steps {
                // Run Prisma migrate deploy against the production database.
                // Uses the prod env file — never touches the dev database.
                sh '''
                    set -e
                    cd "$APP_DIR/src/s3-ui"
                    docker compose --env-file "$ENV_FILE" -f docker-compose.prod.yml --profile migrate run --rm migrator
                '''
            }
        }
    }

    post {
        failure {
            echo 'Pipeline failed — deploy aborted. Check the logs above.'
        }
        success {
            echo 'BetelSAS s3-ui deployed successfully to production.'
        }
    }
}
