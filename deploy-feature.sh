#!/bin/bash

# Sirius Feature Branch Deployer
# This script deploys feature branches for backend and/or frontend
# Usage: ./deploy-feature.sh

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
BACKEND_PATH="/srv/lonagi/projects/sirius/einvoice-fastapi"
FRONTEND_PATH="/srv/lonagi/projects/sirius/einvoice2-nuxt3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect where script was run from
if [[ "$SCRIPT_DIR" == *"einvoice-fastapi"* ]]; then
    DEPLOY_MODE="backend"
    echo "🎯 Running from backend directory - will deploy BACKEND only"
elif [[ "$SCRIPT_DIR" == *"einvoice2-nuxt3"* ]]; then
    DEPLOY_MODE="frontend"
    echo "🎯 Running from frontend directory - will deploy FRONTEND only"
else
    DEPLOY_MODE="interactive"
    echo "🎯 Running from root - interactive mode"
fi

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to get current git branch
get_current_branch() {
    local path=$1
    cd "$path"
    git branch --show-current
}

# Function to list available git branches
list_branches() {
    local path=$1
    cd "$path"
    git fetch --all --quiet 2>/dev/null
    git branch -a | grep -v HEAD | sed 's/remotes\/origin\///' | sed 's/*//' | awk '{print $1}' | sort -u
}

# Function to validate branch exists
branch_exists() {
    local path=$1
    local branch=$2
    cd "$path"
    git show-ref --verify --quiet "refs/heads/$branch" || git show-ref --verify --quiet "refs/remotes/origin/$branch"
}

# Function to create .env-feature if it doesn't exist
create_env_feature() {
    local path=$1
    local env_file="$path/.env-feature"
    
    if [ ! -f "$env_file" ]; then
        print_warning ".env-feature not found in $path"
        echo -n "Do you want to create it from .env.example? (y/n): "
        read create_env
        
        if [ "$create_env" = "y" ] || [ "$create_env" = "Y" ]; then
            if [ -f "$path/.env.example" ]; then
                cp "$path/.env.example" "$env_file"
                print_success "Created $env_file from .env.example"
                print_warning "Please edit $env_file with your feature environment settings"
                echo -n "Press Enter to continue after editing the file..."
                read
            else
                print_error ".env.example not found in $path"
                exit 1
            fi
        else
            print_error "Cannot proceed without .env-feature file"
            exit 1
        fi
    else
        print_success "Found .env-feature in $path"
    fi
}

# Function to deploy backend
deploy_backend() {
    local branch=$1
    local use_local_db=$2
    
    print_header "Deploying Backend"
    
    cd "$BACKEND_PATH"
    
    print_info "Checking out branch: $branch"
    git fetch --all
    git checkout "$branch"
    git pull origin "$branch"
    print_success "Branch $branch checked out"
    
    # Update DB_HOST in .env-feature based on choice
    if [ "$use_local_db" = "y" ] || [ "$use_local_db" = "Y" ]; then
        print_info "Configuring to use local MariaDB from docker-compose..."
        if grep -q "^DB_HOST=" .env-feature; then
            sed -i.bak 's/^DB_HOST=.*/DB_HOST=mariadb-feature/' .env-feature && rm -f .env-feature.bak
            print_success "DB_HOST set to mariadb-feature"
        fi
        COMPOSE_PROFILES="with-db"
    else
        print_info "Using external database from .env-feature"
        # Ensure DB_HOST is NOT mariadb-feature
        if grep -q "^DB_HOST=mariadb-feature" .env-feature; then
            print_warning "DB_HOST is set to mariadb-feature, but you chose external DB"
            echo -n "Update DB_HOST to mariadb-dev? (y/n): "
            read update_host
            if [ "$update_host" = "y" ] || [ "$update_host" = "Y" ]; then
                sed -i.bak 's/^DB_HOST=.*/DB_HOST=mariadb-dev/' .env-feature && rm -f .env-feature.bak
                print_success "DB_HOST set to mariadb-dev"
            fi
        fi
        COMPOSE_PROFILES=""
    fi
    
    print_info "Building and starting backend containers..."
    if [ -n "$COMPOSE_PROFILES" ]; then
        COMPOSE_PROFILES=$COMPOSE_PROFILES docker compose --env-file .env-feature -f docker-compose.feature.yml up -d --build
    else
        docker compose --env-file .env-feature -f docker-compose.feature.yml up -d --build
    fi
    
    print_success "Backend deployed successfully!"
}

# Function to deploy frontend
deploy_frontend() {
    local branch=$1
    
    print_header "Deploying Frontend"
    
    cd "$FRONTEND_PATH"
    
    print_info "Checking out branch: $branch"
    git fetch --all
    git checkout "$branch"
    git pull origin "$branch"
    print_success "Branch $branch checked out"
    
    print_info "Building and starting frontend containers..."
    docker compose --env-file .env-feature -f docker-compose.feature.yml up -d --build
    
    print_success "Frontend deployed successfully!"
}

# Main script
main() {
    print_header "Sirius Feature Branch Deployer"
    
    # Variables
    local deploy_backend_flag=false
    local deploy_frontend_flag=false
    local backend_branch="dev"
    local frontend_branch="dev"
    local use_local_db="n"
    
    # Determine what to deploy based on where script was run
    if [ "$DEPLOY_MODE" = "backend" ]; then
        deploy_backend_flag=true
        deploy_frontend_flag=false
        
        # Check .env-feature
        create_env_feature "$BACKEND_PATH"
        
        # Ask about database
        print_header "Database Configuration"
        echo -n "Use local MariaDB container? (y/n, default: n): "
        read use_local_db
        use_local_db=${use_local_db:-n}
        
        # Ask for backend branch
        print_header "Backend Branch Selection"
        backend_current=$(get_current_branch "$BACKEND_PATH")
        print_info "Current backend branch: $backend_current"
        echo ""
        echo "Available backend branches:"
        list_branches "$BACKEND_PATH" | nl
        echo ""
        echo -n "Enter backend branch name (default: $backend_current): "
        read backend_branch
        backend_branch=${backend_branch:-$backend_current}
        
        if ! branch_exists "$BACKEND_PATH" "$backend_branch"; then
            print_error "Branch '$backend_branch' does not exist in backend repo"
            exit 1
        fi
        
    elif [ "$DEPLOY_MODE" = "frontend" ]; then
        deploy_backend_flag=false
        deploy_frontend_flag=true
        
        # Check .env-feature
        create_env_feature "$FRONTEND_PATH"
        
        # Ask for frontend branch
        print_header "Frontend Branch Selection"
        frontend_current=$(get_current_branch "$FRONTEND_PATH")
        print_info "Current frontend branch: $frontend_current"
        echo ""
        echo "Available frontend branches:"
        list_branches "$FRONTEND_PATH" | nl
        echo ""
        echo -n "Enter frontend branch name (default: $frontend_current): "
        read frontend_branch
        frontend_branch=${frontend_branch:-$frontend_current}
        
        if ! branch_exists "$FRONTEND_PATH" "$frontend_branch"; then
            print_error "Branch '$frontend_branch' does not exist in frontend repo"
            exit 1
        fi
        
    else
        # Interactive mode from root
        if [ ! -d "$BACKEND_PATH" ] || [ ! -d "$FRONTEND_PATH" ]; then
            print_error "Backend or Frontend path not found!"
            print_error "Backend path: $BACKEND_PATH"
            print_error "Frontend path: $FRONTEND_PATH"
            exit 1
        fi
        
        # Ask what to deploy
        print_header "What to Deploy?"
        echo "1) Backend only"
        echo "2) Frontend only"
        echo "3) Both backend and frontend"
        echo ""
        echo -n "Your choice (1/2/3, default: 3): "
        read deploy_choice
        deploy_choice=${deploy_choice:-3}
        
        case $deploy_choice in
            1)
                deploy_backend_flag=true
                deploy_frontend_flag=false
                ;;
            2)
                deploy_backend_flag=false
                deploy_frontend_flag=true
                ;;
            3)
                deploy_backend_flag=true
                deploy_frontend_flag=true
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
        
        # Check .env-feature files
        if [ "$deploy_backend_flag" = true ]; then
            create_env_feature "$BACKEND_PATH"
        fi
        if [ "$deploy_frontend_flag" = true ]; then
            create_env_feature "$FRONTEND_PATH"
        fi
        
        # Database configuration if deploying backend
        if [ "$deploy_backend_flag" = true ]; then
            print_header "Database Configuration"
            echo -n "Use local MariaDB container? (y/n, default: n): "
            read use_local_db
            use_local_db=${use_local_db:-n}
        fi
        
        # Backend branch selection
        if [ "$deploy_backend_flag" = true ]; then
            print_header "Backend Branch Selection"
            backend_current=$(get_current_branch "$BACKEND_PATH")
            print_info "Current backend branch: $backend_current"
            echo ""
            echo "Available backend branches:"
            list_branches "$BACKEND_PATH" | nl
            echo ""
            echo -n "Enter backend branch name (default: dev): "
            read backend_branch
            backend_branch=${backend_branch:-dev}
            
            if ! branch_exists "$BACKEND_PATH" "$backend_branch"; then
                print_error "Branch '$backend_branch' does not exist in backend repo"
                exit 1
            fi
        fi
        
        # Frontend branch selection
        if [ "$deploy_frontend_flag" = true ]; then
            print_header "Frontend Branch Selection"
            frontend_current=$(get_current_branch "$FRONTEND_PATH")
            print_info "Current frontend branch: $frontend_current"
            echo ""
            echo "Available frontend branches:"
            list_branches "$FRONTEND_PATH" | nl
            echo ""
            echo -n "Enter frontend branch name (default: dev): "
            read frontend_branch
            frontend_branch=${frontend_branch:-dev}
            
            if ! branch_exists "$FRONTEND_PATH" "$frontend_branch"; then
                print_error "Branch '$frontend_branch' does not exist in frontend repo"
                exit 1
            fi
        fi
    fi
    
    # Confirmation
    print_header "Deployment Summary"
    if [ "$deploy_backend_flag" = true ]; then
        echo "Backend:  ✓ Deploy branch '$backend_branch'"
        echo "Database: $([ "$use_local_db" = "y" ] || [ "$use_local_db" = "Y" ] && echo "Local MariaDB" || echo "External (from .env-feature)")"
    else
        echo "Backend:  - Skip"
    fi
    if [ "$deploy_frontend_flag" = true ]; then
        echo "Frontend: ✓ Deploy branch '$frontend_branch'"
    else
        echo "Frontend: - Skip"
    fi
    echo ""
    echo -n "Proceed with deployment? (y/n): "
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_warning "Deployment cancelled"
        exit 0
    fi
    
    # Deploy
    if [ "$deploy_backend_flag" = true ]; then
        deploy_backend "$backend_branch" "$use_local_db"
    fi
    
    if [ "$deploy_frontend_flag" = true ]; then
        deploy_frontend "$frontend_branch"
    fi
    
    # Final status
    print_header "Deployment Complete!"
    if [ "$deploy_backend_flag" = true ]; then
        print_success "Backend ($backend_branch) deployed at $BACKEND_PATH"
    fi
    if [ "$deploy_frontend_flag" = true ]; then
        print_success "Frontend ($frontend_branch) deployed at $FRONTEND_PATH"
    fi
    
    echo ""
    print_info "Useful commands:"
    if [ "$deploy_backend_flag" = true ]; then
        echo "  Backend logs:  cd $BACKEND_PATH && docker compose -f docker-compose.feature.yml logs -f"
        echo "  Backend stop:  cd $BACKEND_PATH && docker compose -f docker-compose.feature.yml down"
    fi
    if [ "$deploy_frontend_flag" = true ]; then
        echo "  Frontend logs: cd $FRONTEND_PATH && docker compose -f docker-compose.feature.yml logs -f"
        echo "  Frontend stop: cd $FRONTEND_PATH && docker compose -f docker-compose.feature.yml down"
    fi
    echo ""
}

# Run main function
main
