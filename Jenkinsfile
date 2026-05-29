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
            steps {
                // Run Jest inside a temporary Node container that shares the host
                // network so it can reach the dev PostgreSQL and MinIO on the homelab.
                // The dev .env.local on the host is bind-mounted read-only.
                sh '''
                    set -e
                    docker run --rm \
                        --network host \
                        -v "$APP_DIR/src/s3-ui:/app" \
                        -v "$APP_DIR/src/s3-ui/.env.local:/app/.env.local:ro" \
                        -w /app \
                        node:20-alpine \
                        sh -c "npm ci --prefer-offline && npx jest --ci --forceExit"
                '''
            }
        }

        stage('Build & Deploy') {
            steps {
                sh '''
                    set -e
                    cd "$APP_DIR/src/s3-ui"
                    docker compose --env-file "$ENV_FILE" -f docker-compose.prod.yml up -d --build --wait --wait-timeout 180
                '''
            }
        }

        stage('Migrate') {
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
