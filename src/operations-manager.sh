#!/bin/bash

# static variables
MONGO_HELM_CHART_VERSION="15.1.5"
INSTALLATION_DIR_PATH=".config/helbimom"
PROJECT_PATH="$HOME/$INSTALLATION_DIR_PATH"
CONFIG_DIR_NAME=".current-mongo-configs"
CONFIG_DIR="$HOME/$INSTALLATION_DIR_PATH/$CONFIG_DIR_NAME"
CONTEXT_FILE="$CONFIG_DIR/context.json"


# Function to print help usage
print_help() {
    echo "Helm Bitnami MongoDB Operations Manager CLI"
    echo
    echo "Usage:"
    echo "  $0 [command]"
    echo
    echo "Available Commands:"
    echo "  swc|switch-context <name>       Switch to an existing MongoDB installation context."
    echo "  lsc|list-contexts               List all MongoDB installation contexts available."
    echo "  install                         Install a new MongoDB installation using Helm."
    echo "  start <release-name>            Start a previously uninstalled MongoDB release using Helm."
    echo "  stop <release-name>             Uninstall a MongoDB installation using Helm."
    echo "  delete <release-name>           Fully delete and purge a MongoDB installation."
    echo "  gc|get-creds <release-name>     Display connection information for a MongoDB installation."
    
    echo
    echo "Flags:"
    echo "  -h, --help   Show help for the MongoDB Operations Manager CLI."
    echo
    echo "Examples:"
    echo "  $0 swc|switch-context myMongoDB"
    echo "  $0 lsc|list-contexts"
    echo "  $0 install"
    echo "  $0 start my-mongo"
    echo "  $0 stop my-mongo"
    echo "  $0 delete my-mongo"
    echo "  $0 gc|get-creds my-mongo"
    
    echo
    echo "Use \"$0 [command] --help\" for more information about a command."
}

list_contexts_help() {
    echo "List all MongoDB installation contexts available."
    echo
    echo "Usage:"
    echo "  $0 list-contexts"
    echo
}

switch_context_help() {
    echo "Switch the active MongoDB context."
    echo
    echo "Usage:"
    echo "  $0 switch-context <context-name>"
    echo
    echo "Arguments:"
    echo "  context-name    The name of the context to switch to."
    echo
    echo "Description:"
    echo "  This command switches the active context to the specified context name."
    echo "  The context must exist in the list of configured contexts."
    echo
    echo "Examples:"
    echo "  $0 switch-context mongo-standalone"
    echo "      Switches the active context to 'mongo-standalone'."
    echo
}

install_mongodb_help() {
    echo "Install a new MongoDB installation using Helm."
    echo
    echo "Usage:"
    echo "  $0 new-installation"
    echo
    echo "Description:"
    echo "  This command installs a new MongoDB installation using Helm."
    echo "  It prompts the user for MongoDB flavor, namespace, and other configuration details."
    echo
    echo "Examples:"
    echo "  $0 new-installation"
    echo "      Installs a new MongoDB installation using Helm."
    echo
}

stop_mongodb_help() {
    echo "Uninstall a MongoDB installation using Helm."
    echo
    echo "Usage:"
    echo "  $0 uninstall-mongodb <release-name>"
    echo
    echo "Arguments:"
    echo "  release-name    The name of the MongoDB installation to uninstall."
    echo
    echo "Description:"
    echo "  This command uninstalls a MongoDB installation using Helm."
    echo "  It won't delete the persistent volume claims (PVCs) by default."
    echo "  It won't delete the configurations by default."
    echo "  User can resart the installation with the same configurations."
    echo
    echo "Examples:"
    echo "  $0 uninstall my-mongo"
    echo "      Uninstalls the MongoDB installation with the release name 'my-mongo'."
    echo
}

start_mongodb_help() {
    echo "Restart a previously uninstalled MongoDB installation using Helm."
    echo
    echo "Usage:"
    echo "  $0 restart <release-name>"
    echo
    echo "Arguments:"
    echo "  release-name    The name of the MongoDB release to restart."
    echo
    echo "Description:"
    echo "  This command restarts a MongoDB installation using Helm and existing PVCs."
    echo "  It assumes that the installation was previously uninstalled without deleting PVCs or configuration files."
    echo
    echo "Examples:"
    echo "  $0 restart my-mongo"
    echo "      Restarts the MongoDB installation with the release name 'my-mongo'."
    echo
}

delete_help() {
    echo "Fully delete and purge a MongoDB installation."
    echo
    echo "Usage:"
    echo "  $0 delete <release-name>"
    echo
    echo "Arguments:"
    echo "  release-name    The name of the MongoDB release to completely remove."
    echo
    echo "Description:"
    echo "  This command completely removes a MongoDB installation, including all data and configurations."
    echo "  All associated persistent volume claims and configuration files will be deleted."
    echo
    echo "Examples:"
    echo "  $0 delete my-mongo"
    echo "      Completely removes the MongoDB installation named 'my-mongo'."
    echo
}

get_creds_help() {
    echo "Display connection information for a MongoDB installation."
    echo
    echo "Usage:"
    echo "  $0 gc|get-creds <release-name>"
    echo
    echo "Arguments:"
    echo "  release-name    The name of the MongoDB release to display connection information for."
    echo
    echo "Description:"
    echo "  This command retrieves and displays connection information for a specified MongoDB release."
    echo "  It provides details such as user credentials and MongoDB URIs for internal and external access,"
    echo "  depending on the configuration and state of the MongoDB instance."
    echo
    echo "  The command checks the current status of the MongoDB instance and only provides"
    echo "  connection details if the instance is currently running. For cluster configurations,"
    echo "  it will also detail how to connect externally if external access is enabled."
    echo
    echo "Examples:"
    echo "  $0 gc|get-creds my-mongo"
    echo "      Displays connection information for the MongoDB release named 'my-mongo'."
    echo
    echo "--------------------------------------------------"
    echo
}

####################################################################################################
## @@@@@@@@@@@@@@@@@@@@@@@@@  Context Management Functions @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
####################################################################################################

# Initialize context file if it does not exist
initialize_context_file() {
    if [ ! -f "$CONTEXT_FILE" ]; then
        echo '{"currentContext":"","contexts":[]}' > "$CONTEXT_FILE"
    fi
}

# Function to ensure the configuration directory and context file exist
ensure_config_setup() {
    # Ensure configuration directory exists
    if [ ! -d "$CONFIG_DIR" ]; then
        echo "Creating configuration directory: $CONFIG_DIR"
        mkdir -p "$CONFIG_DIR"
    fi

    # Ensure context file exists
    if [ ! -f "$CONTEXT_FILE" ]; then
        echo "Initializing context file: $CONTEXT_FILE"
        initialize_context_file
    fi
}

# Add a new context to the context file
add_new_context() {
    local name=$1
    local namespace=$2
    local clusterName=$3
    local configFileName=$4
    local helmReleaseName=$5
    local type=$6
    local status=$7
    local backupCleanUpCron=$8
    local s3ExternalBackupCron=$9
    

    # Get the current date in YYYY-MM-DD format
    local creationDate=$(date "+%Y-%m-%d")

    # Initial jq command to update the JSON file with mandatory fields
    local jqCmd='.contexts += [{"name": $name, "namespace": $namespace, "clusterName": $clusterName, "configFileName": $configFileName, "helmReleaseName": $helmReleaseName, "type": $type, "status": $status, "creationDate": $creationDate'

    # Check if s3ExternalBackupCron is provided and append it to the jq command
    if [[ -n "$s3ExternalBackupCron" ]]; then
        jqCmd+=', "s3ExternalBackupCron": $s3ExternalBackupCron'
    fi

    # Check if backupCleanUpCron is provided and append it to the jq command
    if [[ -n "$backupCleanUpCron" ]]; then
        jqCmd+=', "backupCleanUpCron": $backupCleanUpCron'
    fi

    # Close the array and object in the jq command
    jqCmd+='}]'

    # Execute the jq command to add the context
    jq --arg name "$name" \
        --arg namespace "$namespace" \
        --arg clusterName "$clusterName" \
        --arg configFileName "$configFileName" \
        --arg helmReleaseName "$helmReleaseName" \
        --arg type "$type" \
        --arg status "$status" \
        --arg creationDate "$creationDate" \
        --arg s3ExternalBackupCron "$s3ExternalBackupCron" \
        --arg backupCleanUpCron "$backupCleanUpCron" \
        "$jqCmd" "$CONTEXT_FILE" > temp.json && mv temp.json "$CONTEXT_FILE"

    # Set this as the current context
    jq --arg name "$name" '.currentContext = $name' "$CONTEXT_FILE" > temp.json && mv temp.json "$CONTEXT_FILE"
}

# Switch the current active context
switch_context() {
    local selectedContext=$1
    
    # Check if selectedContext is empty
    if [ -z "$selectedContext" ]; then
        echo "Error: No context name provided. Please specify a context name to switch to."
        return 1 # Exit the function with an error status
    fi

    # Validate the selected context exists
    if jq -e --arg selectedContext "$selectedContext" '.contexts[] | select(.name == $selectedContext)' "$CONTEXT_FILE" > /dev/null; then
        jq --arg selectedContext "$selectedContext" '.currentContext = $selectedContext' "$CONTEXT_FILE" > temp.json && mv temp.json "$CONTEXT_FILE"
        echo "Switched to context: $selectedContext"
    else
        echo "Context $selectedContext does not exist."
    fi
}

list_contexts() {
    if [ ! -f "$CONTEXT_FILE" ]; then
        echo "Contexts file not found."
        return 1
    fi

    # Fetch current context
    local current_context=$(jq -r '.currentContext' "$CONTEXT_FILE")
    local contexts_count=$(jq '.contexts | length' "$CONTEXT_FILE")

    # Check if there are no contexts
    if [ "$contexts_count" -eq 0 ]; then
        echo "Current   Name        Type         K8S Cluster   ConfigFileName              Namespace    Status"
        echo "-------   ----        ----         -----------   --------------              ---------    ------- "

        echo "No available contexts."
        return
    fi

    # Extract contexts using jq and format them for processing with awk
    jq -r '.contexts[] | [.name, .type, .clusterName, .configFileName, .namespace, .status] | @tsv' "$CONTEXT_FILE" |
    awk -v currentContext=$(jq -r '.currentContext' "$CONTEXT_FILE") '
    BEGIN {
        FS="\t";
        currentWidth = 7; # "Current" column width
        nameWidth = 4; typeWidth = 10; clusterWidth = 11; configWidth = 13; namespaceWidth = 9; statusWidth = 10; # Initial minimum column widths based on header titles
        separatorWidth = 3; # Additional separation space between all columns
    }
    {
        if (length($1) > nameWidth) nameWidth = length($1);
        if (length($2) > typeWidth) typeWidth = length($2);
        if (length($3) > clusterWidth) clusterWidth = length($3);
        if (length($4) > configWidth) configWidth = length($4);
        if (length($5) > namespaceWidth) namespaceWidth = length($5);
        if (length($6) > statusWidth) statusWidth = length($6);
        contexts[NR] = $0; # Store the line for later printing
    }
    END {
        # Print headers with dynamic widths and additional separation space between all columns
        printf("%-*s%*s%-*s%*s%-*s%*s%-*s%*s%-*s%*s%-*s%*s%-*s\n",
                currentWidth, "Current", separatorWidth, "",
                nameWidth, "Name", separatorWidth, "",
                typeWidth, "Type", separatorWidth, "",
                clusterWidth, "K8S Cluster", separatorWidth, "",
                configWidth, "ConfigFileName", separatorWidth, "",
                namespaceWidth, "Namespace", separatorWidth, "",
                statusWidth, "Status");
        for (i=1; i<=NR; i++) {
            split(contexts[i], fields, FS);
            mark = (fields[1] == currentContext) ? "*" : " ";
            printf("%-*s%*s%-*s%*s%-*s%*s%-*s%*s%-*s%*s%-*s%*s%-*s\n",
                    currentWidth, mark, separatorWidth, "",
                    nameWidth, fields[1], separatorWidth, "",
                    typeWidth, fields[2], separatorWidth, "",
                    clusterWidth, fields[3], separatorWidth, "",
                    configWidth, fields[4], separatorWidth, "",
                    namespaceWidth, fields[5], separatorWidth, "",
                    statusWidth, fields[6]);
        }
    }'

    # If there is no current context set but there are available contexts
    if [ -z "$current_context" ] || [ "$current_context" == "null" ]; then
        echo "No current context is set. Use the appropriate command to set one."
    fi
}

# Function to delete a context from the context file
delete_context() {
    local contextToDelete=$1

    # Check if contextToDelete is not empty
    if [ -z "$contextToDelete" ]; then
        echo "Error: No context name provided. Please specify a context name to delete."
        return 1
    fi

    # Check if the context exists
    local exists=$(jq --arg contextToDelete "$contextToDelete" '.contexts[] | select(.name == $contextToDelete)' "$CONTEXT_FILE")
    if [ -z "$exists" ]; then
        echo "Context $contextToDelete does not exist."
        return 1
    fi

    # Delete the context
    jq --arg contextToDelete "$contextToDelete" 'del(.contexts[] | select(.name == $contextToDelete))' "$CONTEXT_FILE" > temp.json && mv temp.json "$CONTEXT_FILE"
    echo "Context $contextToDelete has been deleted."

    # Check if the deleted context was the current context
    local currentContext=$(jq -r '.currentContext' "$CONTEXT_FILE")
    if [ "$contextToDelete" == "$currentContext" ]; then
        # If it was, unset the current context
        jq '.currentContext = ""' "$CONTEXT_FILE" > temp.json && mv temp.json "$CONTEXT_FILE"
        echo "Current context unset."
    fi
}

get_current_context_configs() {
    # Ensure the context file exists
    if [ ! -f "$CONTEXT_FILE" ]; then
        echo "Context file not found. Please initialize your context."
        return 1
    fi

    # Extract the name of the current context
    local currentContext=$(jq -r '.currentContext' "$CONTEXT_FILE")
    if [ -z "$currentContext" ] || [ "$currentContext" == "null" ]; then
        echo "No current context set."
        return 1
    fi

    # Extract details of the current context
    local contextDetails=$(jq --arg currentContext "$currentContext" '.contexts[] | select(.name == $currentContext)' "$CONTEXT_FILE")
    if [ -z "$contextDetails" ]; then
        echo "Current context details not found."
        return 1
    fi

    # Set extracted values as variables
    CURRENT_CONTEXT_NAME=$(echo "$contextDetails" | jq -r '.name')
    CURRENT_CONTEXT_NAMESPACE=$(echo "$contextDetails" | jq -r '.namespace')
    CURRENT_CONTEXT_CLUSTERNAME=$(echo "$contextDetails" | jq -r '.clusterName')
    CURRENT_CONTEXT_CONFIGFILENAME=$(echo "$contextDetails" | jq -r '.configFileName')
    CURRENT_CONTEXT_HELMRELEASENAME=$(echo "$contextDetails" | jq -r '.helmReleaseName')
    CURRENT_CONTEXT_TYPE=$(echo "$contextDetails" | jq -r '.type')
    CURRENT_CONTEXT_STATUS=$(echo "$contextDetails" | jq -r '.status')
    CURRENT_CONTEXT_CREATIONDATE=$(echo "$contextDetails" | jq -r '.creationDate')

    # Check and set the optional s3ExternalBackupCron if it exists
    local s3Cron=$(echo "$contextDetails" | jq -r '.s3ExternalBackupCron // "not provided"')
    if [ "$s3Cron" != "not provided" ]; then
        CURRENT_CONTEXT_S3EXTERNALBACKUPCRON="$s3Cron"
        echo "S3 External Backup Cron set for: $CURRENT_CONTEXT_S3EXTERNALBACKUPCRON"
    else
        echo "No S3 External Backup Cron set."
    fi

    # Check and set the optional backupCleanUpCron if it exists
    local cleanupCron=$(echo "$contextDetails" | jq -r '.backupCleanUpCron // "not provided"')
    if [ "$cleanupCron" != "not provided" ]; then
        CURRENT_CONTEXT_BACKUPCLEANUPCRON="$cleanupCron"
        echo "Backup CleanUp Cron set for: $CURRENT_CONTEXT_BACKUPCLEANUPCRON"
    else
        echo "No Backup CleanUp Cron set."
    fi

    echo "Current context configs set for: $CURRENT_CONTEXT_NAME"

}

####################################################################################################
## @@@@@@@@@@@@@@@@@@@@@@@@@  MongoDB Operations Functions @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
####################################################################################################

# Function to choose MongoDB flavor and configure values accordingly
choose_mongodb_flavor_values_and_set_releaseName() {
    IS_STANDALONE=false
    # we start by setting the release name
    read -p "Enter new release name or press enter to use default ('my-new-mongo'): " USER_INPUT_RELEASE_NAME
    echo
    if [ -n "$USER_INPUT_RELEASE_NAME" ]; then
        RELEASE_NAME=$USER_INPUT_RELEASE_NAME
    else
        RELEASE_NAME="my-new-mongo" # Default release name
    fi

    # Prompt the user to choose the MongoDB flavor
    echo "Please choose the MongoDB flavor to install:"
    echo "1) ReplicaSet (generally used for production environments, we can configure backup and restore for this flavor)"
    echo "2) Standalone (generally used for development environments, does not support backup and restore nor scaling and high availability)"
    echo
    read -p "Enter your choice (1 or 2): " mongodb_flavor_choice
    echo

    case $mongodb_flavor_choice in
        1)
            echo "You've chosen Replica Set. Preparing values file..."
            echo
            VALUES_FILE_NAME="values-$RELEASE_NAME-replicaset.yaml"
            cp $PROJECT_PATH/values-prod-replicaset.yaml "$CONFIG_DIR/$VALUES_FILE_NAME"
            echo "Configuration for Replica Set copied to $CONFIG_DIR/$VALUES_FILE_NAME"
            echo
            VALUES_FILE_PATH="$CONFIG_DIR/$VALUES_FILE_NAME"
            ;;
        2)
            echo "You've chosen Standalone. Preparing values file..."
            echo
            VALUES_FILE_NAME="values-$RELEASE_NAME-standalone.yaml"
            cp $PROJECT_PATH/values-dev-standalone.yaml "$CONFIG_DIR/$VALUES_FILE_NAME"
            echo "Configuration for Standalone copied to $CONFIG_DIR/$VALUES_FILE_NAME"
            echo
            VALUES_FILE_PATH="$CONFIG_DIR/$VALUES_FILE_NAME"
            IS_STANDALONE=true
            ;;
        *)
            echo "Invalid choice. Exiting."
            echo
            exit 1
            ;;
    esac

    # Set the release name in values.yaml
    yq e -i ".releaseName = \"$RELEASE_NAME\"" "$VALUES_FILE_PATH"

}

# Function to set the namespace in values.yaml using yq
set_namespace() {
    # Read the current namespace set in values.yaml
    VALUES_FILE_NAMESPACE=$(yq e '.global.namespaceOverride' "$VALUES_FILE_PATH")

    # If the namespace is not set in values.yaml, prompt the user to input
    if [ -z "$VALUES_FILE_NAMESPACE" ] || [ "$VALUES_FILE_NAMESPACE" == "null" ]; then
        echo "Current namespace is not set in $VALUES_FILE_NAMESPACE values file."
        echo
        read -p "Enter new namespace or press enter to use default ('default-mongo'): " USER_INPUT_NAMESPACE
        echo
        if [ -n "$USER_INPUT_NAMESPACE" ]; then
            # Save the namespace to values.yaml
            yq e -i ".global.namespaceOverride = \"$USER_INPUT_NAMESPACE\"" "$VALUES_FILE_PATH"
            yq e -i ".namespaceOverride = \"$USER_INPUT_NAMESPACE\"" "$VALUES_FILE_PATH"
        else
            default_namespace="default-mongo" # Default namespace
            # Save the namespace to values.yaml
            yq e -i ".global.namespaceOverride = \"$default_namespace\"" "$VALUES_FILE_PATH"
            yq e -i ".namespaceOverride = \"$default_namespace\"" "$VALUES_FILE_PATH"
        fi
    fi
    
    NAMESPACE=$(yq e '.global.namespaceOverride' "$VALUES_FILE_PATH")
}

check_tools() {
    # Check for helm
    if ! command -v helm &> /dev/null; then
        echo "Error: helm is not installed. on MacOS, run 'brew install helm' to install it."
        exit 1
    fi

    # Check for kubectl
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed. on MacOS, run 'brew install kubectl' to install it."
        exit 1
    fi

    # Check for yq
    if ! command -v yq &> /dev/null; then
        echo "Error: yq is not installed. on MacOS, run 'brew install yq' to install it."
        exit 1
    fi

    # Check for jq
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. on MacOS, run 'brew install jq' to install it."
        exit 1
    fi

    # Check for openssl
    if ! command -v openssl &> /dev/null; then
        echo "Error: openssl is not installed. on MacOS, run 'brew install openssl' to install it."
        exit 1
    fi
}

# Function to get the current Kubernetes cluster name
get_cluster_name() {
    # Show current Kubernetes cluster
    echo "Current Kubernetes cluster:"
    echo "  " && kubectl config current-context| awk '{print "  - " $0}'
    echo
    # Prompt for user confirmation
    read -p "Is this the correct Kubernetes cluster for MongoDB deployment? (yes/no): " CONFIRM_CLUSTER
    echo
    if [ "$CONFIRM_CLUSTER" != "yes" ]; then
        echo "Which Kubernetes cluster would you like to use for this new mongo installation?"
        echo
        kubectl config get-contexts
        read -p "Enter the name of the Kubernetes cluster: " CLUSTER_NAME
        echo
        kubectl config use-context "$CLUSTER_NAME"
    else 
        CLUSTER_NAME=$(kubectl config current-context)
    fi
}

# Function to switch the current Kubernetes context
switch_k8s_context() {
    local contextName=$1

    # Check if contextName is empty
    if [ -z "$contextName" ]; then
        echo "Error: No context name provided. Please specify a context name to switch to."
        echo
        return 1 # Exit the function with an error status
    fi

    # Validate the selected context exists
    if kubectl config get-contexts | grep -q "$contextName"; then
        kubectl config use-context "$contextName"
        echo "Switched to context: $contextName"
        echo
    else
        echo "Context $contextName does not exist."
        echo
    fi
}

# Function to validate the current context of kubernetes match the context of the current mongo installation, if not, switch the context
validate_k8s_context() {
    local contextName=$1

    # Check if contextName is empty
    if [ -z "$contextName" ]; then
        echo "Error: No context name provided. Please specify a context name to validate."
        echo
        return 1 # Exit the function with an error status
    fi

    # get current k8s context
    local currentK8sContext=$(kubectl config current-context)

    # Validate the currentK8sContext matches the contextName
    if [ "$currentK8sContext" != "$contextName" ]; then
        echo "Current k8s context does not match the context of the current mongo installation."
        echo "Switching to the context of the current mongo installation..."
        switch_k8s_context "$contextName"
    else
        echo "Current k8s context matches the context of the current mongo installation."
    fi
}

# Function to generate random and secure passwords, it takes the length of the password as an argument
generate_password() {
    local password_length=$1
    
    # Define character sets
    local special_chars="@#$-_^"
    local alpha_num_chars="A-Za-z0-9"

    if [ -z "$password_length" ]; then
        password_length=16
    fi

    # Generate parts of the password
    part_special=$(echo "$special_chars" | fold -w1 | shuf | head -c1)
    part_alpha_num=$(openssl rand -base64 48 | tr -dc "$alpha_num_chars" | head -c $((password_length - 1)))

    # Assemble the password parts
    GENERATED_PASSWORD="$part_special$part_alpha_num"

    # Ensure the password meets the required length
    GENERATED_PASSWORD=$(echo "$GENERATED_PASSWORD" | head -c $password_length)
}

# Function to configure external access for MongoDB
configure_external_access() {
    read -p "Do you want to enable external access to MongoDB? (yes/no): " enable_external_access
    echo

    if [[ "$enable_external_access" == "yes" ]]; then
        echo "Warning: Enabling external access to MongoDB without TLS is not recommended for production environments."
        echo "If this setup is for production, please ensure to configure TLS for secure communication."
        echo "Proceeding without TLS should only be done for testing or non-critical deployments."
        echo
        read -p "Do you still want to proceed with enabling external access? (yes/no): " confirm_proceed
        echo
        if [[ "$confirm_proceed" != "yes" ]]; then
            echo "External access configuration aborted."
            echo
            return
        fi

        echo "Enabling external access..."
        # Set externalAccess.enabled to true
        yq e -i '.externalAccess.enabled = true' "$VALUES_FILE_PATH"
        
        local replica_count=$(yq e '.replicaCount' "$VALUES_FILE_PATH")

        # Reset the node ports
        yq e -i ".externalAccess.service.nodePorts = []" "$VALUES_FILE_PATH"

        # Finding available ports
        local port_array=()
        local lower_port_limit=30000
        local upper_port_limit=32767
        local needed_ports=$replica_count
        local current_ports=$(kubectl get svc --all-namespaces -o jsonpath="{.items[*].spec.ports[*].nodePort}")

        while [ ${#port_array[@]} -lt $needed_ports ]
        do
            local port_candidate=$((lower_port_limit + RANDOM % (upper_port_limit - lower_port_limit + 1)))
            if [[ ! $current_ports =~ $port_candidate ]]; then
                if [[ ! " ${port_array[@]} " =~ " ${port_candidate} " ]]; then
                    port_array+=($port_candidate)
                fi
            fi
        done

        # Append node ports based on available ports to the list
        for port in "${port_array[@]}"; do
            yq e -i ".externalAccess.service.nodePorts += [$port]" "$VALUES_FILE_PATH"
        done

        echo "Appended node ports to externalAccess.service.nodePorts in values.yaml"
        echo

    else
        echo "Disabling external access..."
        echo
        # Set externalAccess.enabled to false
        yq e -i '.externalAccess.enabled = false' "$VALUES_FILE_PATH"

        # Remove all node ports from the list
        yq e -i ".externalAccess.service.nodePorts = []" "$VALUES_FILE_PATH"
    fi
}

# Function to prompt the user for MongoDB secrets and configuration
set_mongodb_parameters(){
    # Prompt the user for MongoDB secrets and Configuration
    echo "Creating MongoDB secrets..."
    echo
    # ask for the root password, or generate one 
    read -sp "Enter MongoDB Root Password or press enter to automatically generate a secure one: " MONGODB_ROOT_PASSWORD
    if [ -z "$MONGODB_ROOT_PASSWORD" ]; then
        generate_password 26
        MONGODB_ROOT_PASSWORD=$GENERATED_PASSWORD
        echo "Generated Root Password: $MONGODB_ROOT_PASSWORD"
    fi
    echo
    read -p "Enter MongoDB Username: " MONGODB_USERNAME
    echo
    # ask for the password, or generate one
    read -sp "Enter MongoDB User Password or press enter to automatically generate a secure one: " MONGODB_USER_PASSWORD
    if [ -z "$MONGODB_USER_PASSWORD" ]; then
        generate_password 20
        MONGODB_USER_PASSWORD=$GENERATED_PASSWORD
        echo "Generated User Password: $MONGODB_USER_PASSWORD"
    fi
    echo
    read -p "Enter new MongoDB database name: " MONGODB_DATABASE
    # current storage class
    echo 
    echo "Current storage classes available:"
    kubectl get storageclass
    echo 
    read -p "Enter the storage class name: " STORAGE_CLASS
    echo
    read -p "Enter the desired storage size in Gi for MongoDB (note that this is the size for each MongoDB node), Enter only the number without the unit, e.g. 10 : " STORAGE_SIZE
    echo

    # Update values.yaml with the extracted secrets using yq
    yq e -i ".auth.rootPassword = \"$MONGODB_ROOT_PASSWORD\"" "$VALUES_FILE_PATH"
    yq e -i ".auth.usernames[0] = \"$MONGODB_USERNAME\"" "$VALUES_FILE_PATH"
    yq e -i ".auth.passwords[0] = \"$MONGODB_USER_PASSWORD\"" "$VALUES_FILE_PATH"
    yq e -i ".auth.databases[0] = \"$MONGODB_DATABASE\"" "$VALUES_FILE_PATH"
    yq e -i ".persistence.storageClass = \"$STORAGE_CLASS\"" "$VALUES_FILE_PATH"
    # append the unit to the storage size
    STORAGE_SIZE="${STORAGE_SIZE}Gi"
    yq e -i ".persistence.size = \"$STORAGE_SIZE\"" "$VALUES_FILE_PATH"

    if $IS_STANDALONE; then
        # ask if user would access the MongoDB instance from outside the cluster, if yes, set the service type to NodePort
        read -p "Would you like to access the MongoDB instance from outside the Kubernetes cluster? (yes/no): " ACCESS_FROM_OUTSIDE
        echo
        if [ "$ACCESS_FROM_OUTSIDE" == "yes" ]; then
            yq e -i ".service.type = \"NodePort\"" "$VALUES_FILE_PATH"

            # set nodePort port number
            echo "Current NodePort services:"
            echo
            kubectl get svc -A | grep NodePort
            echo
            read -p "Enter the desired NodePort port number for MongoDB, e.g. 32017 (port number must be between 30000 and 32767): " NODE_PORT
            echo
            yq e -i ".service.nodePorts.mongodb = $NODE_PORT" "$VALUES_FILE_PATH"
        else
            # set the service type to ClusterIP
            yq e -i ".service.type   = \"ClusterIP\"" "$VALUES_FILE_PATH"
        fi

    else
        echo
        # Ask for the MongoDB Replica Set Key, or generate one
        read -sp "Enter MongoDB Replica Set Key or press enter to automatically generate a secure one: " MONGODB_REPLICA_SET_KEY
        echo
        if [ -z "$MONGODB_REPLICA_SET_KEY" ]; then
            generate_password 32
            MONGODB_REPLICA_SET_KEY=$GENERATED_PASSWORD
            echo "Generated Replica Set Key: $MONGODB_REPLICA_SET_KEY"
        fi
        echo
        read -p "Enter the desired replica count for MongoDB, min of 2 is required : " REPLICA_COUNT
        echo
        yq e -i ".auth.replicaSetKey = \"$MONGODB_REPLICA_SET_KEY\"" "$VALUES_FILE_PATH"
        yq e -i ".replicaCount = $REPLICA_COUNT" "$VALUES_FILE_PATH"

        # configure backup and restore
        configure_backup_restore

        # Configure external access
        configure_external_access
    fi
}

# Function to configure backup and restore for MongoDB
configure_backup_restore() {
    # ask if user would like to configure backup and restore
        read -p "Would you like to configure backup and restore for MongoDB? (yes/no): " CONFIGURE_BACKUP_RESTORE
        echo
        if [ "$CONFIGURE_BACKUP_RESTORE" == "yes" ]; then
            # Prompt the user for backup and restore configuration
            echo "Configuring backup and restore for MongoDB..."
            echo
            read -p "Enter the desired backup schedule in cron format (e.g. '0 0 * * *' for daily at midnight): " BACKUP_SCHEDULE
            echo
            read -p "Enter the desired retention period for backups in days: " BACKUP_RETENTION
            echo

            yq e -i ".backup.enabled = true" "$VALUES_FILE_PATH"
            yq e -i ".backup.cronjob.schedule = \"$BACKUP_SCHEDULE\"" "$VALUES_FILE_PATH"
            yq e -i ".backup.cronjob.storage.size = \"$STORAGE_SIZE\"" "$VALUES_FILE_PATH"
            yq e -i ".backup.cronjob.storage.storageClass = \"$STORAGE_CLASS\"" "$VALUES_FILE_PATH"
            
            # deploy retention cronjob
            BACKUP_FILE_NAME="backup-cleanup-job-$RELEASE_NAME.yaml"
            cp $PROJECT_PATH/backup-cleanup-job.yaml "$CONFIG_DIR/$BACKUP_FILE_NAME"
            echo "Configuration for backup-cleanup-job copied to $CONFIG_DIR/$BACKUP_FILE_NAME"
            echo
            
            # create namespace if not exists
            kubectl create namespace $NAMESPACE

            # deploy configMap from bash script that does the cleaning inside the pod
            kubectl -n $NAMESPACE create configmap delete-old-backups-script --from-file=$PROJECT_PATH/delete_old_backups.sh
        
            # set the retention period in $CONFIG_DIR/$BACKUP_FILE_NAME file and apply it
            yq e -i ".spec.jobTemplate.spec.template.spec.containers[0].env[0].value = \"$BACKUP_RETENTION\"" "$CONFIG_DIR/$BACKUP_FILE_NAME"

            # ask when the user prefere to schedule cleanup job to start, need to be cronjob syntax
            read -p "Enter the desired schedule for the backup cleanup job in cron format (e.g. '0 0 * * *' for daily at midnight): " BACKUP_CLEANUP_SCHEDULE
            echo
            yq e -i ".spec.schedule = \"$BACKUP_CLEANUP_SCHEDULE\"" "$CONFIG_DIR/$BACKUP_FILE_NAME"
            # read the backup volume name from kubectl, the name should have prefix of : -mongodump
            BACKUP_VOLUME_NAME=$(kubectl get pvc -n mongodb | grep "mongodump" | awk '{print $1}')
            yq e -i ".spec.jobTemplate.spec.template.spec.volumes[1].persistentVolumeClaim.claimName = \"$BACKUP_VOLUME_NAME\"" "$CONFIG_DIR/$BACKUP_FILE_NAME"

            # apply the cronjob
            kubectl apply -f "$CONFIG_DIR/$BACKUP_FILE_NAME"
            
            read -p "Would you like to configure backup to an external S3 storage? (yes/no): " BACKUP_TO_EXTERNAL
            echo
            if [ "$BACKUP_TO_EXTERNAL" == "yes" ]; then

                # deploy retention cronjob
                S3BACKUP_FILE_NAME="mongo-backup-cronjob-rclone-$RELEASE_NAME.yaml"
                cp $PROJECT_PATH/mongo-backup-cronjob-rclone.yaml "$CONFIG_DIR/$S3BACKUP_FILE_NAME"
                echo "Configuration for mongo-backup-cronjob-rclone.yaml copied to $CONFIG_DIR/$S3BACKUP_FILE_NAME"
                echo

                read -p "Enter the S3 bucket name: " S3_BUCKET_NAME
                echo
                read -p "Enter the S3 access key: " S3_ACCESS_KEY
                echo
                read -sp "Enter the S3 secret key: " S3_SECRET_KEY
                echo
                read -p "Enter the S3 endpoint (optional, press enter to skip): " S3_ENDPOINT
                echo
                read -p "Enter the s3 provider ex: AWS, Minio, Wasabi, Ceph. for Linode Object Storage chose ceph: " S3_PROVIDER
                echo
                read -p "Enter desired backup schedule in cron format (e.g. '0 0 * * *' for daily at midnight), choose a shcedule after the mongo backup: " EXTERNAL_BACKUP_SCHEDULE
                echo
                
                # create secret that group S3_ACCESS_KEY and S3_SECRET_KEY and S3_ENDPOINT and deploy it to the namespace
                # Create the secret in Kubernetes
                kubectl -n $NAMESPACE create secret generic s3-credentials --from-literal=access_key="$S3_ACCESS_KEY" --from-literal=secret_key="$S3_SECRET_KEY" --from-literal=endpoint="$S3_ENDPOINT"
                
                # set the values in the $CONFIG_DIR/$S3BACKUP_FILE_NAME file
                # sechdule
                yq e -i ".spec.schedule = \"$EXTERNAL_BACKUP_SCHEDULE\"" "$CONFIG_DIR/$S3BACKUP_FILE_NAME"
                # s3 provider
                yq e -i ".spec.jobTemplate.spec.template.spec.containers[0].env[1].value = \"$S3_PROVIDER\"" "$CONFIG_DIR/$S3BACKUP_FILE_NAME"
                # s3 endpoint from secret
                yq e -i ".spec.jobTemplate.spec.template.spec.containers[0].env[4].valueFrom.secretKeyRef.name = \"s3-credentials\"" "$CONFIG_DIR/$S3BACKUP_FILE_NAME"
                yq e -i ".spec.jobTemplate.spec.template.spec.containers[0].env[4].valueFrom.secretKeyRef.key = \"endpoint\"" "$CONFIG_DIR/$S3BACKUP_FILE_NAME"

                # s3 S3_ACCESS_KEY from secret
                yq e -i ".spec.jobTemplate.spec.template.spec.containers[0].env[2].valueFrom.secretKeyRef.name = \"s3-credentials\"" "$CONFIG_DIR/$S3BACKUP_FILE_NAME"
                yq e -i ".spec.jobTemplate.spec.template.spec.containers[0].env[2].valueFrom.secretKeyRef.key  = \"access_key\"" "$CONFIG_DIR/$S3BACKUP_FILE_NAME"

                # s3 S3_SECRET_KEY from secret
                yq e -i ".spec.jobTemplate.spec.template.spec.containers[0].env[3].valueFrom.secretKeyRef.name  = \"s3-credentials\"" "$CONFIG_DIR/$S3BACKUP_FILE_NAME"
                yq e -i ".spec.jobTemplate.spec.template.spec.containers[0].env[3].valueFrom.secretKeyRef.key   = \"secret_key\"" "$CONFIG_DIR/$S3BACKUP_FILE_NAME"

                # volume
                yq e -i ".spec.jobTemplate.spec.template.spec.volumes[0].persistentVolumeClaim.claimName = \"$BACKUP_VOLUME_NAME\"" "$CONFIG_DIR/$S3BACKUP_FILE_NAME"

                # edit the arg to include the bucket name
                FULL_BUCKET_NAME="$S3_BUCKET_NAME"/dumps
                yq -i '.spec.jobTemplate.spec.template.spec.containers[0].args[3] = "s3:'"$FULL_BUCKET_NAME"'"' "$CONFIG_DIR/$S3BACKUP_FILE_NAME"
                echo "make sure to create bucket $FULL_BUCKET_NAME in the s3 provider"
                # apply the cronjob
                kubectl apply -f "$CONFIG_DIR/$S3BACKUP_FILE_NAME"
            fi  
        fi
}

# Function to install a new MongoDB installation using Helm
new_mongodb_installation() {
    # Choose and copy MongoDB flavor values
    choose_mongodb_flavor_values_and_set_releaseName

    # Set the namespace in values.yaml
    set_namespace

    # Get the current Kubernetes cluster name
    get_cluster_name

    # Set MongoDB parameters
    set_mongodb_parameters

    # validate if bitnami repo is added and updated 
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update

    # Install MongoDB using Helm
    echo "Installing MongoDB using Helm..."
    helm install "$RELEASE_NAME" bitnami/mongodb -f "$VALUES_FILE_PATH" --namespace "$NAMESPACE" --create-namespace --version $MONGO_HELM_CHART_VERSION

    # Validate the installation was successful
    if [ $? -eq 0 ]; then
        echo "MongoDB installation successful."
        # Set the current context to the new installation
        local type="Standalone"
        if [[ "$VALUES_FILE_PATH" == *"replicaset"* ]]; then
            type="Cluster"
            # if type is cluster and backup and restore is configured, we save the cronjob files in context as well
            # save the backup and restore cronjobs
            if [ "$CONFIGURE_BACKUP_RESTORE" == "yes" ]; then
                add_new_context "$RELEASE_NAME" "$NAMESPACE" "$CLUSTER_NAME" "$VALUES_FILE_NAME" "$RELEASE_NAME" "$type" "Running" "$BACKUP_FILE_NAME" "$S3BACKUP_FILE_NAME"
            fi
        else 
            add_new_context "$RELEASE_NAME" "$NAMESPACE" "$CLUSTER_NAME" "$VALUES_FILE_NAME" "$RELEASE_NAME" "$type" "Running"
        fi
        echo "New context added for $RELEASE_NAME with type $type and status Running."
    else
        echo "Error: MongoDB installation failed."
        # Optionally add a context with a status of "Stopped" or similar to reflect the failure
        local type="Standalone"
        if [[ "$VALUES_FILE_PATH" == *"replicaset"* ]]; then
            type="Cluster"
            if [ "$CONFIGURE_BACKUP_RESTORE" == "yes" ]; then
                add_new_context "$RELEASE_NAME" "$NAMESPACE" "$CLUSTER_NAME" "$VALUES_FILE_NAME" "$RELEASE_NAME" "$type" "Stopped" "$BACKUP_FILE_NAME" "$S3BACKUP_FILE_NAME"
            fi
        else 
            add_new_context "$RELEASE_NAME" "$NAMESPACE" "$CLUSTER_NAME" "$VALUES_FILE_NAME" "$RELEASE_NAME" "$type" "Stopped"
        fi
        echo "Context added for $RELEASE_NAME with type $type and status Stopped due to installation failure."
    fi
}

# Function to uninstall a MongoDB installation using Helm
# This function will not delete data, it will only delete the helm release
# The data will be retained in the persistent volume
# the context file won't be deleted, so user can restart the installation
stop_mongodb(){
    local releaseName=$1
    
    # switch to the context of the release
    switch_context "$releaseName"
    
    # get context details
    get_current_context_configs

    # validate k8s context
    validate_k8s_context "$CURRENT_CONTEXT_CLUSTERNAME"

    # Uninstall MongoDB using Helm
    echo "Stopping MongoDB release '$releaseName'..."
    helm uninstall "$CURRENT_CONTEXT_HELMRELEASENAME" --namespace "$CURRENT_CONTEXT_NAMESPACE"

    if [ $? -eq 0 ]; then
        echo "MongoDB release '$releaseName' stopped successfully."
        # Update the status in the context
        jq --arg releaseName "$releaseName" --arg newStatus "Stopped" \
            '(.contexts[] | select(.name == $releaseName) .status) |= $newStatus' \
            "$CONTEXT_FILE" > temp.json && mv temp.json "$CONTEXT_FILE"
    else
        echo "Error: Failed to stop MongoDB release '$releaseName'."
    fi
    # we need to check if we have a backup and restore cronjob and stop it as well
    if [ "$CURRENT_CONTEXT_TYPE" == "Cluster" ]; then
        if [ "$CURRENT_CONTEXT_BACKUPCLEANUPCRON" != "not provided" ]; then
            kubectl -n "$CURRENT_CONTEXT_NAMESPACE" delete -f "$CONFIG_DIR/$CURRENT_CONTEXT_BACKUPCLEANUPCRON"
        fi
        if [ "$CURRENT_CONTEXT_S3EXTERNALBACKUPCRON" != "not provided" ]; then
            kubectl -n "$CURRENT_CONTEXT_NAMESPACE" delete -f "$CONFIG_DIR/$CURRENT_CONTEXT_S3EXTERNALBACKUPCRON"
        fi
    fi

}

# Function to start a previously uninstalled MongoDB release
start_mongodb() {
    local releaseName=$1

    # Check if the release name is provided
    if [ -z "$releaseName" ]; then
        echo "Error: No release name provided. Please specify a release name to start."
        return 1
    fi

    # Ensure the context for the release exists
    switch_context "$releaseName"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to switch context. The specified release may not exist."
        return 1
    fi

    # Get current context configurations
    get_current_context_configs

    # Validate the Kubernetes context
    validate_k8s_context "$CURRENT_CONTEXT_CLUSTERNAME"

    # Reinstall MongoDB using Helm with the existing values file
    echo "Starting MongoDB release '$releaseName'..."
    helm install "$CURRENT_CONTEXT_HELMRELEASENAME" bitnami/mongodb -f "$CONFIG_DIR/$CURRENT_CONTEXT_CONFIGFILENAME" --namespace "$CURRENT_CONTEXT_NAMESPACE" --create-namespace --version $MONGO_HELM_CHART_VERSION

    # Check if the Helm installation was successful
    if [ $? -eq 0 ]; then
        echo "MongoDB release '$releaseName' started successfully."
        # Update the status in the context
        jq --arg releaseName "$releaseName" --arg newStatus "Running" \
            '(.contexts[] | select(.name == $releaseName) .status) |= $newStatus' \
            "$CONTEXT_FILE" > temp.json && mv temp.json "$CONTEXT_FILE"
    else
        echo "Error: Failed to start MongoDB release '$releaseName'."
    fi
    # we need to check if we have a backup and restore cronjob and start it as well
    if [ "$CURRENT_CONTEXT_TYPE" == "Cluster" ]; then
        if [ "$CURRENT_CONTEXT_BACKUPCLEANUPCRON" != "not provided" ]; then
            # apply the cronjob
            kubectl apply -f "$CONFIG_DIR/$CURRENT_CONTEXT_BACKUPCLEANUPCRON"
            echo "Backup cleanup cronjob applied."
            echo
        fi
        if [ "$CURRENT_CONTEXT_S3EXTERNALBACKUPCRON" != "not provided" ]; then
            # apply the cronjob
            kubectl apply -f "$CONFIG_DIR/$CURRENT_CONTEXT_S3EXTERNALBACKUPCRON"
            echo "Backup to external storage cronjob applied."
            echo
        fi
    fi
}


# Function to fully delete and purge a MongoDB release
delete_purge() {
    local releaseName=$1

    # Prompt for confirmation to proceed with data loss
    echo "WARNING: This operation will completely remove the MongoDB release '$releaseName' and all associated data."
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Operation aborted by the user."
        return 1
    fi

    # Switch to the context of the release
    switch_context "$releaseName"
    if [ $? -ne 0 ]; then
        echo "Error: The specified release does not exist or context switching failed."
        return 1
    fi

    # Get current context configurations
    get_current_context_configs

    # Uninstall MongoDB release using Helm
    echo "Uninstalling MongoDB release '$releaseName'..."
    helm uninstall "$CURRENT_CONTEXT_HELMRELEASENAME" --namespace "$CURRENT_CONTEXT_NAMESPACE"

    # if there is a backup and restore cronjob, we need to delete it as well
    if [ "$CURRENT_CONTEXT_TYPE" == "Cluster" ]; then
        if [ "$CURRENT_CONTEXT_BACKUPCLEANUPCRON" != "not provided" ]; then
            kubectl  -n "$CURRENT_CONTEXT_NAMESPACE" delete -f "$CONFIG_DIR/$CURRENT_CONTEXT_BACKUPCLEANUPCRON"
            echo
            # delete the configmap
            kubectl delete configmap -n "$CURRENT_CONTEXT_NAMESPACE" delete-old-backups-script
            # delete the files of the cronjob
            rm -f "$CONFIG_DIR/$CURRENT_CONTEXT_BACKUPCLEANUPCRON"
        fi
        if [ "$CURRENT_CONTEXT_S3EXTERNALBACKUPCRON" != "not provided" ]; then
            kubectl  -n "$CURRENT_CONTEXT_NAMESPACE" delete -f "$CONFIG_DIR/$CURRENT_CONTEXT_S3EXTERNALBACKUPCRON"
            echo
            # delete secret
            kubectl delete secret -n "$CURRENT_CONTEXT_NAMESPACE" s3-credentials
            # delete the files of the cronjob
            rm -f "$CONFIG_DIR/$CURRENT_CONTEXT_S3EXTERNALBACKUPCRON"
        fi
    fi
    # Delete PVCs associated with the release
    echo "Deleting persistent volume claims..."
    kubectl delete pvc --selector release="$CURRENT_CONTEXT_HELMRELEASENAME" --namespace "$CURRENT_CONTEXT_NAMESPACE"
    
    # delete namespace
    kubectl delete namespace "$CURRENT_CONTEXT_NAMESPACE"
    
    # Delete the values file from the configuration directory
    echo "Removing configuration files..."
    rm -f "$CONFIG_DIR/$CURRENT_CONTEXT_CONFIGFILENAME"

    # Remove context from the context file
    delete_context "$releaseName"

    echo "MongoDB release '$releaseName' and all related data have been completely removed."
}

display_connection_info() {
    local releaseName=$1

    # Switch to the context of the release
    switch_context "$releaseName"
    if [ $? -ne 0 ]; then
        echo "Error: The specified release does not exist or context switching failed."
        return 1
    fi

    # Get current context configurations
    get_current_context_configs

    # Define the path to the values file using current context configurations
    local VALUES_PATH="$CONFIG_DIR/$CURRENT_CONTEXT_CONFIGFILENAME"

    # Extract user credentials and details from values.yaml
    local mongodb_username=$(yq e '.auth.usernames[0]' "$VALUES_PATH")
    local mongodb_password=$(yq e '.auth.passwords[0]' "$VALUES_PATH")
    local mongodb_database=$(yq e '.auth.databases[0]' "$VALUES_PATH")
    local mongodb_root_username=$(yq e '.auth.rootUser' "$VALUES_PATH")
    local mongodb_root_password=$(yq e '.auth.rootPassword' "$VALUES_PATH")
    local external_access_enabled=$(yq e '.externalAccess.enabled' "$VALUES_PATH")

    # Check if necessary details are set in values.yaml
    if [ -z "$mongodb_username" ] || [ -z "$mongodb_password" ] || [ -z "$mongodb_database" ]; then
        echo "Error: user credentials or database not set in values.yaml."
        return 1
    fi

    # Display user credentials
    echo "User Credentials: (To connect to mongodb from a client application)"
    echo "  Username: $mongodb_username"
    echo "  Password: $mongodb_password"
    echo "  Database: $mongodb_database"
    echo
    echo "--------------------------------------------------"
    echo
    
    # Check if the MongoDB instance is running
    if [ "$CURRENT_CONTEXT_STATUS" != "Running" ]; then
        echo "The MongoDB instance '$releaseName' is currently not running. Please start the instance to access connection information."
        return
    fi

    if [ "$CURRENT_CONTEXT_TYPE" == "Cluster" ]; then 
        if [ "$external_access_enabled" = "true" ]; then
            # Get the names of all nodes in the replica set
            local nodes=$(kubectl -n "$CURRENT_CONTEXT_NAMESPACE" exec "$CURRENT_CONTEXT_HELMRELEASENAME-mongodb-0" -- mongosh --quiet -u "$mongodb_root_username" -p "$mongodb_root_password" --authenticationDatabase 'admin' --eval "rs.status().members.forEach(member => { if (member.stateStr !== 'ARBITER') print(member.name) })" | grep -E '[0-9]+:[0-9]+')

            if [ -z "$nodes" ]; then
                echo "Error: Unable to determine the MongoDB nodes."
                return 1
            fi
            
            # Concatenate all node names into a single string
            local node_list=""
            for node in $nodes; do
                node_list+="$node,"
            done
            node_list="${node_list%,}" # Remove the trailing comma

            # Construct and display MongoDB URI for user
            echo "Connecting to MongoDB from outside Kubernetes cluster: (Not recommended for production - just for testing)"
            echo "  MongoDB URI for User:"
            echo "      mongodb://$mongodb_username:$mongodb_password@$node_list/$mongodb_database"
            echo
            echo "--------------------------------------------------"
            echo
        fi

        local service_name="$CURRENT_CONTEXT_HELMRELEASENAME-mongodb-headless"
        # Get the list of pod names
        pods=$(kubectl get pods -n $CURRENT_CONTEXT_NAMESPACE -l "app.kubernetes.io/instance=$CURRENT_CONTEXT_HELMRELEASENAME" -o jsonpath='{.items[*].metadata.name}')
        local internal_node_list=""
        # Iterate over each pod name and compare with the primary_node string
        for pod in $pods; do
            if [[ $pod != *"arbiter"* && $pod != *"mongodump"* ]]; then
                internal_node_list+="$pod.$service_name.$CURRENT_CONTEXT_NAMESPACE.svc.cluster.local:27017,"
            fi
        done
        internal_node_list="${internal_node_list%,}"

        # Construct and display MongoDB URI for user
        echo "Connecting to MongoDB from inside Kubernetes cluster:"
        echo "  MongoDB URI for User:"
        echo "      mongodb://$mongodb_username:$mongodb_password@$internal_node_list/$mongodb_database"
        echo
        echo "--------------------------------------------------"
        echo
    fi

    if [ "$CURRENT_CONTEXT_TYPE" == "Standalone" ]; then
        # if .service.type is NodePort, then the user can access the MongoDB instance from outside the cluster
        std_external_access_enabled=$(yq e '.service.type' "$VALUES_PATH")
        if [ "$std_external_access_enabled" = "NodePort" ]; then
            # Get the nodePort for the MongoDB service
            local nodePort=$(yq e '.service.nodePorts.mongodb' "$VALUES_PATH")

            if [ -z "$nodePort" ]; then
                echo "Error: NodePort not set in values.yaml."
                return 1
            fi

            # Get the external IP address of the node
            local external_ip=$(kubectl get nodes -o wide | awk '{print $6}' | sed -n '2 p')

            if [ -z "$external_ip" ]; then
                echo "Error: External IP address not found."
                return 1
            fi
            
            # Construct and display MongoDB URI for user
            echo "Connection striong to connect to MongoDB from outside Kubernetes cluster: generally to use inside application running outside kubernetes cluster (Not recommended for production - just for testing and development)"
            echo "  MongoDB URI for User:"
            echo "      mongodb://$mongodb_username:$mongodb_password@$external_ip:$nodePort/$mongodb_database"
            echo
            echo "--------------------------------------------------"
            echo
        fi

        # Construct and display MongoDB URI for user
        echo "Connection striong to connect to MongoDB from inside Kubernetes cluster: Recommended for applications running inside the cluster"
        echo "  MongoDB URI for User:"
        echo "      mongodb://$mongodb_username:$mongodb_password@$CURRENT_CONTEXT_NAME-mongodb.$CURRENT_CONTEXT_NAMESPACE.svc.cluster.local:27017/$mongodb_database"
        echo
        echo "--------------------------------------------------"
        echo
    fi

}

restore_mongodb_data_from_file() {
    local releaseName=$1 
    local filePath=$2
    
    # switch to the context of the release
    switch_context "$releaseName"
    
    # get context details
    get_current_context_configs

    # validate k8s context
    validate_k8s_context "$CURRENT_CONTEXT_CLUSTERNAME"

    # Define the path to the values file using current context configurations
    local VALUES_PATH="$CONFIG_DIR/$CURRENT_CONTEXT_CONFIGFILENAME"

    # Extract user credentials and details from values.yaml
    local mongodb_username=$(yq e '.auth.usernames[0]' "$VALUES_PATH")
    local mongodb_password=$(yq e '.auth.passwords[0]' "$VALUES_PATH")
    local mongodb_database=$(yq e '.auth.databases[0]' "$VALUES_PATH")
    local mongodb_root_username=$(yq e '.auth.rootUser' "$VALUES_PATH")
    local mongodb_root_password=$(yq e '.auth.rootPassword' "$VALUES_PATH")
    local internal_node_list=""
    if [ "$CURRENT_CONTEXT_TYPE" == "Cluster" ]; then
        local service_name="$CURRENT_CONTEXT_HELMRELEASENAME-mongodb-headless"
        # Get the list of pod names
        pods=$(kubectl get pods -n $CURRENT_CONTEXT_NAMESPACE -l "app.kubernetes.io/instance=$CURRENT_CONTEXT_HELMRELEASENAME" -o jsonpath='{.items[*].metadata.name}')
        # Iterate over each pod name and compare with the primary_node string
        for pod in $pods; do
            if [[ $pod != *"arbiter"* && $pod != *"mongodump"* ]]; then
                internal_node_list+="$pod.$service_name.$CURRENT_CONTEXT_NAMESPACE.svc.cluster.local:27017,"
            fi
        done
        internal_node_list="${internal_node_list%,}"
        
    fi

    if [ "$CURRENT_CONTEXT_TYPE" == "Standalone" ]; then
        internal_node_list=$CURRENT_CONTEXT_NAME-mongodb.$CURRENT_CONTEXT_NAMESPACE.svc.cluster.local:27017
    fi

    storageClass=$(kubectl get storageclass | awk 'NR>1 {print $1}')

    # Define the PersistentVolumeClaim using a heredoc
    read -r -d '' PVC_DEFINITION <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
    name: "restore-pvc-$CURRENT_CONTEXT_HELMRELEASENAME"
    namespace: $CURRENT_CONTEXT_NAMESPACE
spec:
    accessModes:
        - ReadWriteOnce
    resources:
        requests:
                storage: 5Gi
    storageClassName: $storageClass
EOF

    # Apply the PVC to Kubernetes
    echo "$PVC_DEFINITION" | kubectl apply -f -

    # Define the job YAML using another heredoc
    read -r -d '' CP_JOB_DEFINITION <<EOF
apiVersion: batch/v1
kind: Job
metadata:
   name: busybox-cp-job
   namespace: $CURRENT_CONTEXT_NAMESPACE
spec:
  template:
    spec:
      containers:
      - name: busybox
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
        volumeMounts:
        - name: data-volume
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: "restore-pvc-$CURRENT_CONTEXT_HELMRELEASENAME"
EOF

    # Apply the job YAML to Kubernetes
    echo "$CP_JOB_DEFINITION" | kubectl apply -f -

    # Wait for the pod to be running
    echo "Waiting for the BusyBox pod to be ready..."
    kubectl wait --for=condition=ready pod -l job-name=busybox-cp-job -n $CURRENT_CONTEXT_NAMESPACE --timeout=60s

    # Copy the dump file to the pod
    local pod_name=$(kubectl get pods -l job-name=busybox-cp-job -n $CURRENT_CONTEXT_NAMESPACE -o jsonpath="{.items[0].metadata.name}")
    kubectl cp "$filePath" "$CURRENT_CONTEXT_NAMESPACE/$pod_name:/data/"

    echo "Dump file copied to volume."

    # delete the job after copying the file
    echo "$CP_JOB_DEFINITION" | kubectl delete -f -
    SELECTED_BACKUP_NAME=$(basename $filePath | cut -d'.' -f1)
    fromDb="test"
    # Job definition
    jobName="mongodb-restore-job-$(date +%s)"
    read -r -d '' RESTORE_JOB_DEFINITION <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $jobName
  namespace: $CURRENT_CONTEXT_NAMESPACE
spec:
  template:
    spec:
      containers:
      - name: mongorestore
        image: mongo
        command: ["/bin/sh", "-c"]
        args:
        - |
          /usr/bin/mongorestore \
            --host \$host \
            --username \$username \
            --password \$password \
            --authenticationDatabase toDb \
            --dir=/backup/\$SELECTED_BACKUP_NAME \
            --nsExclude=admin.* \
            --nsExclude=config.* ;
          echo Restore operation completed.
        env:
        - name: SELECTED_BACKUP_NAME
          value: "$SELECTED_BACKUP_NAME"
        - name: host
          value: "$internal_node_list"
        - name: username
          value: "$mongodb_username"
        - name: password
          value: "$mongodb_password"
        - name: fromDb
          value: "$fromDb"
        - name: toDb
          value: "$mongodb_database"
        volumeMounts:
        - name: backup
          mountPath: "/backup"
      restartPolicy: Never
      volumes:
      - name: backup
        persistentVolumeClaim:
          claimName: "restore-pvc-$CURRENT_CONTEXT_HELMRELEASENAME"
EOF
    # Launch the MongoDB restore job
    echo "Launching MongoDB restore job..."
    echo "$RESTORE_JOB_DEFINITION" | kubectl apply -f -

    echo "Waiting for the restore job to complete..."
    kubectl wait --for=condition=complete --timeout=600s job/$jobName -n $CURRENT_CONTEXT_NAMESPACE

    echo "Printing logs from the restore job..."
    kubectl logs job/$jobName -n $CURRENT_CONTEXT_NAMESPACE

    echo "Resotre operation of file $SELECTED_BACKUP_NAME completed."

}
####################################################################################################
## @@@@@@@@@@@@@@@@@@@@@@@@@  Script EntryPoint @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
####################################################################################################

# Main function to handle CLI operations
main() {
    
    OPERATION=$1

    # Check for help flag or no arguments
    if [[ "$OPERATION" == "-h" ]] || [[ "$OPERATION" == "--help" ]] || [[ $# -eq 0 ]]; then
        print_help
        return
    fi

    # Ensure configuration setup
    ensure_config_setup
    check_tools

    case "$OPERATION" in
        swc|switch-context)
            if [[ "$2" == "-h" ]] || [[ "$2" == "--help" ]]; then
                switch_context_help
                return
            fi
            switch_context "$2"
            ;;
        lsc|list-contexts)
            if [[ "$2" == "-h" ]] || [[ "$2" == "--help" ]]; then
                list_contexts_help
                returnx/
            fi
            list_contexts
            ;;
        install)
            if [[ "$2" == "-h" ]] || [[ "$2" == "--help" ]]; then
                install_mongodb_help
                return
            fi
            new_mongodb_installation
            ;;
        start)
            if [[ "$2" == "-h" ]] || [[ "$2" == "--help" ]]; then
                start_mongodb_help
                return
            fi
            start_mongodb "$2"
            ;;
        stop)
            if [[ "$2" == "-h" ]] || [[ "$2" == "--help" ]]; then
                stop_mongodb_help
                return
            fi
            stop_mongodb "$2"
            ;;
        delete)
            if [[ "$2" == "-h" ]] || [[ "$2" == "--help" ]]; then
                delete_help
                return
            fi
            delete_purge "$2"
            ;;
        gc|get-creds)
            if [[ "$2" == "-h" ]] || [[ "$2" == "--help" ]]; then
                get_creds_help
                return
            fi
            display_connection_info "$2"
            ;;
        rff|restore-from-file)
            if [[ "$2" == "-h" ]] || [[ "$2" == "--help" ]]; then
                restore_from_file_help
                return
            fi
            restore_mongodb_data_from_file "$2" "$3"
            ;;
        *)
            echo "Invalid command: $OPERATION"
            echo
            print_help
            ;;
    esac
}

main "$@"