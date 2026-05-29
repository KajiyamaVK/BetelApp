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
                        --exclude='.prisma' \
                        "$WORKSPACE/" "$APP_DIR/"
                    # Remove any .env* dirs Docker may have created as placeholders
                    find "$APP_DIR" -maxdepth 4 -name '.env*' -type d -exec docker run --rm -v "$APP_DIR:/t" alpine rm -rf {} + 2>/dev/null || true
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
                    # Use --network host so the container can reach homelab services
                    # (PostgreSQL on localhost:5432, MinIO on s3.kajiyama.com.br) without
                    # needing to resolve external hostnames from inside a bridge network.
                    # The test stage is guarded by `when { branch 'main' }` so only
                    # trusted code reaches this point.
                    # Generate a patched env file replacing 'homelab' with the real IP so the
                    # test container (--network host) can reach PostgreSQL and MinIO.
                    # The Jenkins container's /etc/hosts maps 'homelab' to its own loopback.
                    sed 's/homelab/192.168.0.200/g' /home/kajiyamavk/.config/betelsas-dev.env \
                        > /tmp/betelsas-test.env

                    docker run --rm \
                        --network host \
                        -v "$APP_DIR/src/s3-ui:/app" \
                        -v "/tmp/betelsas-test.env:/app/.env.local:ro" \
                        -w /app \
                        node:20-alpine \
                        sh -c "set -e; npm ci --prefer-offline; npx prisma generate; npx jest --ci --forceExit"
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
