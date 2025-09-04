#!/usr/bin/bash
set -e

required_vars="AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION S3_BUCKET BACKUP_DB_NAME BACKUP_MONGODB_URI BACKUP_AUTH_DB_NAME BACKUP_ARCHIVE_NAME"

for var in $required_vars; do
	if [ -z "$(eval echo \$$var)" ]; then
		echo "Error: Environment variable $var is not set."
		exit 1
	fi
done

echo "Configuring AWS credentials"
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION

echo "Dumping MongoDB databases $BACKUP_DB_NAME to compressed archive..."
/usr/bin/mongodump $BACKUP_EXTRA_PARAMS \
	--uri "$BACKUP_MONGODB_URI" $BACKUP_EXTRA_FLAGS \
	--authenticationDatabase "$BACKUP_AUTH_DB_NAME" \
	--db "$BACKUP_DB_NAME" \
	--gzip \
	--archive="$BACKUP_ARCHIVE_NAME"

echo "Uploading $BACKUP_ARCHIVE_NAME to S3 bucket..."
/usr/bin/aws s3 cp $BACKUP_ARCHIVE_NAME s3://$S3_BUCKET/$BACKUP_ARCHIVE_NAME

echo "Cleaning up compressed archive..."
rm "$BACKUP_ARCHIVE_NAME"

echo "Backup complete!"

if [ -n "$THIN_ARCHIVE_NAME" ]; then
	/bin/bash /thin.sh
fi

exit 0
