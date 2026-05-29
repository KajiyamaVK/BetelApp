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
            // Only run the full pipeline on main — prevents any other branch or fork
            // from executing deploy/migrate stages with prod credentials.
            // GIT_BRANCH is set by the Git plugin in regular pipeline jobs (unlike
            // BRANCH_NAME which only exists in Multibranch Pipelines).
            when { expression { env.GIT_BRANCH == 'origin/main' } }
            steps {
                // Sync Jenkins workspace to the host APP_DIR.
                // .env* are host-managed secrets — never overwrite them.
                // node_modules and .next are rebuilt by Docker, not synced.
                sh '''
                    set -e
                    rsync -a --delete \
                        --exclude='.env*' \
                        --exclude='node_modules' \
                        --exclude='.next' \
                        "$WORKSPACE/" "$APP_DIR/"
                '''
            }
        }

        stage('Test') {
            when { expression { env.GIT_BRANCH == 'origin/main' } }
            steps {
                // Run Jest inside a temporary Node container.
                // Uses a dedicated docker bridge network with access to dev DB/MinIO
                // via the homelab's internal hostname — never --network host,
                // which would expose all host ports to attacker-controlled npm scripts.
                sh '''
                    set -e
                    docker network inspect betelsas-test 2>/dev/null || \
                        docker network create betelsas-test

                    HOMELAB_IP=$(getent hosts homelab | awk '{print $1}' | head -1)
                    MINIO_IP=$(getent hosts s3.kajiyama.com.br | awk '{print $1}' | head -1)

                    # Pass commands via env var to avoid all sh/Groovy quoting issues
                    TEST_CMD="set -e; npm ci --prefer-offline; npx jest --ci --forceExit"

                    docker run --rm \
                        --network betelsas-test \
                        --add-host=homelab:${HOMELAB_IP} \
                        --add-host=s3.kajiyama.com.br:${MINIO_IP} \
                        -e "TEST_CMD=${TEST_CMD}" \
                        -v "$APP_DIR/src/s3-ui:/app" \
                        -v "$APP_DIR/src/s3-ui/.env.local:/app/.env.local:ro" \
                        -w /app \
                        node:20-alpine \
                        sh -c "$TEST_CMD"
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
