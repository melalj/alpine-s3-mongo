#!/usr/bin/bash
set -e

required_vars="AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION S3_BUCKET THIN_ARCHIVE_NAME"

for var in $required_vars; do
	if [ -z "$(eval echo \$$var)" ]; then
		echo "Error: Environment variable $var is not set."
		exit 1
	fi
done

KEEP_HOURLY_FOR_IN_HOURS=${KEEP_HOURLY_FOR_IN_HOURS:-24}
KEEP_DAILY_FOR_IN_DAYS=${KEEP_DAILY_FOR_IN_DAYS:-30}
KEEP_WEEKLY_FOR_IN_WEEKS=${KEEP_WEEKLY_FOR_IN_WEEKS:-52}
KEEP_MONTHLY_FOR_IN_MONTHS=${KEEP_MONTHLY_FOR_IN_MONTHS:-60}

echo "Configuring AWS credentials"
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION

# Function to delete versions of a file based on retention policy
delete_versions_based_on_policy() {
    local current_date=$(date +%s)
    declare -A seen_hourly seen_daily seen_weekly seen_monthly

    # List all versions of the file, sorted by last modified date (newest first)
    /usr/bin/aws s3api list-object-versions --bucket "$S3_BUCKET" --prefix "$THIN_ARCHIVE_NAME" --query 'Versions[?Key==`'$THIN_ARCHIVE_NAME'`].[LastModified,VersionId]' --output text | sort -r | while read -r line; do
        
        # Extract the date/time and version ID
        local file_datetime=$(echo $line | awk '{print $1}')
        local file_version_id=$(echo $line | awk '{print $2}')

        if [ -z "$file_datetime" ] || [ -z "$file_version_id" ]; then
            continue
        fi

        # Convert ISO 8601 datetime to Unix timestamp
        # Handle formats like: 2025-09-04T16:59:15.000Z
        # Alpine's date doesn't handle +00:00 format well, so we use a different approach
        local clean_datetime=$(echo "$file_datetime" | sed 's/\.[0-9]*Z$//' | sed 's/Z$//' | sed 's/T/ /')
        local file_ts=$(TZ=UTC date -d "$clean_datetime" +%s 2>/dev/null)
        
        if [ -z "$file_ts" ] || [ "$file_ts" = "" ]; then
            # Try alternative format parsing
            local year=$(echo "$file_datetime" | cut -d'T' -f1 | cut -d'-' -f1)
            local month=$(echo "$file_datetime" | cut -d'T' -f1 | cut -d'-' -f2)
            local day=$(echo "$file_datetime" | cut -d'T' -f1 | cut -d'-' -f3)
            local time=$(echo "$file_datetime" | cut -d'T' -f2 | sed 's/\.[0-9]*Z$//' | sed 's/Z$//')
            local hour=$(echo "$time" | cut -d':' -f1)
            local min=$(echo "$time" | cut -d':' -f2)
            local sec=$(echo "$time" | cut -d':' -f3)
            
            # Use date with explicit format
            file_ts=$(TZ=UTC date -d "$year-$month-$day $hour:$min:$sec" +%s 2>/dev/null)
        fi
        
        if [ -z "$file_ts" ]; then
            echo "Warning: Could not parse date $file_datetime, skipping"
            continue
        fi

        # Calculate the age of the file in hours, days, and weeks
        local file_age_hours=$(( (current_date - file_ts) / 3600 ))
        local file_age_days=$((file_age_hours / 24))
        local file_date=$(date -d "@$file_ts" +%Y-%m-%d 2>/dev/null)
        local file_week=$(date -d "@$file_ts" +%Y-%V 2>/dev/null)
        local file_month=$(date -d "@$file_ts" +%Y-%m 2>/dev/null)

        if [ -z "$file_date" ] || [ -z "$file_week" ] || [ -z "$file_month" ]; then
            echo "Warning: Could not extract date components from $file_datetime, skipping"
            continue
        fi

        # Apply retention policies
        if [ $file_age_hours -le $KEEP_HOURLY_FOR_IN_HOURS ]; then
            # For KEEP_HOURLY_FOR_IN_HOURS hours, keep only one backup per hour
            local file_hour=$(date -d "@$file_ts" +%Y-%m-%d-%H 2>/dev/null)
            if [[ -z ${seen_hourly[$file_hour]} ]]; then
                # This is the first backup of the hour, keep it
                echo "kept(hourly): $file_datetime"
                seen_hourly[$file_hour]=1
            else
                # Subsequent backup for the hour, delete it
                echo "deleting: $file_datetime (version: $file_version_id)"
                /usr/bin/aws s3api delete-object --bucket "$S3_BUCKET" --key "$THIN_ARCHIVE_NAME" --version-id "$file_version_id" > /dev/null
                echo " ok"
            fi
        elif [ $file_age_days -le $KEEP_DAILY_FOR_IN_DAYS ]; then
            # For KEEP_DAILY_FOR_IN_DAYS days, keep only one backup per day
            if [[ -z ${seen_daily[$file_date]} ]]; then
                # This is the first backup of the day, keep it
                echo "kept(daily): $file_datetime"
                seen_daily[$file_date]=1
            else
                # Subsequent backup for the day, delete it
                echo "deleting: $file_datetime (version: $file_version_id)"
                /usr/bin/aws s3api delete-object --bucket "$S3_BUCKET" --key "$THIN_ARCHIVE_NAME" --version-id "$file_version_id" > /dev/null
                echo " ok"
            fi
        elif [ $file_age_days -le $(($KEEP_WEEKLY_FOR_IN_WEEKS * 7)) ]; then
            # For KEEP_WEEKLY_FOR_IN_WEEKS weeks, keep only the first backup of each week
            if [[ -z ${seen_weekly[$file_week]} ]]; then
              echo "kept(weekly): $file_datetime"
              seen_weekly[$file_week]=1
            else
                echo "deleting: $file_datetime (version: $file_version_id)"
                /usr/bin/aws s3api delete-object --bucket "$S3_BUCKET" --key "$THIN_ARCHIVE_NAME" --version-id "$file_version_id" > /dev/null
                echo " ok"
            fi
        elif [ $file_age_days -le $(($KEEP_MONTHLY_FOR_IN_MONTHS * 30)) ]; then
            # For KEEP_MONTHLY_FOR_IN_MONTHS months, keep only the first backup of each month
            if [[ -z ${seen_monthly[$file_month]} ]]; then
                seen_monthly[$file_month]=1
                echo "kept(monthly): $file_datetime"
            else
                echo "deleting: $file_datetime (version: $file_version_id)"
                /usr/bin/aws s3api delete-object --bucket "$S3_BUCKET" --key "$THIN_ARCHIVE_NAME" --version-id "$file_version_id" > /dev/null
                echo " ok"
            fi
        else
            # Delete backups older than KEEP_MONTHLY_FOR_IN_MONTHS months
            echo "deleted $THIN_ARCHIVE_NAME $file_datetime (version: $file_version_id)"
            /usr/bin/aws s3api delete-object --bucket "$S3_BUCKET" --key "$THIN_ARCHIVE_NAME" --version-id "$file_version_id" > /dev/null
        fi
    done
}

# Apply retention policies
delete_versions_based_on_policy

echo "Backup thinning complete."