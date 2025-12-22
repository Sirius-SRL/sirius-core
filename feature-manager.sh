#!/bin/bash

# Sirius Feature Group Manager
# Manages multiple feature deployments with GROUP_ID routing
# Usage: ./feature-manager.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Paths
BASE_DIR="/srv/lonagi/projects/sirius"
BACKEND_PATH="$BASE_DIR/einvoice-fastapi"
FRONTEND_PATH="$BASE_DIR/einvoice2-nuxt3"
FEATURES_DIR="$BASE_DIR/.features"
NGINX_CONF_DIR="/srv/lonagi/nginx-proxy/vhost.d"

# Ensure features directory exists
mkdir -p "$FEATURES_DIR"

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  $1"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Load feature group info
load_feature() {
    local group_id=$1
    local feature_file="$FEATURES_DIR/$group_id.json"
    
    if [ -f "$feature_file" ]; then
        cat "$feature_file"
    else
        echo "{}"
    fi
}

# Save feature group info
save_feature() {
    local group_id=$1
    local backend_branch=$2
    local frontend_branch=$3
    local use_local_db=$4
    local created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local group_number=$(get_next_group_number)
    
    cat > "$FEATURES_DIR/$group_id.json" <<EOF
{
  "group_id": "$group_id",
  "backend_branch": "$backend_branch",
  "frontend_branch": "$frontend_branch",
  "use_local_db": "$use_local_db",
  "created_at": "$created_at",
  "group_number": $group_number,
  "backend_container": "sirius-md-api-feature-$group_id",
  "frontend_container": "sirius-md-feature-$group_id",
  "db_container": "mariadb-feature-$group_id",
  "backend_ip": "$(get_service_ip $group_number backend)",
  "frontend_ip": "$(get_service_ip $group_number frontend)",
  "worker_ip": "$(get_service_ip $group_number worker)",
  "scheduler_ip": "$(get_service_ip $group_number scheduler)",
  "redis_ip": "$(get_service_ip $group_number redis)",
  "rabbitmq_ip": "$(get_service_ip $group_number rabbitmq)",
  "mariadb_ip": "$(get_service_ip $group_number mariadb)",
  "url": "https://feature.md.sirius.expert/$group_id"
}
EOF
}

# Delete feature group info
delete_feature() {
    local group_id=$1
    rm -f "$FEATURES_DIR/$group_id.json"
}

# Get next available group number (second octet)
# Network allocation structure: 172.X.Y.Z
#   X (second octet)  = Group number for features (20, 21, 22, 23...)
#   Y (third octet)   = Environment (1=prod, 2=dev, 3=staging, 4=features)
#   Z (fourth octet)  = Service (.100=backend, .101=worker, .110=redis, etc.)
#
# Examples:
#   172.20.3.100 = staging backend (group=20, env=3, service=100)
#   172.20.4.100 = feature group #20 backend (group=20, env=4, service=100)
#   172.21.4.100 = feature group #21 backend (group=21, env=4, service=100)
get_next_group_number() {
    local last_group=19  # Start from 20
    for file in "$FEATURES_DIR"/*.json; do
        [ -f "$file" ] || continue
        local group_num=$(jq -r '.group_number' "$file" 2>/dev/null)
        [ -n "$group_num" ] && [ "$group_num" != "null" ] && [ "$group_num" -ge "$last_group" ] && last_group=$group_num
    done
    echo $((last_group + 1))
}

# Get IPs for specific services
# IP format: 172.GROUP.4.SERVICE
# Where:
#   GROUP = feature group number (20, 21, 22...)
#   4 = fixed third octet for features (staging=3, dev=2, prod=1)
#   SERVICE = service type (.100, .101, .110, etc.)
get_service_ip() {
    local group_number=$1
    local service=$2
    
    case $service in
        backend)    echo "172.$group_number.4.100" ;;
        worker)     echo "172.$group_number.4.101" ;;
        scheduler)  echo "172.$group_number.4.102" ;;
        redis)      echo "172.$group_number.4.110" ;;
        rabbitmq)   echo "172.$group_number.4.111" ;;
        mariadb)    echo "172.$group_number.4.112" ;;
        frontend)   echo "172.$group_number.4.120" ;;
        *)          echo "172.$group_number.4.199" ;;
    esac
}

# List all feature groups
list_features() {
    print_header "Active Feature Groups"
    
    if [ ! -d "$FEATURES_DIR" ] || [ -z "$(ls -A "$FEATURES_DIR" 2>/dev/null)" ]; then
        print_warning "No active feature groups found"
        return
    fi
    
    echo -e "${CYAN}GROUP_ID${NC}\t${CYAN}BACKEND${NC}\t\t${CYAN}FRONTEND${NC}\t\t${CYAN}DB${NC}\t${CYAN}URL${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    for file in "$FEATURES_DIR"/*.json; do
        [ -f "$file" ] || continue
        
        local group_id=$(jq -r '.group_id' "$file")
        local backend=$(jq -r '.backend_branch' "$file")
        local frontend=$(jq -r '.frontend_branch' "$file")
        local db=$(jq -r '.use_local_db' "$file")
        local url=$(jq -r '.url' "$file")
        
        local db_type="dev"
        [ "$db" = "true" ] && db_type="local"
        
        echo -e "${GREEN}$group_id${NC}\t${backend:0:15}...\t${frontend:0:15}...\t$db_type\t$url"
    done
    echo ""
}

# Show detailed info for a feature group
show_feature() {
    local group_id=$1
    local feature_file="$FEATURES_DIR/$group_id.json"
    
    if [ ! -f "$feature_file" ]; then
        print_error "Feature group '$group_id' not found"
        return 1
    fi
    
    print_header "Feature Group: $group_id"
    
    local backend=$(jq -r '.backend_branch' "$feature_file")
    local frontend=$(jq -r '.frontend_branch' "$feature_file")
    local db=$(jq -r '.use_local_db' "$feature_file")
    local created=$(jq -r '.created_at' "$feature_file")
    local url=$(jq -r '.url' "$feature_file")
    local group_number=$(jq -r '.group_number' "$feature_file")
    local backend_ip=$(jq -r '.backend_ip' "$feature_file")
    local frontend_ip=$(jq -r '.frontend_ip' "$feature_file")
    local worker_ip=$(jq -r '.worker_ip' "$feature_file")
    local scheduler_ip=$(jq -r '.scheduler_ip' "$feature_file")
    local redis_ip=$(jq -r '.redis_ip' "$feature_file")
    local rabbitmq_ip=$(jq -r '.rabbitmq_ip' "$feature_file")
    local mariadb_ip=$(jq -r '.mariadb_ip' "$feature_file")
    
    echo "📦 Group ID:       $group_id"
    echo "🌿 Backend:        $backend"
    echo "🎨 Frontend:       $frontend"
    echo "💾 Database:       $([ "$db" = "true" ] && echo "Local (mariadb-feature-$group_id)" || echo "Dev (mariadb-dev)")"
    echo "📅 Created:        $created"
    echo "🌐 URL:            $url"
    echo ""
    echo "🌐 Network:        172.$group_number.4.0/24 (Group #$group_number)"
    echo ""
    echo "📡 Service IPs:"
    echo "   Backend API:    $backend_ip"
    echo "   Worker:         $worker_ip"
    echo "   Scheduler:      $scheduler_ip"
    echo "   Frontend:       $frontend_ip"
    echo "   Redis:          $redis_ip"
    echo "   RabbitMQ:       $rabbitmq_ip"
    [ "$db" = "true" ] && echo "   MariaDB:        $mariadb_ip"
    echo ""
    
    # Check container status
    echo "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$group_id" || print_warning "No containers running"
    echo ""
}

# Create new feature group
create_feature() {
    print_header "Create New Feature Group"
    
    # Get GROUP_ID
    echo -n "Enter GROUP_ID (e.g., feat-123, bugfix-456): "
    read group_id
    
    # Validate GROUP_ID format
    if [[ ! "$group_id" =~ ^[a-z0-9-]+$ ]]; then
        print_error "Invalid GROUP_ID format. Use only lowercase letters, numbers, and hyphens."
        return 1
    fi
    
    # Check if already exists
    if [ -f "$FEATURES_DIR/$group_id.json" ]; then
        print_error "Feature group '$group_id' already exists!"
        return 1
    fi
    
    # Ask what to deploy
    echo ""
    echo "What to deploy?"
    echo "1) Backend only"
    echo "2) Frontend only"
    echo "3) Both backend and frontend"
    echo ""
    echo -n "Your choice (1/2/3, default: 3): "
    read deploy_choice
    deploy_choice=${deploy_choice:-3}
    
    local backend_branch="none"
    local frontend_branch="none"
    local use_local_db="false"
    
    # Backend configuration
    if [ "$deploy_choice" = "1" ] || [ "$deploy_choice" = "3" ]; then
        echo ""
        echo "Last 5 backend branches (by update date):"
        cd "$BACKEND_PATH"
        git fetch --all --quiet 2>/dev/null
        git for-each-ref --sort=-committerdate refs/remotes/origin --format='%(refname:short)' | sed 's/origin\///' | grep -v HEAD | head -5 | nl
        echo ""
        echo -n "Backend branch (default: dev): "
        read backend_branch
        backend_branch=${backend_branch:-dev}
        
        echo -n "Use local MariaDB? (y/n, default: n): "
        read use_db
        [ "$use_db" = "y" ] || [ "$use_db" = "Y" ] && use_local_db="true"
    fi
    
    # Frontend configuration
    if [ "$deploy_choice" = "2" ] || [ "$deploy_choice" = "3" ]; then
        echo ""
        echo "Last 5 frontend branches (by update date):"
        cd "$FRONTEND_PATH"
        git fetch --all --quiet 2>/dev/null
        git for-each-ref --sort=-committerdate refs/remotes/origin --format='%(refname:short)' | sed 's/origin\///' | grep -v HEAD | head -5 | nl
        echo ""
        echo -n "Frontend branch (default: dev): "
        read frontend_branch
        frontend_branch=${frontend_branch:-dev}
    fi
    
    # Save configuration
    save_feature "$group_id" "$backend_branch" "$frontend_branch" "$use_local_db"
    
    print_success "Feature group '$group_id' created"
    
    # Deploy
    echo ""
    echo -n "Deploy now? (y/n): "
    read deploy_now
    
    if [ "$deploy_now" = "y" ] || [ "$deploy_now" = "Y" ]; then
        deploy_feature "$group_id"
    else
        print_info "Run './feature-manager.sh deploy $group_id' to deploy later"
    fi
}

# Deploy feature group
deploy_feature() {
    local group_id=$1
    local feature_file="$FEATURES_DIR/$group_id.json"
    
    if [ ! -f "$feature_file" ]; then
        print_error "Feature group '$group_id' not found"
        return 1
    fi
    
    print_header "Deploying Feature Group: $group_id"
    
    local backend_branch=$(jq -r '.backend_branch' "$feature_file")
    local frontend_branch=$(jq -r '.frontend_branch' "$feature_file")
    local use_local_db=$(jq -r '.use_local_db' "$feature_file")
    local backend_ip=$(jq -r '.backend_ip' "$feature_file")
    local frontend_ip=$(jq -r '.frontend_ip' "$feature_file")
    local worker_ip=$(jq -r '.worker_ip' "$feature_file")
    local scheduler_ip=$(jq -r '.scheduler_ip' "$feature_file")
    local redis_ip=$(jq -r '.redis_ip' "$feature_file")
    local rabbitmq_ip=$(jq -r '.rabbitmq_ip' "$feature_file")
    local mariadb_ip=$(jq -r '.mariadb_ip' "$feature_file")
    
    # Deploy backend
    if [ "$backend_branch" != "none" ]; then
        print_info "Deploying backend ($backend_branch)..."
        cd "$BACKEND_PATH"
        
        git fetch --all
        git checkout "$backend_branch"
        git pull origin "$backend_branch"
        
        # Create group-specific env file from .env-feature template
        if [ ! -f ".env-feature" ]; then
            print_error ".env-feature not found in $BACKEND_PATH"
            return 1
        fi
        cp .env-feature ".env-feature-$group_id"
        
        # Update DB_HOST if needed
        if [ "$use_local_db" = "true" ]; then
            sed -i.bak "s/^DB_HOST=.*/DB_HOST=mariadb-feature-$group_id/" ".env-feature-$group_id"
            rm -f ".env-feature-$group_id.bak"
        fi
        
        # Update env to use group-specific Redis/RabbitMQ
        sed -i.bak "s/redis-feature/redis-feature-$group_id/g" ".env-feature-$group_id"
        sed -i.bak "s/rabbitmq-feature/rabbitmq-feature-$group_id/g" ".env-feature-$group_id"
        rm -f ".env-feature-$group_id.bak"
        
        # Create group-specific compose file
        # All IPs are now read from feature JSON file
        
        cat > "docker-compose.feature-$group_id.yml" <<EOF
name: sirius-md-api-$group_id

services:
  sirius-md-api-feature-$group_id:
    extends:
      file: docker-compose.feature.yml
      service: sirius-md-api-feature
    container_name: sirius-md-api-feature-$group_id
    hostname: sirius-md-api-feature-$group_id
    networks:
      nginx-proxy:
        aliases:
          - network-sirius-md-api-feature-$group_id
        ipv4_address: $backend_ip

  sirius-md-worker-feature-$group_id:
    extends:
      file: docker-compose.feature.yml
      service: sirius-md-worker-feature
    container_name: sirius-md-worker-feature-$group_id
    networks:
      nginx-proxy:
        ipv4_address: $worker_ip

  sirius-md-scheduler-feature-$group_id:
    extends:
      file: docker-compose.feature.yml
      service: sirius-md-scheduler-feature
    container_name: sirius-md-scheduler-feature-$group_id
    networks:
      nginx-proxy:
        ipv4_address: $scheduler_ip

  redis-feature-$group_id:
    extends:
      file: docker-compose.feature.yml
      service: redis-feature
    container_name: redis-feature-$group_id
    volumes:
      - redis-feature-$group_id-data:/data
    networks:
      nginx-proxy:
        ipv4_address: $redis_ip

  rabbitmq-feature-$group_id:
    extends:
      file: docker-compose.feature.yml
      service: rabbitmq-feature
    container_name: rabbitmq-feature-$group_id
    volumes:
      - rabbitmq-feature-$group_id-data:/var/lib/rabbitmq
    networks:
      nginx-proxy:
        ipv4_address: $rabbitmq_ip

$([ "$use_local_db" = "true" ] && cat <<DBEOF
  mariadb-feature-$group_id:
    extends:
      file: docker-compose.feature.yml
      service: mariadb-feature
    container_name: mariadb-feature-$group_id
    profiles: []  # Remove profile to start always
    volumes:
      - mariadb-feature-$group_id-data:/var/lib/mysql
    networks:
      nginx-proxy:
        ipv4_address: $mariadb_ip
DBEOF
)

volumes:
  redis-feature-$group_id-data:
  rabbitmq-feature-$group_id-data:
$([ "$use_local_db" = "true" ] && echo "  mariadb-feature-$group_id-data:")
  # External volumes from dev environment
  scontent_dev:
    external: true
  templates-volume-dev:
    external: true
    name: templates-volume-dev
  templates-assets-volume-dev:
    external: true
    name: templates-assets-volume-dev
  thumbnails-assets-volume-dev:
    external: true
    name: thumbnails-assets-volume-dev
  logs_feature:
    name: logs_feature

networks:
  nginx-proxy:
    external:
      name: nginx-proxy
EOF
        
        # Stop existing containers first
        print_info "Stopping existing backend containers..."
        docker compose --env-file ".env-feature-$group_id" -f "docker-compose.feature-$group_id.yml" down 2>/dev/null || true
        
        # Deploy
        print_info "Building and starting backend containers..."
        docker compose --env-file ".env-feature-$group_id" -f "docker-compose.feature-$group_id.yml" up -d --build
        
        print_success "Backend deployed"
    fi
    
    # Deploy frontend
    if [ "$frontend_branch" != "none" ]; then
        print_info "Deploying frontend ($frontend_branch)..."
        cd "$FRONTEND_PATH"
        
        git fetch --all
        git checkout "$frontend_branch"
        git pull origin "$frontend_branch"
        
        # Create group-specific env file from .env-feature template
        if [ ! -f ".env-feature" ]; then
            print_error ".env-feature not found in $FRONTEND_PATH"
            return 1
        fi
        cp .env-feature ".env-feature-$group_id"
        
        # Update base URL to point to this group's backend
        sed -i.bak "s|NUXT_PUBLIC_BASE_URL=.*|NUXT_PUBLIC_BASE_URL=https://feature.md.sirius.expert/$group_id/app|" ".env-feature-$group_id"
        rm -f ".env-feature-$group_id.bak"
        
        # Create group-specific compose file
        cat > "docker-compose.feature-$group_id.yml" <<EOF
name: sirius-md-$group_id

services:
  sirius-md-feature-$group_id:
    extends:
      file: docker-compose.feature.yml
      service: sirius-md-feature
    container_name: sirius-md-feature-$group_id
    hostname: sirius-md-feature-$group_id
    environment:
      - BASE_URL=/$group_id
    networks:
      nginx-proxy:
        aliases:
          - network-sirius-md-feature-$group_id
        ipv4_address: $frontend_ip

networks:
  nginx-proxy:
    external:
      name: nginx-proxy
EOF
        
        # Stop existing containers first
        print_info "Stopping existing frontend containers..."
        docker compose --env-file ".env-feature-$group_id" -f "docker-compose.feature-$group_id.yml" down 2>/dev/null || true
        
        # Deploy
        print_info "Building and starting frontend containers..."
        docker compose --env-file ".env-feature-$group_id" -f "docker-compose.feature-$group_id.yml" up -d --build
        
        print_success "Frontend deployed"
    fi
    
    # Regenerate nginx config for all groups
    regenerate_nginx_config
    
    print_success "Feature group '$group_id' deployed!"
    print_info "URL: https://feature.md.sirius.expert/$group_id"
}

# Regenerate full nginx configuration for all groups
regenerate_nginx_config() {
    print_info "Regenerating nginx configuration for all feature groups..."
    
    local nginx_config="$NGINX_CONF_DIR/feature.md.sirius.expert"
    
    # Start with header
    cat > "$nginx_config" <<'NGINXHEADER'
## Feature Groups Configuration
## Auto-generated by feature-manager.sh
## Do not edit manually

add_header X-Frame-Options "SAMEORIGIN";
add_header X-XSS-Protection "1; mode=block";
add_header X-Content-Type-Options "nosniff";

proxy_read_timeout 200s;
proxy_send_timeout 200s;
proxy_buffering off;

proxy_set_header REMOTE_ADDR $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Referrer $http_referer;
proxy_set_header Referer $http_referer;

client_body_buffer_size 120M;
client_max_body_size 120M;

NGINXHEADER
    
    # Get first feature group for root redirect
    local first_group_id=""
    for file in "$FEATURES_DIR"/*.json; do
        [ -f "$file" ] || continue
        first_group_id=$(jq -r '.group_id' "$file")
        break
    done
    
    # Add root redirect to first feature group if exists
    if [ -n "$first_group_id" ]; then
        cat >> "$nginx_config" <<NGINXROOT

# Root redirect to first available feature group
location = / {
    return 302 /$first_group_id/;
}

NGINXROOT
    fi
    
    # Add configuration for each feature group
    for file in "$FEATURES_DIR"/*.json; do
        [ -f "$file" ] || continue
        
        local group_id=$(jq -r '.group_id' "$file")
        local backend_branch=$(jq -r '.backend_branch' "$file")
        local frontend_branch=$(jq -r '.frontend_branch' "$file")
        
        cat >> "$nginx_config" <<NGINXGROUP

# Feature group: $group_id
# Backend: $backend_branch | Frontend: $frontend_branch
location = /$group_id {
    return 301 /$group_id/;
}

location /$group_id/ {
    proxy_pass http://network-sirius-md-feature-$group_id:3000/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    
    # Backend API routing
    location ~ ^/$group_id/(api|app|internal|error|php|assets|docs|openapi.json) {
        rewrite ^/$group_id/(.*) /\$1 break;
        proxy_pass http://network-sirius-md-api-feature-$group_id:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
NGINXGROUP
    done
    
    # Reload nginx
    docker exec nginx-proxy nginx -s reload 2>/dev/null || print_warning "Could not reload nginx automatically"
    
    print_success "Nginx configuration regenerated: $nginx_config"
}

# Stop feature group
stop_feature() {
    local group_id=$1
    
    print_header "Stopping Feature Group: $group_id"
    
    # Stop backend
    if [ -f "$BACKEND_PATH/docker-compose.feature-$group_id.yml" ]; then
        cd "$BACKEND_PATH"
        docker compose -f "docker-compose.feature-$group_id.yml" down 2>/dev/null || print_warning "Backend containers already stopped or failed to stop"
        print_success "Backend stopped"
    fi
    
    # Stop frontend
    if [ -f "$FRONTEND_PATH/docker-compose.feature-$group_id.yml" ]; then
        cd "$FRONTEND_PATH"
        docker compose -f "docker-compose.feature-$group_id.yml" down 2>/dev/null || print_warning "Frontend containers already stopped or failed to stop"
        print_success "Frontend stopped"
    fi
}

# Delete feature group
remove_feature() {
    local group_id=$1
    
    print_header "Removing Feature Group: $group_id"
    
    echo -n "Are you sure you want to delete '$group_id'? (y/n): "
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_warning "Cancelled"
        return
    fi
    
    # Stop containers (ignore errors - containers might not exist)
    stop_feature "$group_id" || true
    
    # Remove files (force remove, ignore errors)
    rm -f "$BACKEND_PATH/docker-compose.feature-$group_id.yml" 2>/dev/null || true
    rm -f "$BACKEND_PATH/.env-feature-$group_id" 2>/dev/null || true
    rm -f "$FRONTEND_PATH/docker-compose.feature-$group_id.yml" 2>/dev/null || true
    rm -f "$FRONTEND_PATH/.env-feature-$group_id" 2>/dev/null || true
    
    # Remove feature info
    delete_feature "$group_id"
    
    # Regenerate nginx config without this group
    regenerate_nginx_config
    
    print_success "Feature group '$group_id' removed"
}

# Main menu
main_menu() {
    print_header "Sirius Feature Group Manager"
    
    echo "1) List all feature groups"
    echo "2) Create new feature group"
    echo "3) Show feature group details"
    echo "4) Deploy feature group"
    echo "5) Stop feature group"
    echo "6) Remove feature group"
    echo "7) Exit"
    echo ""
    echo -n "Your choice: "
    read choice
    
    case $choice in
        1)
            list_features
            ;;
        2)
            create_feature
            ;;
        3)
            echo -n "Enter GROUP_ID: "
            read group_id
            show_feature "$group_id"
            ;;
        4)
            echo -n "Enter GROUP_ID: "
            read group_id
            deploy_feature "$group_id"
            ;;
        5)
            echo -n "Enter GROUP_ID: "
            read group_id
            stop_feature "$group_id"
            ;;
        6)
            echo -n "Enter GROUP_ID: "
            read group_id
            remove_feature "$group_id"
            ;;
        7)
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    echo ""
    echo -n "Press Enter to continue..."
    read dummy
    main_menu
}

# CLI mode
if [ $# -gt 0 ]; then
    case $1 in
        list|ls)
            list_features
            ;;
        show|info)
            show_feature "$2"
            ;;
        create|new)
            create_feature
            ;;
        deploy)
            deploy_feature "$2"
            ;;
        stop)
            stop_feature "$2"
            ;;
        remove|rm|delete)
            remove_feature "$2"
            ;;
        *)
            echo "Usage: $0 {list|show|create|deploy|stop|remove} [GROUP_ID]"
            exit 1
            ;;
    esac
else
    main_menu
fi

