#!/usr/bin/env bash

# Configuration variables

WORK_DIR="$(pwd)"
LOGS_DIR="$WORK_DIR/logs"
TIMESTAMP_FORMAT="${TIMESTAMP_FORMAT:-%Y-%m-%d-%H:%M:%S}"
CURRENT_TIMESTAMP=$(date +"$TIMESTAMP_FORMAT")
LOG_FILE="${LOG_FILE:-$LOGS_DIR/script_execution_$CURRENT_TIMESTAMP.log}"
LOG_ENABLED="${LOG_ENABLED:-1}"  # Set to 0 to disable logging

# Function to get current timestamp
function cteate_log_folder() {
    if [[ ! -d $LOGS_DIR ]];then
        echo "Creating log folder"
        mkdir -p $LOGS_DIR
    else
        echo "Already exists"
    fi
}

# Function to get current timestamp
function get_timestamp() {
    date +"$TIMESTAMP_FORMAT"
}

# Function to log a message to the log file
function log_message() {
    local message="$1"
    local timestamp=$(get_timestamp)
    
    if [[ $LOG_ENABLED -eq 1 ]]; then
        echo "[$timestamp] $message" >> "$LOG_FILE"
    fi
}

# Function to run a command and check its status with descriptive output
function run_command() {
    local description="$1"
    shift
    
    local timestamp=$(get_timestamp)
    echo "[$timestamp] Executing: $description"
    log_message "STARTED: $description (command: $*)"
    
    "$@"
    local status=$?
    
    timestamp=$(get_timestamp)
    if [[ $status -eq 0 ]]; then
        echo "[$timestamp]  $description: SUCCESS"
        log_message "SUCCESS: $description (exit code: $status)"
    else
        echo "[$timestamp]  $description: FAILED (exit code: $status)"
        log_message "FAILED: $description (exit code: $status)"
        return $status
    fi
}

# Function that will exit the script if the command fails
function run_critical_command() {
    local description="$1"
    shift
    
    local timestamp=$(get_timestamp)
    echo "[$timestamp] Executing critical operation: $description"
    log_message "STARTED CRITICAL: $description (command: $*)"
    
    "$@"
    local status=$?
    
    timestamp=$(get_timestamp)
    if [[ $status -eq 0 ]]; then
        echo "[$timestamp]  $description: SUCCESS"
        log_message "SUCCESS: $description (exit code: $status)"
    else
        echo "[$timestamp]  $description: FAILED (exit code: $status)"
        log_message "CRITICAL FAILURE: $description (exit code: $status)"
        echo "[$timestamp] Critical operation failed. Exiting script."
        log_message "EXITING SCRIPT due to critical failure"
        exit $status
    fi
}

# Function that logs command output to a separate file while displaying status
function run_logged_command() {
    local description="$1"
    local cmd_log_file="$2"
    shift 2
    
    local timestamp=$(get_timestamp)
    echo "[$timestamp] Executing: $description (logging to $cmd_log_file)"
    log_message "STARTED: $description (command: $*, output logged to $cmd_log_file)"
    
    # Ensure the directory for the log file exists
    mkdir -p "$(dirname "$cmd_log_file")" 2>/dev/null
    
    # Log the command with timestamp
    echo "[$timestamp] Command: $*" > "$cmd_log_file"
    echo "----------------------------------------" >> "$cmd_log_file"
    
    # Execute command and capture output
    "$@" >> "$cmd_log_file" 2>&1
    local status=$?
    
    # Add ending timestamp and status
    echo "----------------------------------------" >> "$cmd_log_file"
    timestamp=$(get_timestamp)
    echo "[$timestamp] Command completed with status: $status" >> "$cmd_log_file"
    
    if [[ $status -eq 0 ]]; then
        echo "[$timestamp] $description: SUCCESS"
        log_message "SUCCESS: $description (exit code: $status, log: $cmd_log_file)"
    else
        echo "[$timestamp] $description: FAILED (exit code: $status)"
        log_message "FAILED: $description (exit code: $status, log: $cmd_log_file)"
        echo "Last 5 lines of command output:"
        tail -n 5 "$cmd_log_file" | sed 's/^/    /'
        return $status
    fi
}

# Example usage
# Initialize log file
# echo "Script execution started at $(get_timestamp)" > "$LOG_FILE"
# run_command "Updating package lists" sudo apt update
# run_critical_command "Installing NGINX" sudo apt install -y nginx
# run_logged_command "Testing NGINX configuration" "/tmp/nginx_test.log" sudo nginx -t
    
#local timestamp=$(get_timestamp)
#echo "[$timestamp] All operations completed"
#log_message "Script execution completed successfully"


# Example of customizing log settings
# LOG_FILE="/var/log/my_custom_script.log"
# LOG_ENABLED=1
# TIMESTAMP_FORMAT="%Y-%m-%d-%H:%M:%S.%N"
