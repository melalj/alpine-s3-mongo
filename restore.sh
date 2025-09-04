#!/usr/bin/bash
set -e

required_vars="AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION S3_BUCKET RESTORE_DB_NAME RESTORE_MONGODB_URI RESTORE_AUTH_DB_NAME RESTORE_ARCHIVE_NAME"

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

echo "Download $RESTORE_ARCHIVE_NAME from S3 bucket..."
if [ -n "$RESTORE_VERSION_ID" ]; then
    echo "Downloading specific version: $RESTORE_VERSION_ID"
    /usr/bin/aws s3api get-object --bucket $S3_BUCKET --key $RESTORE_ARCHIVE_NAME --version-id $RESTORE_VERSION_ID $RESTORE_ARCHIVE_NAME
else
    /usr/bin/aws s3 cp s3://$S3_BUCKET/$RESTORE_ARCHIVE_NAME $RESTORE_ARCHIVE_NAME
fi

echo "Restore MongoDB database $RESTORE_DB_NAME from compressed archive..."
/usr/bin/mongorestore $RESTORE_EXTRA_PARAMS \
	--uri "$RESTORE_MONGODB_URI" $RESTORE_EXTRA_FLAGS \
	--authenticationDatabase "$RESTORE_AUTH_DB_NAME" \
	--db "$RESTORE_DB_NAME" \
	--gzip \
	--archive="$RESTORE_ARCHIVE_NAME"

echo "Cleaning up compressed archive..."
rm "$RESTORE_ARCHIVE_NAME"

echo "Restore complete!"
exit 0
