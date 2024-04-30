#!/bin/sh

# Convert retention period in days to seconds
RETENTION_SECONDS=$(($RETENTION_PERIOD * 86400))

# Get the current date in seconds since the epoch
CURRENT_EPOCH=$(date +%s)

# Calculate the threshold date in epoch time
THRESHOLD_EPOCH=$(($CURRENT_EPOCH - $RETENTION_SECONDS))

# Directory containing backup files
BACKUP_DIR="/backup"

# Initialize a flag to track errors
ERROR_OCCURRED=0

# Ensure the script executes in a shell that supports globbing for file iteration
cd "$BACKUP_DIR"
for file in mongodump-*.gz; do
    if [ "$file" = "mongodump-*.gz" ]; then
        echo "No backup files found."
        break
    fi
    
    # Extract the date part from the filename
    filename=$(basename "$file")
    year=$(echo "$filename" | cut -d'-' -f2)
    month=$(echo "$filename" | cut -d'-' -f3)
    day=$(echo "$filename" | cut -d'-' -f4)
    
    # Convert file date to epoch time
    FILE_EPOCH=$(date -D "%Y-%m-%d" -d "$year-$month-$day" +%s 2>/dev/null)
    
    # Check if date conversion was successful
    if [ $? -ne 0 ]; then
        echo "Error converting date for file $file"
        ERROR_OCCURRED=1
        continue
    fi

    # Check if the file's epoch time is less than the threshold epoch time
    if [ "$FILE_EPOCH" -lt "$THRESHOLD_EPOCH" ]; then
        echo "Deleting $file..."
        rm -f "$file"
        if [ $? -ne 0 ]; then
            echo "Failed to delete $file"
            ERROR_OCCURRED=1
        fi
    fi
done

# Return to the original directory if needed
# cd -

# Exit with an error status if any errors were encountered
if [ $ERROR_OCCURRED -ne 0 ]; then
    exit 1
fi
